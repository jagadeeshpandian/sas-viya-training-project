*Read a parquet data set from Google Cloud Storage;
libname gcs parquet "/export/viya/homes/psoundra@asu.edu/projects/data/input/gcs";

proc datasets lib=gcs;
quit;

proc contents data=gcs.customer_churn_data varnum;
run;

proc print data=gcs.customer_churn_data (obs=10);
run;

proc means data=gcs.customer_churn_data;
run;

proc freq data=gcs.customer_churn_data nlevels;
	tables _all_ / noprint;
run;