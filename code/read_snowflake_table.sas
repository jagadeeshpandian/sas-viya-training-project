*Read a snowflake dataset;
libname cust "/export/viya/homes/psoundra@asu.edu/projects/data/input/snowflake";

*List tables from snowflake;
proc datasets lib=cust nodetails;
run;

*list column details of a Snowflake table;
proc contents data=cust.customers varnum;
run;

*Print a few rows from a Snowflake table;
proc sql;
	select * from cust.customers(obs=10);
quit;

*Get few metrics from a Snowflake table;
proc means data = cust.customers;
	var EstimatedIncome;
	class demhomeOwnerCode;
run;

*Get a frequency report from a snowflake table;
proc freq data=cust.customers;
	tables customerSubscrCode;
run;