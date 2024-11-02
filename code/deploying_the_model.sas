/*Score a data set using the score code from the logistic regression model */

title2 'Score data with a %include statement referencing SAS Data Step code from proc logselect';
data log_scored ;
   set churn.customer_churn_ml_test_final;
   %include "&path/code/logscore.sas";
run;

/* Print a few observations with the scores*/

proc sort data=log_scored ;
    by descending P_LostCustomer ;
run ;
proc print data=log_scored (obs=10) ;
    var ID customerGender customerSubscrStat DemHomeOwner I_LostCustomer P_LostCustomer ;
run ;

/* Score a data set using the Astore file from the gradient boosting model */

title2 'ASTORE describe and scoring';
proc astore;
    score data=churn.customer_churn_ml_test_final rstore=gbstore
          out=grad_scored copyvars=(&char_vars ID );
run;

/* Print a few observations with the scores*/

proc sort data=grad_scored ;
    by descending P_LostCustomer1 ;
run ;
proc print data=grad_scored (obs=10) ;
run ;

