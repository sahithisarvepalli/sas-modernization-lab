/*
Purpose: Provide reusable logging helpers for SAS modernization workflows.
Inputs: message, severity, module_name.
Outputs: Standardized log lines in the SAS log.
Usage: %log_message(message=Starting Module A, severity=INFO, module_name=module_a);
*/
%macro log_message(message=, severity=INFO, module_name=unknown);
    %put NOTE: [&severity.] [&module_name.] &message.;
%mend log_message;
