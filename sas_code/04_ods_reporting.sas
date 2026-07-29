/******************************************************************************
 * PROGRAM  : 04_ods_reporting.sas
 * PURPOSE  : Stage 04 — Automated executive-dashboard and regulatory report
 *            generation using PROC REPORT, PROC TABULATE, ODS EXCEL, and
 *            ODS PDF.
 *
 * KEY SAS TECHNIQUES DEMONSTRATED:
 *   • ODS EXCEL       — multi-sheet workbook with autofilter, frozen headers,
 *                       and conditional cell shading
 *   • ODS PDF         — styled regulatory report with PDF bookmarks/TOC
 *   • PROC REPORT     — columnar report with COMPUTE blocks for dynamic
 *                       row/cell highlighting and summary rows
 *   • PROC TABULATE   — cross-tabulation with nested CLASS variables
 *   • CALL DEFINE()   — runtime cell-level style overrides in PROC REPORT
 *   • RBREAK / BREAK  — report section totals and grand totals
 *
 * OUTPUTS : data/processed/reports/ACA_Compliance_Report_<YEAR>.xlsx
 *            data/processed/reports/ACA_Regulatory_Report_<YEAR>.pdf
 *            data/processed/reports/pipeline_audit.log
 * LAYER   : Stage 04 (Reporting / Output Artifacts)
 * DEPENDS : 03_aca_business_logic.sas must have run first.
 ******************************************************************************/

%include "/workspaces/sas-modernization-lab/sas_code/00_config_and_macros.sas";

%let REPORT_DATE_LABEL = %sysfunc(today(), worddate.);
%let EXCEL_FILE = &DATA_ROOT./processed/reports/ACA_Compliance_Report_&G_ACA_REPORTING_YR..xlsx;
%let PDF_FILE   = &DATA_ROOT./processed/reports/ACA_Regulatory_Report_&G_ACA_REPORTING_YR..pdf;

%AUDIT_LOG(step=04_STAGE_START, status=START,
           msg=%str(Reporting stage started — generating Excel and PDF outputs));

/* ===========================================================================
   4.1  ODS EXCEL — MULTI-SHEET COMPLIANCE WORKBOOK
   =========================================================================== */
%AUDIT_LOG(step=04_ODS_EXCEL, status=START, msg=Generating Excel compliance workbook);

ods excel file    = "&EXCEL_FILE."
  options(
    sheet_interval       = 'proc'        /* New proc = new sheet            */
    embedded_titles      = 'yes'
    embedded_footnotes   = 'yes'
    frozen_headers       = 'yes'         /* Freeze header row for scrolling  */
    autofilter           = 'all'         /* Enable column filters in Excel   */
    flow                 = 'tables'
    tab_color            = 'blue'
  );

/* ---------------------------------------------------------------------------
   Sheet 1: Monthly FTE Dashboard
   Shows org-level FTE by month and highlights months where the org
   is an Applicable Large Employer (ALE) under IRC §4980H(a).
   --------------------------------------------------------------------------- */
ods excel options(sheet_name='Monthly FTE Dashboard' tab_color='cx003087');

title1 j=c height=14pt
  "Healthcare Payer Analytics — ACA Compliance Dashboard";
title2 j=c height=11pt
  "Reporting Year: &G_ACA_REPORTING_YR. | Generated: &REPORT_DATE_LABEL.";
footnote1 j=l height=8pt
  "Source: HR Payroll Feed | Rule: ≥50 FTE/month average → Applicable Large Employer";
footnote2 j=l height=8pt
  "ACA Reference: IRC §4980H | FTE Threshold: &G_FTE_THRESHOLD_HRS. hrs/month";

proc report data=GOLD.org_monthly_fte nowd style(report)=[cellpadding=4];
  columns MONTH_LABEL EMPLOYEE_COUNT FULLTIME_HEADCOUNT TOTAL_FTE_UNITS IS_ALE_MONTH;

  define MONTH_LABEL        / display 'Month'
    style(column) = [width=10 just=left];
  define EMPLOYEE_COUNT     / display 'Total Employees'
    style(column) = [just=right];
  define FULLTIME_HEADCOUNT / display 'FT Headcount (≥130 hrs)'
    style(column) = [just=right];
  define TOTAL_FTE_UNITS    / display 'Total FTE Units'
    format=8.2 style(column) = [just=right];
  define IS_ALE_MONTH       / display 'ALE Threshold Met?'
    style(column) = [just=center width=18];

  /* Conditional cell shading on the ALE flag column */
  compute IS_ALE_MONTH;
    if IS_ALE_MONTH = 1 then
      call define(_col_, 'style',
        'style=[background=cxD4EDDA color=cx155724 font_weight=bold]');
    else
      call define(_col_, 'style',
        'style=[background=cxF8D7DA color=cx721C24]');
  endcomp;

  /* Grand-total row */
  rbreak after / summarize style=[fontweight=bold background=cxE2EFDA];
