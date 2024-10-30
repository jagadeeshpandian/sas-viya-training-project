*Read data files in SAS;
*set project path;
%let path=/export/viya/homes/psoundra@asu.edu/projects;

*Read the CSV file;
proc import file="'&path/data/input/subscriptions.csv" out=subscriptions dbms=csv replace;
run;

*Describe the new dataset;
proc contents data=subscriptions varnum;
run;

*Print some observations;
proc print data=subscriptions;
run;

*Reading a JSON file;
libname rev json "&path/data/input/reviews.json";

proc datasets lib=rev;
quit;

proc contents data=rev.reviews varnum;
run;

proc print data=rev.reviews(obs=10);
run;

*Read the SAS dataset;
libname tcs "&path/data/input";

proc datasets lib=tcs;
run;

proc contents data=tcs.TECHSUPPORTEVALS varnum;
run;

proc print data=tcs.TECHSUPPORTEVALS(obs=10);
run;

proc means data=tcs.techsupportevals;
run;

proc freq data=tcs.techsupportevals;
	tables techsupporteval / plots=freqplot;
run;

