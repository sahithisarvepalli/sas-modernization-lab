/******************************************************************************
 * PROGRAM  : 02_data_cleaning.sas
 * PURPOSE  : Silver Layer — Standardize casing, parse date strings,
 *            impute missing values, enrich via Hash Object lookups, and
 *            deduplicate all three healthcare payer feeds.
 *
 * KEY SAS TECHNIQUES DEMONSTRATED:
 *   • DECLARE HASH / defineKey / defineData / find()  — O(1) lookups
 *   • ARRAY processing with iterative DO loops        — bulk imputation
 *   • PROPCASE / UPCASE / STRIP / COMPRESS            — string normalization
 *   • IF 0 THEN SET   — PDV population without reading data
 *   • ANYDTDTE informat  — flexible date string parsing
 *   • PROC SORT NODUPRECS  — exact-duplicate elimination
 *   • BY-group LAST.variable  — keep latest record per key
 *
 * INPUTS  : BRONZE.hr_payroll_raw, BRONZE.plan_enrollments_raw,
 *            BRONZE.wellness_activity_raw, work.dept_master, work.plan_master
 * OUTPUTS : SILVER.hr_payroll_clean, SILVER.plan_enrollments_clean,
 *            SILVER.wellness_activity_clean
 * LAYER   : Stage 02 (Silver / Cleansed)
 * DEPENDS : 01_data_ingestion.sas must have run first.
 ******************************************************************************/

%include "/workspaces/sas-modernization-lab/sas_code/00_config_and_macros.sas";

%AUDIT_LOG(step=02_STAGE_START, status=START,
           msg=%str(Silver cleaning pipeline started));

/* ============================================================
   2.0  BUILD IN-MEMORY REFERENCE TABLES
        These small lookup datasets will be loaded into Hash
        Objects inside the data steps below.
   ============================================================ */
data work.dept_master;
  infile datalines delimiter='|';
  length DEPT_CODE $6  DEPT_NAME $60  DIVISION $40  COST_CENTER $8;
  input  DEPT_CODE $   DEPT_NAME $    DIVISION $     COST_CENTER $;
datalines;
MED001|Medical Underwriting|Health Operations|CC-4410
MED002|Claims Adjudication|Health Operations|CC-4411
ADM001|Human Resources|Corporate Services|CC-1100
ADM002|Payroll Operations|Corporate Services|CC-1101
IT0001|Data Engineering|Technology|CC-7700
FIN001|Actuarial Services|Finance|CC-2200
COM001|Compliance & Regulatory|Legal|CC-3300
;
run;

data work.plan_master;
  infile datalines delimiter='|';
  length PLAN_CODE $8  PLAN_NAME $80  METAL_TIER $10  PREMIUM_CATEGORY $15;
  input  PLAN_CODE $   PLAN_NAME $    METAL_TIER $     PREMIUM_CATEGORY $;
datalines;
PPO_GOLD|Premier Gold PPO|Gold|High
PPO_SILV|Value Silver PPO|Silver|Mid
HMO_BRNZ|Core Bronze HMO|Bronze|Low
HDHP_HSA|HDHP with HSA|Bronze|Low
EPO_PLAT|Executive Platinum EPO|Platinum|Premium
;
run;

/* ============================================================
   2.1  SORT BRONZE PAYROLL FOR BY-GROUP DEDUPLICATION
   ============================================================ */
proc sort data=BRONZE.hr_payroll_raw out=work.payroll_sorted;
  by EMPLOYEE_ID HIRE_DATE;
run;

/* ============================================================
   2.2  CLEAN HR PAYROLL  →  SILVER.hr_payroll_clean
   ============================================================ */
%AUDIT_LOG(step=02_CLEAN_PAYROLL, status=START, msg=Cleaning hr_payroll_raw);

