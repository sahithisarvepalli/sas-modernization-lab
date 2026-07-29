/******************************************************************************
 * PROGRAM  : 01_data_ingestion.sas
 * PURPOSE  : Bronze Layer — Land raw CSV files into SAS datasets via
 *            PROC IMPORT, then run structural integrity and format
 *            validation checks for all three healthcare payer feeds.
 *
 * INPUTS  : data/raw/hr_payroll.csv
 *            data/raw/plan_enrollments.csv
 *            data/raw/wellness_activity.csv
 * OUTPUTS : BRONZE.hr_payroll_raw
 *            BRONZE.plan_enrollments_raw
 *            BRONZE.wellness_activity_raw
 *            BRONZE.ingestion_summary
 * LAYER   : Stage 01 (Bronze / Raw Ingestion)
 * DEPENDS : 00_config_and_macros.sas
 ******************************************************************************/

%include "/workspaces/sas-modernization-lab/sas_code/00_config_and_macros.sas";

%AUDIT_LOG(step=01_STAGE_START, status=START,
           msg=%str(Bronze ingestion pipeline started for run &G_PIPELINE_RUN_ID.));

/* ============================================================
   1.1  HR PAYROLL FEED  (hr_payroll.csv)
   Schema:
     EMPLOYEE_ID    char(9)   — Two-letter prefix + 7 digits (e.g. EM0000001)
     LAST_NAME      char      — Employee surname (raw UPPER case from source)
     FIRST_NAME     char      — Given name
     DEPT_CODE      char(6)   — Maps to department master reference table
     JOB_CLASS      char      — Title/classification code
     HIRE_DATE      char      — MM/DD/YYYY string (converted in Silver)
     HOURLY_RATE    num       — Base hourly wage (USD)
     STATE_CD       char(2)   — US state code for tax/regulatory jurisdictions
     HOURS_JAN ..
     HOURS_DEC      num       — Actual hours worked per calendar month
     EMP_STATUS     char      — ACTIVE | TERMINATED | LEAVE
   ============================================================ */
%AUDIT_LOG(step=01_INGEST_PAYROLL, status=START, msg=Reading hr_payroll.csv into BRONZE);

proc import
  datafile = "&DATA_ROOT./raw/hr_payroll.csv"
  out      = BRONZE.hr_payroll_raw
  dbms     = csv
  replace;
  getnames    = yes;
  guessingrows = MAX;   /* Scan all rows to infer column types correctly */
run;

/* --- Structural checks ----------------------------------------------- */
%ASSERT_ROWCOUNT(ds=BRONZE.hr_payroll_raw, min=1, max=100000, label=HR Payroll Raw);
%CHECK_NULLS(ds=BRONZE.hr_payroll_raw, var=EMPLOYEE_ID, threshold_pct=0);
%CHECK_NULLS(ds=BRONZE.hr_payroll_raw, var=HIRE_DATE,   threshold_pct=1);

/* --- Format validation: EMPLOYEE_ID must match /^[A-Z]{2}[0-9]{7}$/ --- */
proc sql noprint;
  select count(*) as invalid_ids
  into   :_bad_ids trimmed
  from   BRONZE.hr_payroll_raw
  where  not prxmatch('/^[A-Z]{2}[0-9]{7}$/', strip(upcase(EMPLOYEE_ID)));
quit;

%if %eval(&_bad_ids. > 0) %then
  %AUDIT_LOG(step=01_VALIDATE_EMP_ID, status=WARN, records=&_bad_ids.,
             msg=%str(&_bad_ids. EMPLOYEE_IDs fail format check /^[A-Z]{2}[0-9]{7}$/));
%else
  %AUDIT_LOG(step=01_VALIDATE_EMP_ID, status=SUCCESS,
             msg=All EMPLOYEE_IDs match the required format);

/* --- Business rule: HOURLY_RATE must be > 0 and <= statutory max ($500) */
proc sql noprint;
  select count(*) as bad_rates
  into   :_bad_rates trimmed
  from   BRONZE.hr_payroll_raw
  where  HOURLY_RATE <= 0 or HOURLY_RATE > 500 or missing(HOURLY_RATE);
quit;

%if %eval(&_bad_rates. > 0) %then
  %AUDIT_LOG(step=01_VALIDATE_RATE, status=WARN, records=&_bad_rates.,
             msg=%str(&_bad_rates. records have HOURLY_RATE outside the range (0, 500]));

/* ============================================================
   1.2  PLAN ENROLLMENT FEED  (plan_enrollments.csv)
   Schema:
     EMPLOYEE_ID      char    — Foreign key to hr_payroll
     PLAN_CODE        char(8) — Maps to plan master reference table
     COVERAGE_TIER    char    — EMPLOYEE | EMPLOYEE+SPOUSE | EMPLOYEE+FAMILY
     ENROLLMENT_DT    char    — MM/DD/YYYY enrollment effective date
     TERMINATION_DT   char    — MM/DD/YYYY (blank = still-active enrollment)
     SUBSIDY_ELIGIBLE char(1) — Y/N — Qualified for ACA premium tax credit
   ============================================================ */
%AUDIT_LOG(step=01_INGEST_ENROLLMENT, status=START, msg=Reading plan_enrollments.csv into BRONZE);

