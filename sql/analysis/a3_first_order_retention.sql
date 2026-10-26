USE olist;
GO
-- Purchase cohort [2017-01-01, 2018-09-01); rates are fractions.
-- First order selected over all history BEFORE cohort filtering; fixed 90-day follow-up.
WITH g AS (
	 SELECT is_late,COUNT(*) customers,SUM(repeat_90d) repeat_customers,
	 AVG(1.0*repeat_90d) repeat_rate FROM mart.vw_customer WHERE order_purchase_timestamp>='20170101' AND order_purchase_timestamp<'20180901' AND is_eligible=1
	 AND has_90d_followup=1 GROUP BY is_late)
SELECT *, (repeat_rate+3.8416/(2*customers)-1.96*SQRT(repeat_rate*(1-repeat_rate)/customers+3.8416/(4*customers*1.0*customers)))/(1+3.8416/customers) ci_low,
	 (repeat_rate+3.8416/(2*customers)+1.96*SQRT(repeat_rate*(1-repeat_rate)/customers+3.8416/(4*customers*1.0*customers)))/(1+3.8416/customers) ci_high 
 FROM g;