data SILVER.hr_payroll_clean (drop=_i _dept_rc);

  /* --- Hash Object setup (must be inside IF _N_=1 block) --------------- */
  /* "IF 0 THEN SET" puts all dept_master variables into the PDV so SAS    */
  /* knows their type/length before the hash is populated at runtime.      */
  if 0 then set work.dept_master;

  if _N_ = 1 then do;
    declare hash h_dept(dataset: 'work.dept_master');
    h_dept.defineKey ('DEPT_CODE');
    h_dept.defineData('DEPT_NAME', 'DIVISION', 'COST_CENTER');
    h_dept.defineDone();
    call missing(DEPT_NAME, DIVISION, COST_CENTER);
  end;

  set work.payroll_sorted;
  by EMPLOYEE_ID HIRE_DATE;

  /* -------------------------------------------------------------------- */
  /* String standardization                                                */
  /* -------------------------------------------------------------------- */
  LAST_NAME  = propcase(strip(LAST_NAME));
  FIRST_NAME = propcase(strip(FIRST_NAME));
  DEPT_CODE  = strip(upcase(DEPT_CODE));
  STATE_CD   = strip(upcase(STATE_CD));
  JOB_CLASS  = strip(upcase(JOB_CLASS));
  EMP_STATUS = strip(upcase(EMP_STATUS));

  /* -------------------------------------------------------------------- */
  /* Date conversion: raw MM/DD/YYYY string → SAS date value               */
  /* ANYDTDTE10. is a flexible informat that handles many date formats.    */
  /* -------------------------------------------------------------------- */
  format HIRE_DATE_SAS date9.;
  HIRE_DATE_SAS = input(strip(HIRE_DATE), anydtdte10.);

  if missing(HIRE_DATE_SAS) then
    put "WARN: Unparseable HIRE_DATE='" HIRE_DATE "' for EMPLOYEE_ID=" EMPLOYEE_ID;

  /* -------------------------------------------------------------------- */
  /* ARRAY loop: validate and impute monthly hours                         */
  /* - Missing hours are imputed to 0 (employee was not scheduled)        */
  /* - Negative hours are clamped to 0 (data entry error)                 */
  /* - Hours > 744 (max hours in any month) are clamped to 744            */
  /* -------------------------------------------------------------------- */
  array hrs{12} HOURS_JAN HOURS_FEB HOURS_MAR HOURS_APR HOURS_MAY HOURS_JUN
                HOURS_JUL HOURS_AUG HOURS_SEP HOURS_OCT HOURS_NOV HOURS_DEC;

  do _i = 1 to 12;
    if  missing(hrs{_i}) then hrs{_i} = 0;
    else                       hrs{_i} = max(0, min(744, hrs{_i}));
  end;

  /* -------------------------------------------------------------------- */
  /* Derived column: total hours worked across all 12 months              */
  /* -------------------------------------------------------------------- */
  TOTAL_ANNUAL_HOURS = sum(of hrs{*});

  /* -------------------------------------------------------------------- */
  /* Hash lookup: enrich with department name, division, cost center      */
  /* h_dept.find() sets the hash output variables when RC = 0 (found).   */
  /* -------------------------------------------------------------------- */
  _dept_rc = h_dept.find();

  if _dept_rc ne 0 then do;
    DEPT_NAME   = 'UNKNOWN DEPARTMENT';
    DIVISION    = 'UNKNOWN';
    COST_CENTER = 'UNK';
    put "WARN: DEPT_CODE='" DEPT_CODE "' not found in dept_master for EMP=" EMPLOYEE_ID;
  end;

  /* -------------------------------------------------------------------- */
  /* BY-group deduplication: keep the LAST record per EMPLOYEE_ID +        */
  /* HIRE_DATE combination (last-record-wins strategy)                    */
  /* -------------------------------------------------------------------- */
  if last.HIRE_DATE;

  drop HIRE_DATE;  /* Replaced by the SAS-date HIRE_DATE_SAS */
run;

%ASSERT_ROWCOUNT(ds=SILVER.hr_payroll_clean, min=1, label=Silver Payroll Clean);
%CHECK_NULLS(ds=SILVER.hr_payroll_clean, var=HIRE_DATE_SAS, threshold_pct=2);

proc contents data=SILVER.hr_payroll_clean varnum;
  title "SILVER.hr_payroll_clean — Variable Inventory";
run;

/* ============================================================
   2.3  CLEAN PLAN ENROLLMENTS  →  SILVER.plan_enrollments_clean
   ============================================================ */
%AUDIT_LOG(step=02_CLEAN_ENROLLMENT, status=START, msg=Cleaning plan_enrollments_raw);

data SILVER.plan_enrollments_clean (drop=_plan_rc);

  if 0 then set work.plan_master;

  if _N_ = 1 then do;
    declare hash h_plan(dataset: 'work.plan_master');
    h_plan.defineKey ('PLAN_CODE');
    h_plan.defineData('PLAN_NAME', 'METAL_TIER', 'PREMIUM_CATEGORY');
    h_plan.defineDone();
    call missing(PLAN_NAME, METAL_TIER, PREMIUM_CATEGORY);
  end;

  set BRONZE.plan_enrollments_raw;

  /* --- Key standardization -------------------------------------------- */
  EMPLOYEE_ID      = strip(upcase(EMPLOYEE_ID));
  PLAN_CODE        = strip(upcase(PLAN_CODE));
  COVERAGE_TIER    = strip(upcase(COVERAGE_TIER));
  SUBSIDY_ELIGIBLE = strip(upcase(SUBSIDY_ELIGIBLE));

  /* --- Date parsing ---------------------------------------------------- */
  format ENROLLMENT_DT_SAS TERMINATION_DT_SAS date9.;
  ENROLLMENT_DT_SAS  = input(strip(ENROLLMENT_DT),  anydtdte10.);

  if strip(TERMINATION_DT) ne ''
    then TERMINATION_DT_SAS = input(strip(TERMINATION_DT), anydtdte10.);
  else      TERMINATION_DT_SAS = .;  /* NULL = still-active enrollment */

  /* --- Derived: is this enrollment currently active? ------------------- */
  length COVERAGE_ACTIVE_FLAG $1;
  if missing(TERMINATION_DT_SAS) or TERMINATION_DT_SAS >= today()
    then COVERAGE_ACTIVE_FLAG = 'Y';
  else      COVERAGE_ACTIVE_FLAG = 'N';

  /* --- Hash lookup: enrich with plan metadata -------------------------- */
  _plan_rc = h_plan.find();

  if _plan_rc ne 0 then do;
    PLAN_NAME        = 'UNKNOWN PLAN';
    METAL_TIER       = 'UNK';
    PREMIUM_CATEGORY = 'UNK';
    put "WARN: PLAN_CODE='" PLAN_CODE "' not found in plan_master";
  end;

  drop ENROLLMENT_DT TERMINATION_DT;
