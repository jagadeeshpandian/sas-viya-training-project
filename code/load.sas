libname churn "/export/viya/homes/psoundra@asu.edu/projects/data/output";

data churn.customer_churn_abt;
	set churn2;
run;

/* SQL Example*/
proc sql;
	create table churn.customer_churn_abt as
	select *
	from churn2
	;
quit;

proc export data=churn2 outfile="/export/viya/homes/psoundra@asu.edu/projects/data/output/customer_churn_abt.csv"
	dbms=csv 
	replace
	;
run;