run;

/* ---------------------------------------------------------------------------
   Sheet 2: 1095-C Offer Code Distribution
   Cross-tab of Line 14 codes by ACA full-time status using PROC TABULATE.
   --------------------------------------------------------------------------- */
ods excel options(sheet_name='1095-C Offer Code Summary' tab_color='cx28A745');

title1 "ACA Form 1095-C — Line 14 Offer Code Distribution";
title2 "Reporting Year: &G_ACA_REPORTING_YR.";
footnote1 j=l height=8pt
  "Line 14 Reference: IRS Instructions for Forms 1094-C and 1095-C";

proc tabulate data=GOLD.aca_1095c_determination format=comma8.0;
  class  LINE_14_OFFER_CODE LINE_14_DESC ACA_FULLTIME_EMPLOYEE PENALTY_RISK_FLAG;
  var    MONTHS_FULLTIME;

  table
    LINE_14_OFFER_CODE=' ' * LINE_14_DESC=' ',
    N='Employee Count' *
      ACA_FULLTIME_EMPLOYEE='ACA Full-Time?'
    / box    = 'Line 14 Code × Full-Time Status'
      rts    = 60
      indent = 4;

  /* Penalty-risk sub-table */
  table
    PENALTY_RISK_FLAG=' ',
    N='Employees at §4980H(b) Penalty Risk'
    / box = 'Penalty Risk Summary';
run;

/* ---------------------------------------------------------------------------
   Sheet 3: Employee-Level 1095-C Detail
   Full employee roster with all 1095-C fields for filing review.
   --------------------------------------------------------------------------- */
ods excel options(sheet_name='Employee 1095-C Detail' tab_color='cxFFC107');

title1 "Employee-Level Form 1095-C Filing Detail";
title2 "Reporting Year: &G_ACA_REPORTING_YR. | All ACA Full-Time Employees";

proc report data=GOLD.aca_1095c_determination nowd;
  columns EMPLOYEE_ID LAST_NAME FIRST_NAME STATE_CD JOB_CLASS EMP_STATUS
          ACA_FULLTIME_EMPLOYEE MONTHS_FULLTIME AVG_MONTHLY_HOURS
          LINE_14_OFFER_CODE LINE_16_SAFE_HBR
          PLAN_CODE COVERAGE_TIER PENALTY_RISK_FLAG;

  define EMPLOYEE_ID          / display 'Employee ID'
    style(column)=[width=12 background=cxF8F9FA];
  define LAST_NAME            / display 'Last Name';
  define FIRST_NAME           / display 'First Name';
  define STATE_CD             / display 'State' style(column)=[width=6 just=center];
  define JOB_CLASS            / display 'Job Class';
  define EMP_STATUS           / display 'Status' style(column)=[width=12];
  define ACA_FULLTIME_EMPLOYEE/ display 'ACA FT?' style(column)=[just=center width=8];
  define MONTHS_FULLTIME      / display 'FT Months' style(column)=[just=right];
  define AVG_MONTHLY_HOURS    / display 'Avg Hrs/Mo' format=8.1 style(column)=[just=right];
  define LINE_14_OFFER_CODE   / display 'Line 14'
    style(column)=[just=center width=10 background=cxFFF3CD font_weight=bold];
  define LINE_16_SAFE_HBR     / display 'Line 16'
    style(column)=[just=center width=10];
  define PLAN_CODE            / display 'Plan Code';
  define COVERAGE_TIER        / display 'Coverage Tier';
  define PENALTY_RISK_FLAG    / display 'Penalty Risk?'
    style(column)=[just=center width=12];

  /* Highlight employees with potential §4980H penalty exposure */
  compute PENALTY_RISK_FLAG;
    if PENALTY_RISK_FLAG = 'Y' then
      call define(_row_, 'style', 'style=[background=cxFFE5E5]');
  endcomp;
run;

/* ---------------------------------------------------------------------------
   Sheet 4: Wellness Incentive Summary
   Tier distribution with ACA tobacco-program compliance flags.
   --------------------------------------------------------------------------- */
ods excel options(sheet_name='Wellness Incentive Summary' tab_color='cx6F42C1');

title1 "Employee Wellness Incentive Program — Tier Summary";
title2 "Reporting Year: &G_ACA_REPORTING_YR. | Max Annual Points: &G_WELLNESS_MAX_PTS.";
footnote1 j=l height=8pt
  "ACA Incentive Limit: 30% of annual premium (50% for tobacco-cessation programs)";

