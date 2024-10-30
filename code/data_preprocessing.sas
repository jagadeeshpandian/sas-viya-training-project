
%let path=/export/viya/homes/psoundra@asu.edu/projects ;
libname churn "&path/data/output" ;

 /* Drop columns: birthdate, unstructured data, a strongly correlated column, and columns used to create composite column */
data work.customer_churn_ml;
    set churn.customer_churn_abt 
    (drop= birthdate 
           review_text title 
           AvgPurchaseAmount12 
           intAdExposureCount12 socialMediaAdCountAll);
run;

title1 "Quick Listing of Variables Remaining in Churn Table";
proc contents order=varnum short;
run;
title;

proc sql noprint;
    /* Create macro variable for numeric variables */
    /* Do not include ID or target variable        */
    select name 
    into :num_vars separated by ' '
    from dictionary.columns
    where libname='WORK' /* Change to your library name */
      and memname='CUSTOMER_CHURN_ML' /* Change to your table name */
      and type='num' and (name ne "ID" and name ne "LostCustomer");

    /* Create macro variable for character variables */
    select name 
    into :char_vars separated by ' '
    from dictionary.columns
    where libname='WORK' /* library name */
      and memname='CUSTOMER_CHURN_ML' /* table name */
      and type='char';
quit;

%let target=LostCustomer;

/* Display the macro variables */
%put &num_vars;
%put &char_vars;
%put &target;