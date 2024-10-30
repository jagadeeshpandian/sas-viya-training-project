*Join Data;
proc sql;
	create table churn1
		(drop=custId customerSubscrCode ID reviewId ordinal_root ordinal_reviews) as		
		select *
		from gcs.customer_churn_data as churn
			left join cust.customers as cust on churn.custId=cust.custId
			left join subscriptions as subs on cust.customerSubscrCode=subs.customerSubscrCode
			left join tcs.techSupportEvals as evals on churn.ID=evals.ID
			left join rev.reviews as rev on churn.reviewId=rev.reviewId
	;
quit;

*Describe the output table;
proc contents data=churn1 varnum;
run;

*get some basic statistics;
proc means data=churn1 n nmiss mean min max;
run;

*Get number of distinct values;
proc freq data=churn1 nlevels;
	tables _all_ / noprint;
run;

