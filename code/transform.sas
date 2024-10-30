proc format;
	value $ demhomeowner "U"="UnKnown"
						 "H"="HomeOwner"
						 ;
run;

data churn2(rename=(DemHomeOwnerCode=DemHomeOwner));
	set churn1;
	/* add customer age*/
	customerAge = intck('ÝEAR',birthdate,today(),'Ç');
    /* add additional measure */
	AvgPurchasePerAd12 = AvgPurchaseAmount12/intAdExposureCount12;
	/* format demhomeowner */
	format demHomeOwnerCode $demhomeowner.;
run;

* Same with SQL;
proc sql;
	create table churn2(drop=DemHomeOwnerCode) as
	select *
			, intck('YEAR',birthdate,today(),'C') as customerAge
			, DemHomeOwnerCode as DemHomeOwner format = $demHomeOwner.
			, AvgPurchaseAmount12/intAdExposureCount12 as AvgPurchasePerAd12
	from churn1
	;
quit;