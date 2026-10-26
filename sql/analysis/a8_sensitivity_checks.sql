USE olist;
GO
-- Purchase cohort [2017-01-01, 2018-09-01); rates are fractions.
SELECT v.scenario,COUNT(*) eligible_orders,AVG(1.0*is_late) late_rate,
	 SUM(CASE WHEN review_score BETWEEN 1 AND 5 AND (v.strict_review=0 OR is_review_valid=1) THEN 1 ELSE 0 END) reviews,
	 SUM(CASE WHEN review_score<=2 AND (v.strict_review=0 OR is_review_valid=1) THEN 1.0 ELSE 0 END)/
	 NULLIF(SUM(CASE WHEN review_score BETWEEN 1 AND 5 AND (v.strict_review=0 OR is_review_valid=1) THEN 1 ELSE 0 END),0) low_review_rate
FROM mart.vw_logistics CROSS JOIN(VALUES('main','20180901',1,0),('exclude_august','20180801',1,0),('all_review_timing','20180901',0,0),('exclude_duration_outliers','20180901',1,1))
 v(scenario,end_date,strict_review,drop_outliers)
WHERE order_purchase_timestamp>='20170101' AND order_purchase_timestamp<'20180901' AND is_eligible=1 AND order_purchase_timestamp<CAST(v.end_date AS date)
 AND (v.drop_outliers=0 OR is_duration_outlier=0) GROUP BY v.scenario;

SELECT category_en,customer_state,is_late,COUNT(*) eligible_orders,SUM(is_review_valid) reviews,
 SUM(CASE WHEN is_review_valid=1 AND review_score<=2 THEN 1.0 ELSE 0 END)/NULLIF(SUM(is_review_valid),0) low_review_rate
FROM mart.vw_category WHERE order_purchase_timestamp>='20170101' AND order_purchase_timestamp<'20180901' AND is_eligible=1 GROUP BY category_en,customer_state,is_late;
-- Threshold sensitivity 30/50/100 is emitted by a2 and a5.