proc report data=GOLD.wellness_incentive_summary nowd;
  columns INCENTIVE_TIER ACA_TOBACCO_COMPLIANT N
          TOTAL_RAW_PTS TOTAL_CAPPED_PTS INCENTIVE_VALUE_USD TOTAL_EVENTS;

  define INCENTIVE_TIER        / group 'Incentive Tier'
    style(column)=[font_weight=bold];
  define ACA_TOBACCO_COMPLIANT / group 'Tobacco Compliant?'
    style(column)=[just=center];
  define N                     / 'Employee Count' format=comma8.0;
  define TOTAL_RAW_PTS         / analysis mean 'Avg Raw Points' format=8.1;
  define TOTAL_CAPPED_PTS      / analysis mean 'Avg Capped Points' format=8.1;
  define INCENTIVE_VALUE_USD   / analysis mean 'Avg Incentive ($)' format=dollar8.0;
  define TOTAL_EVENTS          / analysis sum  'Total Activity Events' format=comma10.0;

  /* Color-code tiers */
  compute INCENTIVE_TIER;
    select (INCENTIVE_TIER);
      when ('PLATINUM') call define(_col_, 'style', 'style=[background=cxE0E0E0]');
      when ('GOLD')     call define(_col_, 'style', 'style=[background=cxFFF3CD]');
      when ('SILVER')   call define(_col_, 'style', 'style=[background=cxF8F9FA]');
      otherwise         call define(_col_, 'style', 'style=[background=cxCD7F32 color=white]');
    end;
  endcomp;

  rbreak after / summarize style=[fontweight=bold background=cxE2EFDA];
run;

ods excel close;

%AUDIT_LOG(step=04_ODS_EXCEL, status=SUCCESS,
           msg=%str(Excel workbook written to &EXCEL_FILE.));

/* ===========================================================================
   4.2  ODS PDF — REGULATORY COMPLIANCE REPORT
        A formal, bookmarked PDF for regulatory audit submission.
   =========================================================================== */
%AUDIT_LOG(step=04_ODS_PDF, status=START, msg=Generating PDF regulatory report);

options nodate nonumber;

ods pdf file    = "&PDF_FILE."
        style   = Journal2
        pdftoc  = 3              /* Table of contents nesting depth   */
        bookmarkgen = yes        /* Generate PDF bookmark panel        */
        notoc;                   /* TOC is auto-generated by bookmarks */

/* PDF Cover Page */
ods pdf text =
  "^{style[fontsize=20pt fontweight=bold just=c]ACA Employer Shared Responsibility}";
ods pdf text =
  "^{style[fontsize=20pt fontweight=bold just=c]Compliance Report}";
ods pdf text = " ";
ods pdf text =
  "^{style[fontsize=14pt just=c]Healthcare Payer Analytics Organization}";
ods pdf text =
  "^{style[fontsize=12pt just=c]Reporting Year: &G_ACA_REPORTING_YR.}";
ods pdf text =
  "^{style[fontsize=10pt just=c color=gray]Generated: &REPORT_DATE_LABEL.}";
ods pdf text = " ";
ods pdf text =
  "^{style[fontsize=9pt just=c color=darkred fontweight=bold]" ||
  "CONFIDENTIAL — For Regulatory Filing Purposes Only}";
ods pdf text = " ";
ods pdf text =
  "^{style[fontsize=8pt just=c color=gray]" ||
  "Prepared pursuant to IRC §4980H | IRS Publication 5196}";

/* -------- Section 1: ALE Determination ---------------------------------- */
ods proclabel "Section 1: ALE Determination";

title1 height=14pt "Section 1: Applicable Large Employer (ALE) Determination";
title2 height=10pt
  "Rule: Monthly FTE average ≥ 50 over the prior calendar year → ALE status";

proc report data=GOLD.org_monthly_fte nowd
  style(report) = [rules=all frame=box]
  style(header) = [background=cx003087 color=white fontweight=bold just=center];

  columns MONTH_LABEL EMPLOYEE_COUNT FULLTIME_HEADCOUNT TOTAL_FTE_UNITS IS_ALE_MONTH;

  define MONTH_LABEL        / display 'Reporting Month';
  define EMPLOYEE_COUNT     / display 'Total Employees';
  define FULLTIME_HEADCOUNT / display 'Full-Time Headcount';
  define TOTAL_FTE_UNITS    / display 'FTE Units (IRC §4980H)' format=8.2;
  define IS_ALE_MONTH       / display 'ALE Threshold Met (≥50)';

  rbreak after / summarize
    style=[fontweight=bold background=cxE2EFDA];

  compute IS_ALE_MONTH;
    if IS_ALE_MONTH = 1 then
      call define(_col_, 'style', 'style=[background=cxD4EDDA fontweight=bold]');
  endcomp;

  compute after;
    MONTH_LABEL = 'FULL YEAR TOTAL';
  endcomp;
