/******************************************************************************
 * PROGRAM  : 00_config_and_macros.sas
 * PURPOSE  : Global configuration, library assignments (4-layer Medallion
 *            Architecture), and reusable audit/validation macros for the
 *            ACA Healthcare Analytics pipeline.
 * LAYER    : Cross-cutting concern — %include'd by all pipeline stages
 * AUTHOR   : SAS Healthcare Playground
 * VERSION  : 1.0
 * DATE     : 2024
 *
 * MEDALLION LAYERS:
 *   BRONZE  → data/processed/bronze/  (raw SAS datasets from PROC IMPORT)
 *   SILVER  → data/processed/silver/  (cleansed, standardized)
 *   GOLD    → data/processed/gold/    (aggregated, business-ready)
 *   REPORTS → data/processed/reports/ (ODS output artifacts)
 ******************************************************************************/

/* ==========================================================================
   SECTION 1: Global Options
   ========================================================================== */
options
  mprint              /* Echo resolved macro code to the SAS log            */
  mlogic              /* Trace macro logic (do/end, if/then) in log         */
  symbolgen           /* Display macro variable substitution values in log  */
  fullstimer          /* Report full CPU/memory performance metrics          */
  compress    = binary /* Apply binary compression to all output datasets   */
  obs         = MAX    /* Always process all records                        */
  errors      = 20     /* Print the first 20 errors only                   */
  fmtsearch   = (work library)
;

/* ==========================================================================
   SECTION 2: Project Root & Library Assignments
   ========================================================================== */
%let PROJECT_ROOT = /workspaces/sas-modernization-lab;
%let DATA_ROOT    = &PROJECT_ROOT./data;

/* Create the processed sub-directories if they don't yet exist */
options dlcreatedir;
libname BRONZE  "&DATA_ROOT./processed/bronze";   /* Raw SAS datasets (immutable)  */
libname SILVER  "&DATA_ROOT./processed/silver";   /* Cleansed & standardized       */
libname GOLD    "&DATA_ROOT./processed/gold";     /* Business-ready aggregates      */
libname REPORTS "&DATA_ROOT./processed/reports";  /* ODS output artifacts           */
options nodlcreatedir;

/* ==========================================================================
   SECTION 3: Global Macro Variables
   ========================================================================== */
%global
  G_PIPELINE_RUN_DT    /* Pipeline execution date (formatted)                */
  G_PIPELINE_RUN_ID    /* Unique run identifier for audit trail               */
  G_ACA_REPORTING_YR   /* Calendar year for ACA 1095-C reporting              */
  G_FTE_THRESHOLD_HRS  /* ACA full-time threshold: 130 hours/month            */
  G_WELLNESS_MAX_PTS   /* Annual cap on wellness incentive points              */
  G_LOG_LVL            /* Logging verbosity: DEBUG | INFO | WARN | ERROR      */
;

%let G_PIPELINE_RUN_DT   = %sysfunc(today(), date9.);
%let G_PIPELINE_RUN_ID   = %sysfunc(catx(_,
                             RUN,
                             %sysfunc(today(), yymmddn8.),
                             %sysfunc(compress(%sysfunc(time(), time8.), :))));
%let G_ACA_REPORTING_YR  = 2024;
%let G_FTE_THRESHOLD_HRS = 130;   /* ACA: 30 hrs/wk × 4.333 wks/mo ≈ 130 hrs */
%let G_WELLNESS_MAX_PTS  = 500;
%let G_LOG_LVL           = INFO;

/* ==========================================================================
   SECTION 4: Audit Logging Macro — %AUDIT_LOG
   Writes a pipe-delimited record to pipeline_audit.log and echoes to SAS log.
   Usage: %AUDIT_LOG(step=01_INGEST, status=SUCCESS, msg=Loaded 500 rows, records=500)
   ========================================================================== */
