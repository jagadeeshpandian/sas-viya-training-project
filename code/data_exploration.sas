proc import datafile	="/export/viya/homes/psoundra@asu.edu/projects/data/output/customer_churn_abt.csv"
			out 		= customer_churn
			dbms 		= csv
			replace;
			guessingrows=max;
run;

* Remove Duplicate rows;
proc sort data=work.customer_churn noduprec;
	by _all_;
run;

* Metadata;
proc contents data=work.customer_churn varnum;
run;

* create macro variables;
proc sql noprint;
    /* Create macro variable for numeric variables */
    select name 
    into :num_vars separated by ' '
    from dictionary.columns
    where libname='WORK' /* Change to your library name */
      and memname='CUSTOMER_CHURN' /* Change to your table name */
      and type='num';

    /* Create macro variable for character variables */
    select name 
    into :char_vars separated by ' '
    from dictionary.columns
    where libname='WORK' /* library name */
      and memname='CUSTOMER_CHURN' /* table name */
      and type='char';
quit;

/* Display the macro variables */
%put &num_vars;
%put &char_vars;

/*-----------------------------------------------------
 * Use PROC MEANS to generate the statistics.
 */

PROC MEANS DATA=WORK.customer_churn FW=12 PRINTALLTYPES CHARTYPE QMETHOD=OS VARDEF=DF 	
		MEAN STD MIN MAX N NMISS Q1 MEDIAN Q3 SKEW KURT;
	VAR &num_vars;
RUN;

/*-----------------------------------------------------
 * Use PROC UNIVARIATE to generate the histograms.
 */

TITLE;
TITLE1 "Summary Statistics";
TITLE2 "Histograms";

ods output Moments=Moments MissingValues=MissingValues;
PROC UNIVARIATE DATA=customer_churn;
	VAR &num_vars;
  HISTOGRAM ;
RUN;
QUIT;
ods output close;


TITLE;
TITLE1 "Summary Statistics";
TITLE2 "Box and Whisker Plots";
/*-----------------------------------------------------
 * Use macro to loop through variables and create vertical box plots.
 */
%macro process_num_vars;
    /* Count the number of variables in &num_vars */
    %let count = %sysfunc(countw(&num_vars));

    /* Loop through each variable */
    %do i = 1 %to &count;
        %let var = %scan(&num_vars, &i);
        
        /* SGPLOT code to execute for each variable */
        PROC SGPLOT DATA=WORK.customer_churn	;
	      VBOX &var;
        RUN;QUIT;
    %end;
%mend process_num_vars;

/* Call the macro */
%process_num_vars;

TITLE; FOOTNOTE;


%macro process_char_vars;
    
    /* Set default table name in &dataset */
    %let dataset = work.customer_churn;
    
    /* Count the number of variables in &char_vars */
    %let count = %sysfunc(countw(&char_vars));

    /* Loop through each variable */
    %do i = 1 %to &count;
        %let var = %scan(&char_vars, &i);
        
        proc sql noprint;
            /* Count total observations */
            select count(&var) into :total_count
            from &dataset;

            /* Count unique values */
            select count(distinct &var) into :unique_count
            from &dataset;
        quit;

        %put Total Count: &total_count;
        %put Unique Values Count: &unique_count;

        proc freq data=&dataset order=freq;
            tables &var / out=freq_out noprint;
        run;

        /* Limit to top 5 most frequent values */
        data top_5;
            set freq_out(obs=5);
        run;

        /* Display the results */
        Title1 "For &var";
        Title2 "Total Number of Values: &total_count";
        Title3 "Unique Values Count: &unique_count";
        Footnote1 "Top 5 Values";
        proc print data=top_5;
            var &var count;
            label count = "Frequency Count"
        run;
        RUN;QUIT;
        Title;
    %end;
%mend process_char_vars;

/* Call the macro */
%process_char_vars;

TITLE; FOOTNOTE;

Title1 "Target Variable Frequency Distribution";
Title2 "And other Categorical Inputs";
proc freq data=work.customer_churn order=freq;
     tables lostcustomer customergender customersubscrstat demhomeowner/ 
     scores=table plots(only)=freq;
run;

Title1 "High Skewness or High Kurtosis";
proc print data=work.moments (rename= (label1=Skewness label2=Kurtosis));
    where (varname ne "ID" and (skewness = "Skewness")) and
    (abs(nvalue1)>3 or abs(nvalue2)>3);
    var varname skewness nvalue1 kurtosis nvalue2;
run;

Title1 "Inputs with High Skewness";
proc print data=work.moments (rename= (label1=Skewness label2=Kurtosis));
    where ((varname ne "ID" or varname ne "LostCustomer") and (skewness = "Skewness")) and
    (abs(nvalue1)>3);
    var varname skewness nvalue1;
run;

Title1 "Missing Values";
proc print data=work.missingvalues;
run;

%macro remove_strings(list, remove1, remove2, remove3);
   %local new_list item;

    %let new_list=;

   /* Loop through each item in the list */
   %do i=1 %to %sysfunc(countw(&list, %str( )));
      %let item = %scan(&list, &i, %str( ));

      /* Add item to the new list if it doesn't match the strings to be removed */
      %if &item ne &remove1 and &item ne &remove2 and &item ne &remove3 %then %do;
         %let new_list = &new_list &item;
      %end;
   %end;

   /* Trim any leading spaces */
   %let new_list = %sysfunc(compbl(&new_list));

   /* Return the new list */
   &new_list
%mend;

%let num_vars_input = %remove_strings(&num_vars, ID, LostCustomer, birthDate);
%put &num_vars_input; 



title2 'Correlation between numeric effects';
ods output PearsonCorr=corr;
proc corr data = work.customer_churn nosimple;
    var &num_vars_input;
run;

/******************************************************************************

 Sort and transpose the output from the CORR procedure for plotting a heatmap.

 ******************************************************************************/

proc sort data=Corr;
    by variable;
run;
proc transpose data=Corr out=Corr_trans(rename=(COL1=Corr)) name=Correlation;
    var &num_vars_input;
    by variable;
run;
proc sort data=Corr_trans;
    where abs(corr) > .9 and corr ne 1;
    by variable correlation;
run;

/******************************************************************************

 Use the SGPLOT procedure to produce the heatmap.

 ******************************************************************************/

title2 'Heatmap of the correlation matrix between numeric effects';
proc sgplot data=Corr_trans noautolegend;
    heatmap x=variable y=Correlation / colorresponse=Corr discretex discretey x2axis;
    text x=Variable y=Correlation text=Corr  / textattrs=(size=10pt) x2axis;
    label correlation='Pearson Correlation';
    yaxis reverse display=(nolabel);
    x2axis display=(nolabel);
    gradlegend;
run;