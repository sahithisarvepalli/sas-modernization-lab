/******************************************************************************
 * PROGRAM  : 03_aca_business_logic.sas
 * PURPOSE  : Gold Layer — Apply federal ACA Employer Mandate rules to
 *            determine full-time employee status, 1095-C offer codes,
 *            and wellness incentive program tiers.
 *
 * KEY SAS TECHNIQUES DEMONSTRATED:
 *   • INTCK()  — count intervals between two SAS dates (months of employment)
 *   • INTNX()  — shift a date by N intervals (next anniversary date)
 *   • PROC TRANSPOSE  — reshape wide monthly-hours to long format
 *   • PROC SQL CASE/WHEN  — multi-branch conditional aggregation
 *   • SELECT/WHEN  — SAS data step branching (equivalent to switch)
 *   • IFC() / CALCULATED — inline derived columns in PROC SQL
 *
 * FEDERAL REFERENCES:
 *   • IRC §4980H — Employer Shared Responsibility (Play-or-Pay)
 *   • IRS Publication 5196 — ACA for Employers
 *   • IRS Instructions for Forms 1094-C and 1095-C
 *     https://www.irs.gov/pub/irs-pdf/i109495c.pdf
 *
 * ACA KEY THRESHOLDS (2024):
 *   Full-Time Employee:  ≥ 130 hours/month (average 30 hrs/week × 4.333)
 *   Applicable Large Employer (ALE):  ≥ 50 FTE equivalents on average
 *   Wellness Incentive Cap:  30% of total annual premium (50% for tobacco)
 *
 * INPUTS  : SILVER.hr_payroll_clean, SILVER.plan_enrollments_clean,
 *            SILVER.wellness_activity_clean
 * OUTPUTS : GOLD.org_monthly_fte, GOLD.emp_aca_status,
 *            GOLD.aca_1095c_determination, GOLD.wellness_incentive_summary
 * LAYER   : Stage 03 (Gold / Domain Business Logic)
 * DEPENDS : 02_data_cleaning.sas must have run first.
 ******************************************************************************/

%include "/workspaces/sas-modernization-lab/sas_code/00_config_and_macros.sas";

%AUDIT_LOG(step=03_STAGE_START, status=START,
           msg=%str(Gold ACA business logic pipeline started));

/* ============================================================
   3.1  TRANSPOSE MONTHLY HOURS: Wide → Long
        PROC TRANSPOSE reshapes the 12 HOURS_XXX columns into a
        single (EMPLOYEE_ID, MONTH_NUM, HOURS_WORKED) structure
        so we can compute FTE per employee per month with PROC SQL.
   ============================================================ */
%AUDIT_LOG(step=03_TRANSPOSE_HOURS, status=START,
           msg=Transposing monthly hours to long format for FTE analysis);

proc transpose
  data   = SILVER.hr_payroll_clean
  out    = work.hours_long
  name   = MONTH_VAR;    /* MONTH_VAR will hold the original column name */
  var    HOURS_JAN HOURS_FEB HOURS_MAR HOURS_APR HOURS_MAY HOURS_JUN
         HOURS_JUL HOURS_AUG HOURS_SEP HOURS_OCT HOURS_NOV HOURS_DEC;
  by     EMPLOYEE_ID;
run;

data work.hours_long (rename=(COL1=HOURS_WORKED) drop=MONTH_VAR);
  set work.hours_long;

  /* Extract 3-char month abbreviation from variable name:
     "HOURS_JAN" → position 7, length 3 → "JAN"              */
  length MONTH_ABBR $3;
  MONTH_ABBR = substr(MONTH_VAR, 7, 3);

  /* WHICHC returns the 1-based position of the first match  */
  MONTH_NUM = whichc(MONTH_ABBR,
                'JAN','FEB','MAR','APR','MAY','JUN',
                'JUL','AUG','SEP','OCT','NOV','DEC');
run;

/* ============================================================
   3.2  ORGANIZATION-LEVEL MONTHLY FTE
        The ACA treats all controlled-group entities together.
        ALE determination: does the org average ≥ 50 FTEs per
        month across the prior calendar year?

        FTE formula (IRC §4980H):
          Full-time employee (≥130 hrs/mo) = 1.0 FTE unit
          Part-time employee (<130 hrs/mo) = total_hrs / 120 FTE units
   ============================================================ */