%macro AUDIT_LOG(step=, status=SUCCESS, msg=, records=.);
  %local _dt _tm _log_path;
  %let _dt       = %sysfunc(today(), date9.);
  %let _tm       = %sysfunc(time(),  time8.);
  %let _log_path = &DATA_ROOT./processed/reports/pipeline_audit.log;

  data _null_;
    file "&_log_path." mod;  /* MOD = append mode */
    put "|&_dt.|&_tm.|&G_PIPELINE_RUN_ID.|&step.|&status.|&records.|&msg.|";
  run;

  /* Always print ERRORs/WARNs; print DEBUG only when G_LOG_LVL=DEBUG */
  %if %upcase(&status.) = ERROR or %upcase(&status.) = WARN %then %do;
    %put %str(W)ARN: [PIPELINE][&status.][&_dt. &_tm.] Step=&step. Rec=&records. &msg.;
  %end;
  %else %if %upcase(&G_LOG_LVL.) = DEBUG or %upcase(&G_LOG_LVL.) = INFO %then %do;
    %put NOTE: [PIPELINE][&status.][&_dt. &_tm.] Step=&step. Rec=&records. &msg.;
  %end;
%mend AUDIT_LOG;

/* ==========================================================================
   SECTION 5: Row-Count Assertion Macro — %ASSERT_ROWCOUNT
   Aborts the pipeline if a dataset has fewer rows than expected.
   Usage: %ASSERT_ROWCOUNT(ds=SILVER.hr_payroll_clean, min=1, label=Payroll)
   ========================================================================== */
%macro ASSERT_ROWCOUNT(ds=, min=0, max=99999999, label=);
  %local _dsid _nobs _rc;
  %let _dsid = %sysfunc(open(&ds.));

  %if &_dsid. = 0 %then %do;
    %AUDIT_LOG(step=%str(ASSERT: &label.), status=ERROR,
               msg=%str(Dataset &ds. does not exist or cannot be opened));
    %abort cancel;
  %end;

  %let _nobs = %sysfunc(attrn(&_dsid., nobs));
  %let _rc   = %sysfunc(close(&_dsid.));

  %if %eval(&_nobs. < &min.) or %eval(&_nobs. > &max.) %then %do;
    %AUDIT_LOG(step=%str(ASSERT: &label.), status=ERROR, records=&_nobs.,
               msg=%str(Row count &_nobs. outside bounds [&min., &max.] for &ds.));
    %abort cancel;
  %end;
  %else %do;
    %AUDIT_LOG(step=%str(ASSERT: &label.), status=SUCCESS, records=&_nobs.,
               msg=%str(Row count &_nobs. is within expected bounds));
  %end;
%mend ASSERT_ROWCOUNT;

/* ==========================================================================
   SECTION 6: Column-Level Null Check Macro — %CHECK_NULLS
   Emits WARN to the audit log if the null % for a column exceeds threshold.
   Usage: %CHECK_NULLS(ds=SILVER.hr_payroll_clean, var=HIRE_DATE_SAS, threshold_pct=2)
   ========================================================================== */
%macro CHECK_NULLS(ds=, var=, threshold_pct=5);
  %local _miss_pct;

  proc sql noprint;
    select (sum(missing(&var.)) / max(count(*), 1)) * 100
    into   :_miss_pct trimmed
    from   &ds.;
  quit;

  %if %sysevalf(&_miss_pct. > &threshold_pct.) %then %do;
    %AUDIT_LOG(
      step     = %str(NULL CHECK: &ds..&var.),
      status   = WARN,
      msg      = %str(&var. is &_miss_pct.%% missing — threshold is &threshold_pct.%%)
    );
  %end;
  %else %do;
    %AUDIT_LOG(
      step   = %str(NULL CHECK: &ds..&var.),
      status = SUCCESS,
      msg    = %str(&var. null rate &_miss_pct.%% is within acceptable threshold)
    );
  %end;
%mend CHECK_NULLS;

/* ==========================================================================
   SECTION 7: Dataset Profile Macro — %PROFILE_DATASET
   Prints a quick variable-level summary (type, n, nmiss, min, max, mean).
   Usage: %PROFILE_DATASET(ds=BRONZE.hr_payroll_raw)
   ========================================================================== */
%macro PROFILE_DATASET(ds=);
  proc means data=&ds. n nmiss min max mean stackodsoutput;
    title "Data Profile: &ds.";
  run;
  proc contents data=&ds. short;
    title "Contents: &ds.";
  run;
  title;
%mend PROFILE_DATASET;

/* Initialization confirmation */
%put NOTE: *** CONFIG LOADED — Pipeline &G_PIPELINE_RUN_ID. | Date: &G_PIPELINE_RUN_DT. ***;
