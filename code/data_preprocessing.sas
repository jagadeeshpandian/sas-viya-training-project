
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


proc sort data=work.customer_churn_ml;
  by lostcustomer;
run;

proc surveyselect data=work.customer_churn_ml out=work.train_test_split
    samprate=0.7 /* 70% training data */
    seed=12345 /* Set seed for reproducibility */
    outall /* Keeps both selected and non-selected observations */
    method=srs; /* Simple Random Sampling */
    strata LostCustomer; /* Stratify by Target variable */
run;


/* Create training and testing datasets based on selection */
data work.customer_churn_ml_train work.customer_churn_ml_test;
    drop selected selectionprob samplingweight;
    set work.train_test_split;
    if Selected then output work.customer_churn_ml_train;
    else output work.customer_churn_ml_test;
run;

proc varimpute data=work.customer_churn_ml_train seed=12345;
  input avgDiscountValue12 techSupportEval customerAge/ ctech=mean;
  output out=work.customer_churn_ml_train_i copyvar=(_all_);
  code file="&path/code/imputing_vars.sas";
run;

data work.customer_churn_ml_train_i;
   set work.customer_churn_ml_train_i(drop=avgDiscountValue12 techSupportEval customerAge);
run;

data work.customer_churn_ml_test_i(drop=avgDiscountValue12 techSupportEval customerAge);
  set work.customer_churn_ml_test;
  %include "&path/code/imputing_vars.sas";
run;


data work.customer_churn_ml_train_il;
   set work.customer_churn_ml_train_i;
   log_LastPurchaseAmount=log(LastPurchaseAmount+1);
   log_AvgPurchaseAmountTotal=log(AvgPurchaseAmountTotal+1);
   logi_avgDiscountValue12=log(IM_avgDiscountValue12+1);
   log_customersales=log(customersales+1);
   log_AvgPurchasePerAd12=log(AvgPurchasePerAd12+1);
   format _numeric_ best12.;
run;

data work.customer_churn_ml_test_il;
  set work.customer_churn_ml_test_i;
  log_LastPurchaseAmount=log(LastPurchaseAmount+1);
  log_AvgPurchaseAmountTotal=log(AvgPurchaseAmountTotal+1);
  logi_avgDiscountValue12=log(IM_avgDiscountValue12+1);
  log_customersales=log(customersales+1);
  log_AvgPurchasePerAd12=log(AvgPurchasePerAd12+1);
  format _numeric_ best12.;
run;

proc sql noprint;
    /* Create macro variable for numeric variables */
    /* Do not include ID or target variable        */
    select name 
    into :num_vars_il separated by ' '
    from dictionary.columns
    where libname='WORK' /* Change to your library name */
      and memname='CUSTOMER_CHURN_ML_TRAIN_IL' /* Change to your table name */
      and type='num' and (name ne "ID" and name ne "LostCustomer");

    /* Create macro variable for character variables */
    select name 
    into :char_vars_il separated by ' '
    from dictionary.columns
    where libname='WORK' /* library name */
      and memname='CUSTOMER_CHURN_ML_TRAIN_IL' /* table name */
      and type='char';
quit;

%put &num_vars_il;
%put &char_vars_il;

proc stdize data=work.customer_churn_ml_train_il
  out=work.customer_churn_ml_train_ils method=std
  outstat=train_std;
  var &num_vars_il;
run;

proc stdize data=work.customer_churn_ml_test_il
  out=work.customer_churn_ml_test_ils
  method=in(train_std);
  var &num_vars_il;
run;

title2 'Supervised variable Selection/Reduction';
proc varreduce data=work.customer_churn_ml_train_ils matrix=COV tech=DSC;
   ods output SelectionSummary=variable_selection_summary SelectedEffects=variable_selected;
   class &target &char_vars_il;
   reduce supervised &target = &char_vars_il &num_vars_il / maxiter=15 BIC;
run;

/* Plot the BIC values over iterations during the variable selection process */
proc sgplot data=variable_selection_summary;
   series x=Iteration  y=BIC;
run;

/* Capture selected variables */
proc sql noprint;
    select variable into :selected_class_s separated by ' '
    from variable_selected
    where type = 'CLASS';

    select variable into :selected_num_s separated by ' '
    from variable_selected
    where type = 'INTERVAL';
quit;

%put From Supervised Method;
%put Selected Class Variables: &selected_class_s;
%put Selected Interval Variables: &selected_num_s;

title2 'Unsupervised variable Selection/Reduction';
proc varreduce data=work.customer_churn_ml_train_ils;
   class &char_vars_il;
   reduce unsupervised &char_vars_il &num_vars_il /
            varianceexplained=0.9 minvarianceincrement=0.01;
   ods output selectionsummary=work.summary;
   ods output selectedeffects=work.effects;
run;

data work.out_iter (keep=Iteration VarExp Base Increment Parameter);
   set work.summary;
   Increment=dif(VarExp);
   if Increment=. then
         Increment=0;
   Base=VarExp - Increment;
run;

proc transpose data=work.out_iter out=work.out_iter_trans;
   by Iteration VarExp Parameter;
run;

proc sort data=work.out_iter_trans;
   label _NAME_='Group';
   by _NAME_;
run;

proc sgplot data=work.out_iter_trans;
   title 'Variance Explained by Iteration';
   yaxis label='Variance Explained';
   vbar Iteration / response=COL1 group=_NAME_;
run;

proc delete data=work.out_iter work.out_iter_trans;
run;

/* Creates macro variable for interval predictors  */

/* Capture selected variables */
proc sql noprint;
    select variable into :selected_class_u separated by ' '
    from work.effects
    where type = 'CLASS';

    select variable into :selected_num_u separated by ' '
    from work.effects
    where type = 'INTERVAL';
quit;

%put From Unsupervised Method;
%put Selected Class Variables: &selected_class_u;
%put Selected Interval Variables: &selected_num_u;

data work.customer_churn_ml_train_final;
    set work.customer_churn_ml_train_ils; 
    keep id lostcustomer 
         &selected_class_u &selected_num_u 
         &selected_class_s &selected_num_s; 
run;

title1 "List of Variables in Final Training Churn Table";
proc contents order=varnum short;
run;
title;

proc datasets lib=churn ;
   delete customer_churn_ml_train_final customer_churn_ml_test_final ;
   copy in=work out=churn ;
   select customer_churn_ml_train_final customer_churn_ml_test_ils ;
   change customer_churn_ml_test_ils=customer_churn_ml_test_final ;
quit ;