%AUDIT_LOG(step=03_ORG_FTE, status=START,
           msg=Computing organization-level monthly FTE totals);

proc sql;
  create table GOLD.org_monthly_fte as
  select
    MONTH_NUM,
    MONTH_ABBR                                                          as MONTH_LABEL,
    count(distinct EMPLOYEE_ID)                                         as EMPLOYEE_COUNT,
    sum(case when HOURS_WORKED >= &G_FTE_THRESHOLD_HRS. then 1 else 0 end)
                                                                        as FULLTIME_HEADCOUNT,
    /* ACA FTE calculation per employee aggregated to org level          */
    sum(case
          when HOURS_WORKED >= &G_FTE_THRESHOLD_HRS. then 1.0
          when HOURS_WORKED > 0                      then HOURS_WORKED / 120.0
          else 0
        end)                                                            as TOTAL_FTE_UNITS
                                                                           format=8.2,
    /* ALE flag: TRUE if this month's FTE count is at or above 50       */
    calculated TOTAL_FTE_UNITS >= 50                                    as IS_ALE_MONTH
  from work.hours_long
  group by MONTH_NUM, MONTH_ABBR
  order by MONTH_NUM;
quit;

/* ============================================================
   3.3  EMPLOYEE-LEVEL ACA FULL-TIME STATUS
        Combines payroll hours with INTCK/INTNX date calculations:
          - INTCK('month', start, end)  → months between two dates
          - INTNX('year',  date, n, 'same')  → nth anniversary
        An employee is ACA full-time for the year if they meet the
        ≥ 130-hour threshold for at least 6 of the 12 months.
   ============================================================ */
%AUDIT_LOG(step=03_EMP_ACA_STATUS, status=START,
           msg=Computing employee-level ACA full-time classification);

data GOLD.emp_aca_status;
  set SILVER.hr_payroll_clean;

  /* --- INTCK: count full months employed within the reporting year ---- */
  /* max() / min() guard against employees hired or terminated mid-year   */
  YEAR_START_DT   = mdy(1,  1,  &G_ACA_REPORTING_YR.);
  YEAR_END_DT     = mdy(12, 31, &G_ACA_REPORTING_YR.);
  EFFECTIVE_START = max(HIRE_DATE_SAS, YEAR_START_DT);
  EFFECTIVE_END   = min(today(),       YEAR_END_DT);

  /* INTCK with 'C' (complete intervals) gives months fully elapsed       */
  MONTHS_IN_YEAR = max(0,
                    intck('month', EFFECTIVE_START, EFFECTIVE_END, 'C') + 1);

  /* --- INTNX: compute the employee's next service anniversary date ---- */
  /* INTNX('year', base, n, 'same') advances exactly n years from base   */
  _years_served     = year(today()) - year(HIRE_DATE_SAS);
  _next_ann_offset  = _years_served +
                      (intnx('year', HIRE_DATE_SAS, _years_served, 'same') < today());
  NEXT_ANNIVERSARY  = intnx('year', HIRE_DATE_SAS, _next_ann_offset, 'same');
  format YEAR_START_DT YEAR_END_DT EFFECTIVE_START EFFECTIVE_END
         NEXT_ANNIVERSARY date9.;

  /* --- Count months at or above the ACA 130-hour threshold ------------ */
  MONTHS_FULLTIME =
    (HOURS_JAN  >= &G_FTE_THRESHOLD_HRS.) + (HOURS_FEB  >= &G_FTE_THRESHOLD_HRS.) +
    (HOURS_MAR  >= &G_FTE_THRESHOLD_HRS.) + (HOURS_APR  >= &G_FTE_THRESHOLD_HRS.) +
    (HOURS_MAY  >= &G_FTE_THRESHOLD_HRS.) + (HOURS_JUN  >= &G_FTE_THRESHOLD_HRS.) +
    (HOURS_JUL  >= &G_FTE_THRESHOLD_HRS.) + (HOURS_AUG  >= &G_FTE_THRESHOLD_HRS.) +
    (HOURS_SEP  >= &G_FTE_THRESHOLD_HRS.) + (HOURS_OCT  >= &G_FTE_THRESHOLD_HRS.) +
    (HOURS_NOV  >= &G_FTE_THRESHOLD_HRS.) + (HOURS_DEC  >= &G_FTE_THRESHOLD_HRS.);

  /* --- Average monthly hours across the full year --------------------- */
  AVG_MONTHLY_HOURS = TOTAL_ANNUAL_HOURS / 12;
  format AVG_MONTHLY_HOURS 8.1;

  /* --- ACA full-time classification: ≥ 6 of 12 months at threshold --- */
  length ACA_FULLTIME_EMPLOYEE $1;
  ACA_FULLTIME_EMPLOYEE = ifc(MONTHS_FULLTIME >= 6 and EMP_STATUS ne 'TERMINATED',
                              'Y', 'N');

  drop _years_served _next_ann_offset YEAR_START_DT YEAR_END_DT;
