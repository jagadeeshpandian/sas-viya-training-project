
%let path=/export/viya/homes/psoundra@asu.edu/projects ;
libname churn "&path/data/output" ;

proc copy in=churn out=work ;
   select customer_churn_ml_train_final customer_churn_ml_test_final ;
run ;

proc sql noprint;
    /* Create macro variable for numeric variables */
    /* Do not include ID or target variables       */
    select name 
    into :num_vars separated by ' '
    from dictionary.columns
    where libname='WORK' /* Change to your library name */
      and memname='CUSTOMER_CHURN_ML_TRAIN_FINAL' /* Change to your table name */
      and type='num' and (name ne "ID" and name ne "LostCustomer");

    /* Create macro variable for character variables */
    select name 
    into :char_vars separated by ' '
    from dictionary.columns
    where libname='WORK' /* library name */
      and memname='CUSTOMER_CHURN_ML_TRAIN_FINAL' /* table name */
      and type='char';
quit;
/* Create macro variable for target variable */
%let target=LostCustomer;

/* Display the macro variables */
%put &num_vars;
%put &char_vars;
%put &target;

title2 'Logistic Regression Model on Churn Data';
proc logselect data=work.customer_churn_ml_train_final;
    class &char_vars &target;
    model &target(event='1')=&char_vars &num_vars;
    /* Specify variable selection technique*/
    selection method=elasticnet;
    /* Generate score code */
    code file="&path/code/logscore.sas";
run;

/* Score test data with the LOGSELECT model using the SAS Data Step code just created */

title2 'Scoring test data using SAS Data Step code from proc logselect';
data log_scored ;
   set work.customer_churn_ml_test_final;
   %include "&path/code/logscore.sas";
run;

title2 'GRADBOOST on Churn Data';
proc gradboost data=work.customer_churn_ml_train_final ntrees=100 maxdepth=5 assignmissing=useinsearch;
    input &char_vars / level=nominal;
    input &num_vars / level=interval;
    target &target / level=nominal;
    savestate rstore=gbstore;  /* creates ASTORE binary for scoring  */
    *code file='gbscore.sas';  /* creates 70,000 line SAS scoring program  */
run;

title2 'ASTORE describe and scoring';
proc astore;
    describe rstore=gbstore;
    score data=work.customer_churn_ml_test_final rstore=gbstore
          out=grad_scored copyvars=(&target);
run;

title2 'Ensemble Model';
data ensemble_predictions;
    merge log_scored (rename=(P_&target=log_pred) keep = &target P_&target )
        grad_scored (rename=(P_&target.1=grad_pred)  keep = &target P_&target.1);
    /* Calculate predicted values using cutoff */
    if log_pred <.13 then I_&target._log='0';
    else I_&target._log='1';
    if grad_pred <.13 then I_&target._grad='0';
    else I_&target._grad='1';
    /* Calculate average of predictions */
    ensemble_pred = mean(log_pred, grad_pred);
    if ensemble_pred <.13 then I_&target._ensemble='0';
    else I_&target._ensemble='1';
run;


ods graphics on;
proc logistic data=ensemble_predictions plots=roc;
   model &target(event='1') = log_pred grad_pred ensemble_pred / nofit;
   roc 'Ensemble' ensemble_pred;
   roc 'Logistic Regression' log_pred;
   roc 'Gradient Boosting' grad_pred;
run;

/* Run PROC FREQ to generate the frequency table */
proc freq data=ensemble_predictions noprint;
  tables &target*I_&target._&mtype / out=freq_out;
run;

/* Extract the counts for TP, TN, FP, FN and save to a new dataset */
data confusion_matrix;
    length TP TN FP FN 8;
    set freq_out;

    /* Initialize counts */
    retain TP TN FP FN 0;

    /* True Positive: actual=1 and predicted=1 */
    if &target = 1 and I_&target._&mtype = "1" then TP = count;

    /* True Negative: actual=0 and predicted=0 */
    if &target = 0 and I_&target._&mtype = "0" then TN = count;

    /* False Positive: actual=0 and predicted=1 */
    if &target = 0 and I_&target._&mtype = "1" then FP = count;

    /* False Negative: actual=1 and predicted=0 */
    if &target = 1 and I_&target._&mtype = "0" then FN = count;

    /* Keep only one row with the final values */
    if _N_ = 4 then output;
    keep TP TN FP FN;
run;

data metrics;
    set confusion_matrix;
    Accuracy = (TP + TN) / (TP + TN + FP + FN);
    Sensitivity = TP / (TP + FN);
    Specificity = TN / (TN + FP);
run;

Title2 "Overall Model Perfomance Statistics for &mtype";
proc print data=metrics;
run;
%mend modelstats;

%modelstats(log)
%modelstats(grad)
%modelstats(ensemble)

/* Clean up */
title;
footnote;