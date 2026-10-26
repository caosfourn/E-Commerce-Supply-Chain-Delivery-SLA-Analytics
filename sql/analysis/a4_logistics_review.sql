USE olist;
GO
-- Purchase cohort [2017-01-01, 2018-09-01); rates are fractions.
SELECT DISTINCT order_month,COUNT(*) OVER(PARTITION BY order_month) eligible_orders,
		AVG(1.0*is_late) OVER(PARTITION BY order_month) late_rate,
		PERCENTILE_CONT(.5) WITHIN GROUP(ORDER BY delivery_days) OVER(PARTITION BY order_month) median_days,
		PERCENTILE_CONT(.9) WITHIN GROUP(ORDER BY delivery_days) OVER(PARTITION BY order_month) p90_days,
		PERCENTILE_CONT(.9) WITHIN GROUP(ORDER BY delay_days) OVER(PARTITION BY order_month) p90_delay
FROM mart.vw_logistics 
WHERE order_purchase_timestamp>='20170101' AND order_purchase_timestamp<'20180901' AND is_eligible=1
ORDER BY order_month ASC;


SELECT DISTINCT s.stage,COUNT(s.days) OVER(PARTITION BY s.stage) sample_size,
		PERCENTILE_CONT(.5) WITHIN GROUP(ORDER BY s.days) OVER(PARTITION BY s.stage) median_days,
		PERCENTILE_CONT(.9) WITHIN GROUP(ORDER BY s.days) OVER(PARTITION BY s.stage) p90_days
FROM mart.vw_logistics CROSS APPLY(VALUES('approval',approval_days),('handoff',handoff_days),('transit',transit_days)) s(stage,days)
WHERE order_purchase_timestamp>='20170101' AND order_purchase_timestamp<'20180901' AND is_eligible=1;


SELECT CASE WHEN is_late=0 THEN 'on_time' WHEN delay_days<=3 THEN 'late_1_3' WHEN delay_days<=7 THEN 'late_4_7' ELSE 'late_8_plus' END delay_band,
		COUNT(*) eligible_orders,SUM(is_review_valid) reviewed_orders,AVG(1.0*is_review_valid) coverage,
		SUM(CASE WHEN is_review_valid=1 AND review_score<=2 THEN 1.0 ELSE 0 END)/NULLIF(SUM(is_review_valid),0) low_review_rate
FROM mart.vw_logistics WHERE order_purchase_timestamp>='20170101' AND order_purchase_timestamp<'20180901' AND is_eligible=1
GROUP BY CASE WHEN is_late=0 THEN 'on_time' WHEN delay_days<=3 THEN 'late_1_3' WHEN delay_days<=7 THEN 'late_4_7' ELSE 'late_8_plus' END;