run;

%ASSERT_ROWCOUNT(ds=GOLD.emp_aca_status, min=1, label=Employee ACA Status Gold);

/* ============================================================
   3.4  ACA 1095-C OFFER CODE DETERMINATION
        Form 1095-C — Employer-Provided Health Insurance Offer and
        Coverage — is filed for each ACA full-time employee.

        Line 14 (Offer of Coverage) codes assigned here:
          1A — Qualifying Offer: MEC + min value + employee-only affordable
          1B — MEC to employee only (no dependent coverage offered)
          1C — MEC to employee + spouse (no dependent children)
          1E — MEC to employee + all family members
          1H — No offer of coverage

        Line 16 (Section 4980H Safe Harbor):
          2A — Employee not employed during that month
          2B — Employee not ACA full-time (part-time safe harbor)
          2C — Employee enrolled in coverage offered
          2F — W-2 affordability safe harbor
   ============================================================ */
%AUDIT_LOG(step=03_1095C_CODES, status=START,
           msg=Determining Form 1095-C Line 14 and Line 16 codes per employee);

/* Join employee status with their most recent active plan enrollment */
proc sql;
  create table work.emp_with_coverage as
  select
    e.EMPLOYEE_ID,
    e.LAST_NAME,
    e.FIRST_NAME,
    e.JOB_CLASS,
    e.EMP_STATUS,
    e.STATE_CD,
    e.DEPT_CODE,
    e.DEPT_NAME,
    e.HIRE_DATE_SAS,
    e.MONTHS_FULLTIME,
    e.AVG_MONTHLY_HOURS,
    e.ACA_FULLTIME_EMPLOYEE,
    e.NEXT_ANNIVERSARY,
    p.PLAN_CODE,
    p.PLAN_NAME,
    p.METAL_TIER,
    p.COVERAGE_TIER,
    p.COVERAGE_ACTIVE_FLAG,
    p.ENROLLMENT_DT_SAS,
    p.TERMINATION_DT_SAS
  from GOLD.emp_aca_status   e
  left join SILVER.plan_enrollments_clean p
    on  e.EMPLOYEE_ID        = p.EMPLOYEE_ID
    and p.COVERAGE_ACTIVE_FLAG = 'Y'
  order by e.EMPLOYEE_ID;
quit;

