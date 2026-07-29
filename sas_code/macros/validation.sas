/*
Purpose: Provide reusable dataset existence and row-count validation helpers.
Inputs: dataset_name, min_rows.
Outputs: Validation status messages in the SAS log.
Usage: %validate_dataset(dataset_name=work.claims, min_rows=1);
*/
%macro validate_dataset(dataset_name=, min_rows=1);
    %local dsid nobs rc;

    %if %sysfunc(exist(&dataset_name.)) %then %do;
        %let dsid = %sysfunc(open(&dataset_name.));

        %if &dsid. %then %do;
            %let nobs = %sysfunc(attrn(&dsid., nlobs));
            %let rc = %sysfunc(close(&dsid.));

            %if &nobs. >= &min_rows. %then %do;
                %put NOTE: Validation passed for &dataset_name. with &nobs. row(s).;
            %end;
            %else %do;
                %put ERROR: Dataset &dataset_name. has only &nobs. row(s); minimum is &min_rows..;
            %end;
        %end;
        %else %do;
            %put ERROR: Dataset &dataset_name. exists but could not be opened for validation.;
        %end;
    %end;
    %else %do;
        %put ERROR: Dataset &dataset_name. does not exist.;
    %end;
%mend validate_dataset;