proc import
  datafile = "&DATA_ROOT./raw/plan_enrollments.csv"
  out      = BRONZE.plan_enrollments_raw
  dbms     = csv
  replace;
  getnames    = yes;
  guessingrows = MAX;
run;

%ASSERT_ROWCOUNT(ds=BRONZE.plan_enrollments_raw, min=1, max=200000, label=Plan Enrollments Raw);
%CHECK_NULLS(ds=BRONZE.plan_enrollments_raw, var=PLAN_CODE,     threshold_pct=0);
%CHECK_NULLS(ds=BRONZE.plan_enrollments_raw, var=COVERAGE_TIER, threshold_pct=2);

/* --- Referential integrity: all COVERAGE_TIER values must be in allowed set */
proc sql noprint;
  select count(*) as bad_tiers
  into   :_bad_tiers trimmed
  from   BRONZE.plan_enrollments_raw
  where  upcase(strip(COVERAGE_TIER)) not in
           ('EMPLOYEE', 'EMPLOYEE+SPOUSE', 'EMPLOYEE+FAMILY');
quit;

%if %eval(&_bad_tiers. > 0) %then
  %AUDIT_LOG(step=01_VALIDATE_TIER, status=WARN, records=&_bad_tiers.,
             msg=%str(&_bad_tiers. records have unrecognized COVERAGE_TIER values));

/* --- Temporal integrity: TERMINATION_DT must not precede ENROLLMENT_DT --- */
proc sql noprint;
  select count(*) as inverted
  into   :_inv_dates trimmed
  from   BRONZE.plan_enrollments_raw
  where  TERMINATION_DT ne ''
    and  input(TERMINATION_DT, mmddyy10.) < input(ENROLLMENT_DT, mmddyy10.);
quit;

%if %eval(&_inv_dates. > 0) %then
  %AUDIT_LOG(step=01_VALIDATE_DATES, status=WARN, records=&_inv_dates.,
             msg=%str(&_inv_dates. rows have TERMINATION_DT earlier than ENROLLMENT_DT));

/* ============================================================
   1.3  WELLNESS ACTIVITY FEED  (wellness_activity.csv)
   Schema:
     EMPLOYEE_ID    char    — Foreign key to hr_payroll
     ACTIVITY_DATE  char    — MM/DD/YYYY event date
     ACTIVITY_TYPE  char    — Wellness program event category
     POINTS_EARNED  num     — Points for this event [0, 100]
     VENDOR_CODE    char    — Third-party vendor identifier
     VERIFIED_FLAG  char(1) — Y = employer-verified; N = pending/rejected
   ============================================================ */
%AUDIT_LOG(step=01_INGEST_WELLNESS, status=START, msg=Reading wellness_activity.csv into BRONZE);

proc import
  datafile = "&DATA_ROOT./raw/wellness_activity.csv"
  out      = BRONZE.wellness_activity_raw
  dbms     = csv
  replace;
  getnames    = yes;
  guessingrows = MAX;
run;

%ASSERT_ROWCOUNT(ds=BRONZE.wellness_activity_raw, min=1, max=500000, label=Wellness Activity Raw);
%CHECK_NULLS(ds=BRONZE.wellness_activity_raw, var=EMPLOYEE_ID,   threshold_pct=0);
%CHECK_NULLS(ds=BRONZE.wellness_activity_raw, var=POINTS_EARNED, threshold_pct=5);

/* --- POINTS_EARNED must be numeric and in [0, 100] per event ----------- */
proc sql noprint;
  select count(*) as bad_pts
  into   :_bad_pts trimmed
  from   BRONZE.wellness_activity_raw
  where  missing(POINTS_EARNED) or POINTS_EARNED < 0 or POINTS_EARNED > 100;
quit;

%if %eval(&_bad_pts. > 0) %then
  %AUDIT_LOG(step=01_VALIDATE_PTS, status=WARN, records=&_bad_pts.,
             msg=%str(&_bad_pts. wellness records have POINTS_EARNED outside [0, 100]));

/* ============================================================
   1.4  PIPELINE LANDING-ZONE SUMMARY
        Creates a metadata dataset recording record counts and
        run details — the start of the data lineage trail.
   ============================================================ */
proc sql;
  create table BRONZE.ingestion_summary as
  select
    "&G_PIPELINE_RUN_ID."  as RUN_ID          length=40,
    today()                as RUN_DATE         format=date9.,
    'hr_payroll_raw'       as DATASET          length=40,
    count(*)               as RECORD_COUNT
  from BRONZE.hr_payroll_raw

  union all
  select "&G_PIPELINE_RUN_ID.", today(), 'plan_enrollments_raw',  count(*)
  from BRONZE.plan_enrollments_raw

  union all
  select "&G_PIPELINE_RUN_ID.", today(), 'wellness_activity_raw', count(*)
  from BRONZE.wellness_activity_raw;
quit;

proc print data=BRONZE.ingestion_summary noobs label;
  title "Stage 01 — Bronze Layer Ingestion Summary | Run: &G_PIPELINE_RUN_ID.";
  var RUN_DATE DATASET RECORD_COUNT;
  label RECORD_COUNT = 'Records Landed';
run;

title;

%AUDIT_LOG(step=01_STAGE_COMPLETE, status=SUCCESS,
           msg=%str(All 3 feeds landed to BRONZE libref — see BRONZE.ingestion_summary));