data GOLD.aca_1095c_determination;
  set work.emp_with_coverage;

  length
    LINE_14_OFFER_CODE $2
    LINE_14_DESC       $80
    LINE_16_SAFE_HBR   $2
    LINE_16_DESC       $60;

  /* ------------------------------------------------------------------
     Determine Line 14 Offer Code and Line 16 Safe Harbor code
     using a SELECT/WHEN block (SAS equivalent of switch-case).
     Conditions are evaluated top-to-bottom; first match wins.
  ------------------------------------------------------------------ */
  select;

    /* Employee not employed at all (terminated with no hours) */
    when (EMP_STATUS = 'TERMINATED' and missing(PLAN_CODE)) do;
      LINE_14_OFFER_CODE = '1H';
      LINE_14_DESC       = 'No offer of coverage (employment gap or termination)';
      LINE_16_SAFE_HBR   = '2A';
      LINE_16_DESC       = 'Employee not employed during this reporting period';
    end;

    /* Terminated but had active enrollment during the year */
    when (EMP_STATUS = 'TERMINATED' and not missing(PLAN_CODE)) do;
      LINE_14_OFFER_CODE = '1H';
      LINE_14_DESC       = 'No offer — terminated employee (COBRA-eligible period)';
      LINE_16_SAFE_HBR   = '2A';
      LINE_16_DESC       = 'Employee not employed during this reporting period';
    end;

    /* Part-time employee — safe harbor: employer not liable */
    when (ACA_FULLTIME_EMPLOYEE = 'N' and EMP_STATUS ne 'TERMINATED') do;
      LINE_14_OFFER_CODE = '1H';
      LINE_14_DESC       = 'No offer required — employee did not meet FT threshold';
      LINE_16_SAFE_HBR   = '2B';
      LINE_16_DESC       = 'Employee is not a full-time employee (part-time SH)';
    end;

    /* Full-time: enrolled in Employee + Family (1E) */
    when (ACA_FULLTIME_EMPLOYEE = 'Y' and
          COVERAGE_ACTIVE_FLAG  = 'Y' and
          upcase(COVERAGE_TIER) = 'EMPLOYEE+FAMILY') do;
      LINE_14_OFFER_CODE = '1E';
      LINE_14_DESC       = 'MEC offered to employee, spouse & all dependents — affordable';
      LINE_16_SAFE_HBR   = '2C';
      LINE_16_DESC       = 'Employee enrolled in coverage offered by employer';
    end;

    /* Full-time: enrolled in Employee + Spouse only (1C) */
    when (ACA_FULLTIME_EMPLOYEE = 'Y' and
          COVERAGE_ACTIVE_FLAG  = 'Y' and
          upcase(COVERAGE_TIER) = 'EMPLOYEE+SPOUSE') do;
      LINE_14_OFFER_CODE = '1C';
      LINE_14_DESC       = 'MEC offered to employee and spouse (no dependent children)';
      LINE_16_SAFE_HBR   = '2C';
      LINE_16_DESC       = 'Employee enrolled in coverage offered by employer';
    end;

    /* Full-time: enrolled in Employee-only coverage (1B) */
    when (ACA_FULLTIME_EMPLOYEE = 'Y' and
          COVERAGE_ACTIVE_FLAG  = 'Y' and
          upcase(COVERAGE_TIER) = 'EMPLOYEE') do;
      LINE_14_OFFER_CODE = '1B';
      LINE_14_DESC       = 'MEC offered to employee only (self-only coverage elected)';
      LINE_16_SAFE_HBR   = '2C';
      LINE_16_DESC       = 'Employee enrolled in coverage offered by employer';
    end;

    /* Full-time: Qualifying Offer on lowest-cost plan (1A) */
    when (ACA_FULLTIME_EMPLOYEE = 'Y' and
          COVERAGE_ACTIVE_FLAG  = 'Y' and
          upcase(METAL_TIER) in ('BRONZE', 'LOW')) do;
      LINE_14_OFFER_CODE = '1A';
      LINE_14_DESC       = 'Qualifying Offer: MEC, minimum value, employee-only affordable';
      LINE_16_SAFE_HBR   = '2C';
      LINE_16_DESC       = 'Employee enrolled in coverage offered by employer';
    end;

    /* Full-time: no active enrollment on record */
    otherwise do;
      LINE_14_OFFER_CODE = '1H';
      LINE_14_DESC       = 'No offer of coverage on record — potential penalty exposure';
      LINE_16_SAFE_HBR   = '2F';
      LINE_16_DESC       = 'W-2 affordability safe harbor asserted';
    end;

  end;  /* select */

  /* Flag employees who may generate an IRC §4980H(b) Employer Penalty   */
  length PENALTY_RISK_FLAG $1;
  PENALTY_RISK_FLAG = ifc(
    LINE_14_OFFER_CODE = '1H' and ACA_FULLTIME_EMPLOYEE = 'Y',
    'Y', 'N');

run;

%ASSERT_ROWCOUNT(ds=GOLD.aca_1095c_determination, min=1, label=ACA 1095-C Gold);

/* ============================================================
   3.5  WELLNESS INCENTIVE AGGREGATION
        The ACA limits employer wellness incentives to 30% of the
        total cost of coverage (50% for tobacco-cessation programs).
        Here we aggregate points per employee, apply the annual cap,
        derive incentive tiers, and flag ACA compliance.
   ============================================================ */