run;

/* Remove exact duplicate enrollment rows */
proc sort data=SILVER.plan_enrollments_clean noduprecs;
  by EMPLOYEE_ID PLAN_CODE ENROLLMENT_DT_SAS;
run;

%ASSERT_ROWCOUNT(ds=SILVER.plan_enrollments_clean, min=1, label=Silver Enrollments Clean);

/* ============================================================
   2.4  CLEAN WELLNESS ACTIVITY  →  SILVER.wellness_activity_clean
   ============================================================ */
%AUDIT_LOG(step=02_CLEAN_WELLNESS, status=START, msg=Cleaning wellness_activity_raw);

data SILVER.wellness_activity_clean;
  set BRONZE.wellness_activity_raw;

  /* --- Keep only employer-verified activity records ------------------- */
  where strip(upcase(VERIFIED_FLAG)) = 'Y';

  /* --- String standardization ----------------------------------------- */
  EMPLOYEE_ID   = strip(upcase(EMPLOYEE_ID));
  ACTIVITY_TYPE = strip(upcase(ACTIVITY_TYPE));
  VENDOR_CODE   = strip(upcase(VENDOR_CODE));

  /* --- Date parsing ---------------------------------------------------- */
  format ACTIVITY_DATE_SAS date9.;
  ACTIVITY_DATE_SAS = input(strip(ACTIVITY_DATE), anydtdte10.);

  if missing(ACTIVITY_DATE_SAS) then
    put "WARN: Bad ACTIVITY_DATE='" ACTIVITY_DATE "' for EMPLOYEE_ID=" EMPLOYEE_ID;

  /* --- Cap points per event to business maximum (100 pts) ------------- */
  POINTS_EARNED = max(0, min(100, coalesce(POINTS_EARNED, 0)));

  /* --- Restrict to the ACA reporting year ----------------------------- */
  if year(ACTIVITY_DATE_SAS) = &G_ACA_REPORTING_YR.;

  drop ACTIVITY_DATE VERIFIED_FLAG;
run;

%ASSERT_ROWCOUNT(ds=SILVER.wellness_activity_clean, min=1, label=Silver Wellness Clean);

/* ============================================================
   2.5  CROSS-DATASET REFERENTIAL INTEGRITY CHECK
        Ensure every employee in plan enrollment and wellness
        records exists in the payroll master.
   ============================================================ */
proc sql;
  /* Employees in enrollment but not in payroll */
  create table work.orphan_enrollments as
  select e.EMPLOYEE_ID, 'ENROLLMENT' as SOURCE
  from   SILVER.plan_enrollments_clean e
  where  e.EMPLOYEE_ID not in (select EMPLOYEE_ID from SILVER.hr_payroll_clean);

  /* Employees in wellness but not in payroll */
  insert into work.orphan_enrollments
  select w.EMPLOYEE_ID, 'WELLNESS'
  from   SILVER.wellness_activity_clean w
  where  w.EMPLOYEE_ID not in (select EMPLOYEE_ID from SILVER.hr_payroll_clean);
quit;

%let _orphan_n = 0;
proc sql noprint;
  select count(*) into :_orphan_n trimmed from work.orphan_enrollments;
quit;

%if %eval(&_orphan_n. > 0) %then %do;
  %AUDIT_LOG(step=02_REF_INTEGRITY, status=WARN, records=&_orphan_n.,
             msg=%str(&_orphan_n. enrollment/wellness records reference unknown EMPLOYEE_IDs));
  proc print data=work.orphan_enrollments noobs;
    title "Referential Integrity Violations — Unknown Employee IDs";
  run;
  title;
%end;
%else
  %AUDIT_LOG(step=02_REF_INTEGRITY, status=SUCCESS,
             msg=All enrollment and wellness records reference known EMPLOYEE_IDs);

%AUDIT_LOG(step=02_STAGE_COMPLETE, status=SUCCESS,
           msg=%str(All 3 Silver datasets created and validated));