run;

/* -------- Section 2: 1095-C Filing Statistics --------------------------- */
ods proclabel "Section 2: Form 1095-C Statistics";

title1 height=14pt "Section 2: Form 1095-C — Offer of Coverage Statistics";
title2 height=10pt
  "Employer is required to furnish 1095-C to each ACA full-time employee";

proc report data=GOLD.aca_1095c_determination nowd
  style(report) = [rules=all frame=box]
  style(header) = [background=cx003087 color=white fontweight=bold just=center];

  columns LINE_14_OFFER_CODE LINE_14_DESC N MONTHS_FULLTIME;

  define LINE_14_OFFER_CODE / group   'Line 14 Code'
    style(column)=[just=center font_weight=bold width=12];
  define LINE_14_DESC       / group   'Offer of Coverage Description';
  define N                  / 'Employee Count'     format=comma8.0;
  define MONTHS_FULLTIME    / analysis mean 'Avg FT Months' format=8.1;

  rbreak after / summarize
    style=[fontweight=bold background=cxE2EFDA];
run;

/* -------- Section 3: Penalty Risk Summary ------------------------------- */
ods proclabel "Section 3: IRC §4980H Penalty Risk";

title1 height=14pt "Section 3: §4980H(b) Employer Penalty Risk Assessment";
title2 height=10pt
  "Employees with offer code 1H who are ACA full-time represent potential penalty exposure";

proc report data=GOLD.aca_1095c_determination (where=(PENALTY_RISK_FLAG='Y')) nowd
  style(report) = [rules=all frame=box]
  style(header) = [background=cx721C24 color=white fontweight=bold just=center];

  columns EMPLOYEE_ID LAST_NAME FIRST_NAME STATE_CD JOB_CLASS
          MONTHS_FULLTIME LINE_14_OFFER_CODE LINE_16_SAFE_HBR;

  define EMPLOYEE_ID         / display 'Employee ID';
  define LAST_NAME           / display 'Last Name';
  define FIRST_NAME          / display 'First Name';
  define STATE_CD            / display 'State' style(column)=[just=center];
  define JOB_CLASS           / display 'Job Class';
  define MONTHS_FULLTIME     / display 'FT Months' style(column)=[just=right];
  define LINE_14_OFFER_CODE  / display 'Line 14'
    style(column)=[just=center font_weight=bold background=cxFFE5E5];
  define LINE_16_SAFE_HBR    / display 'Line 16' style(column)=[just=center];
run;

/* -------- Section 4: Wellness Program Compliance Summary ---------------- */
ods proclabel "Section 4: Wellness Program Compliance";

title1 height=14pt "Section 4: Wellness Incentive Program — ACA Compliance Summary";
title2 height=10pt
  "ACA limit: incentives ≤ 30% of total plan premium (50% for tobacco-cessation)";

proc report data=GOLD.wellness_incentive_summary nowd
  style(report) = [rules=all frame=box]
  style(header) = [background=cx003087 color=white fontweight=bold just=center];

  columns INCENTIVE_TIER N TOTAL_CAPPED_PTS INCENTIVE_VALUE_USD ACA_TOBACCO_COMPLIANT;

  define INCENTIVE_TIER       / group 'Incentive Tier' style(column)=[font_weight=bold];
  define N                    / 'Employees' format=comma8.0;
  define TOTAL_CAPPED_PTS     / analysis mean 'Avg Points (Capped)' format=8.1;
  define INCENTIVE_VALUE_USD  / analysis sum  'Total Incentive Value ($)' format=dollar10.0;
  define ACA_TOBACCO_COMPLIANT/ group 'Tobacco Compliant?' style(column)=[just=center];

  rbreak after / summarize style=[fontweight=bold background=cxE2EFDA];
run;

ods pdf close;

title;
footnote;
options date number;

%AUDIT_LOG(step=04_ODS_PDF, status=SUCCESS,
           msg=%str(PDF report written to &PDF_FILE.));

%AUDIT_LOG(step=04_STAGE_COMPLETE, status=SUCCESS,
           msg=%str(*** FULL PIPELINE COMPLETE — Run ID: &G_PIPELINE_RUN_ID. ***));

%put NOTE: *** PIPELINE COMPLETE — All 4 stages executed successfully ***;
%put NOTE: *** Run ID: &G_PIPELINE_RUN_ID. | Date: &G_PIPELINE_RUN_DT. ***;
%put NOTE: *** Excel: &EXCEL_FILE. ***;
%put NOTE: *** PDF:   &PDF_FILE. ***;
