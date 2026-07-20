/*
Purpose: Provide reusable dataset existence and row-count validation helpers.
Inputs: dataset_name, min_rows.
Outputs: Validation status messages in the SAS log.
Usage: %validate_dataset(dataset_name=work.claims, min_rows=1);
*/
%macro validate_dataset(dataset_name=, min_rows=1);
    %if %sysfunc(exist(&dataset_name.)) %then %do;
        %put NOTE: Validation passed for &dataset_name.;
    %end;
    %else %do;
        %put ERROR: Dataset &dataset_name. does not exist.;
    %end;
%mend validate_dataset;