%AUDIT_LOG(step=03_WELLNESS_AGG, status=START,
           msg=%str(Aggregating wellness points for year &G_ACA_REPORTING_YR.));

proc sql;
  create table work.wellness_raw_agg as
  select
    EMPLOYEE_ID,
    sum(case when ACTIVITY_TYPE = 'TOBACCO_CESSATION'
            then POINTS_EARNED else 0 end)    as TOBACCO_CESSATION_PTS,
    sum(case when ACTIVITY_TYPE ne 'TOBACCO_CESSATION'
            then POINTS_EARNED else 0 end)    as OTHER_WELLNESS_PTS,
    sum(POINTS_EARNED)                        as TOTAL_RAW_PTS,
    count(distinct ACTIVITY_TYPE)             as DISTINCT_ACTIVITIES,
    count(*)                                  as TOTAL_EVENTS
  from SILVER.wellness_activity_clean
  group by EMPLOYEE_ID;
quit;

data GOLD.wellness_incentive_summary;
  set work.wellness_raw_agg;

  /* --- Apply annual wellness points cap ------------------------------- */
  TOTAL_CAPPED_PTS = min(TOTAL_RAW_PTS, &G_WELLNESS_MAX_PTS.);

  /* --- Derive incentive tier via SELECT/WHEN -------------------------- */
  length INCENTIVE_TIER $10  TIER_DESCRIPTION $80;

  select;
    when (TOTAL_CAPPED_PTS >= 450) do;
      INCENTIVE_TIER   = 'PLATINUM';
      TIER_DESCRIPTION = 'Maximum engagement — eligible for premium reduction';
    end;
    when (TOTAL_CAPPED_PTS >= 300) do;
      INCENTIVE_TIER   = 'GOLD';
      TIER_DESCRIPTION = 'High engagement — eligible for HRA employer contribution';
    end;
    when (TOTAL_CAPPED_PTS >= 150) do;
      INCENTIVE_TIER   = 'SILVER';
      TIER_DESCRIPTION = 'Moderate engagement — gift card reward eligible';
    end;
    otherwise do;
      INCENTIVE_TIER   = 'BRONZE';
      TIER_DESCRIPTION = 'Entry-level participation in wellness program';
    end;
  end;

  /* --- ACA tobacco-incentive compliance check ------------------------- */
  /* Tobacco-cessation incentives must not exceed 50% of cost of coverage */
  /* Using &G_WELLNESS_MAX_PTS. as proxy for annual premium cost           */
  length ACA_TOBACCO_COMPLIANT $1;
  ACA_TOBACCO_COMPLIANT = ifc(
    TOBACCO_CESSATION_PTS <= 0.50 * &G_WELLNESS_MAX_PTS.,
    'Y', 'N');

  /* --- Monetary incentive value (illustrative mapping) ---------------- */
  /* Platinum = $300 premium reduction, Gold = $150 HRA, Silver = $75 GC */
  INCENTIVE_VALUE_USD = case(INCENTIVE_TIER)
    when 'PLATINUM' then 300
    when 'GOLD'     then 150
    when 'SILVER'   then  75
    otherwise            0
  end;

run;

%ASSERT_ROWCOUNT(ds=GOLD.wellness_incentive_summary, min=1, label=Wellness Gold);

/* ============================================================
   3.6  GOLD LAYER SUMMARY STATS  (printed to SAS log)
   ============================================================ */
proc sql;
  select
    sum(ACA_FULLTIME_EMPLOYEE = 'Y')  as FT_Employees,
    sum(ACA_FULLTIME_EMPLOYEE = 'N')  as PT_Employees,
    sum(PENALTY_RISK_FLAG     = 'Y')  as Penalty_Risk_Count,
    sum(LINE_14_OFFER_CODE    = '1E') as Code_1E_Count,
    sum(LINE_14_OFFER_CODE    = '1H') as Code_1H_Count
  from GOLD.aca_1095c_determination;
quit;

%AUDIT_LOG(step=03_STAGE_COMPLETE, status=SUCCESS,
           msg=%str(All 4 Gold datasets created: org_monthly_fte, emp_aca_status, aca_1095c_determination, wellness_incentive_summary));
