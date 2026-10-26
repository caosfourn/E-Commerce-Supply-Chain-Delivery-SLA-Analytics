USE olist;
GO
-- Purchase cohort [2017-01-01, 2018-09-01); rates are fractions.
;WITH scored AS (
		 SELECT *,
		 PERCENTILE_CONT(.5) WITHIN GROUP(ORDER BY delivery_days) OVER(PARTITION BY seller_id) median_days,
		 PERCENTILE_CONT(.9) WITHIN GROUP(ORDER BY delivery_days) OVER(PARTITION BY seller_id) p90_days
		 FROM mart.vw_seller WHERE order_purchase_timestamp>='20170101' AND order_purchase_timestamp<'20180901' AND is_eligible=1), 

	 grouped AS (
		 SELECT seller_id,COUNT(*) eligible_orders,SUM(is_late) late_orders,AVG(1.0*is_late) late_rate,
		 MAX(median_days) median_days,MAX(p90_days) p90_days,
		 SUM(is_review_valid) reviewed_orders,
		 SUM(CASE WHEN is_review_valid=1 AND review_score<=2 THEN 1.0 ELSE 0 END)/NULLIF(SUM(is_review_valid),0) low_review_rate
		 FROM scored GROUP BY seller_id)

 SELECT n.minimum_orders,g.*,RANK() OVER(PARTITION BY n.minimum_orders ORDER BY late_orders DESC) priority_rank
 FROM grouped g CROSS JOIN(VALUES(30),(50),(100)) n(minimum_orders)
 WHERE eligible_orders>=n.minimum_orders ORDER BY n.minimum_orders,priority_rank;

-- Deduplicate order-route: several sellers may share the same route.
;WITH scored AS (
	 SELECT *,
	 PERCENTILE_CONT(.5) WITHIN GROUP(ORDER BY delivery_days) OVER(PARTITION BY seller_state,customer_state) median_days,
	 PERCENTILE_CONT(.9) WITHIN GROUP(ORDER BY delivery_days) OVER(PARTITION BY seller_state,customer_state) p90_days
	 FROM (SELECT DISTINCT order_id,order_purchase_timestamp,seller_state,customer_state,is_eligible,is_late,delivery_days,is_review_valid,review_score FROM mart.vw_seller) routes WHERE order_purchase_timestamp>='20170101' AND order_purchase_timestamp<'20180901' AND is_eligible=1), 
 grouped AS (
	 SELECT seller_state,customer_state,COUNT(*) eligible_orders,SUM(is_late) late_orders,AVG(1.0*is_late) late_rate,
	 MAX(median_days) median_days,MAX(p90_days) p90_days,
	 SUM(is_review_valid) reviewed_orders,
	 SUM(CASE WHEN is_review_valid=1 AND review_score<=2 THEN 1.0 ELSE 0 END)/NULLIF(SUM(is_review_valid),0) low_review_rate
	 FROM scored GROUP BY seller_state,customer_state)

 SELECT n.minimum_orders,g.*,RANK() OVER(PARTITION BY n.minimum_orders ORDER BY late_orders DESC) priority_rank
 FROM grouped g CROSS JOIN(VALUES(30),(50),(100)) n(minimum_orders)
 WHERE eligible_orders>=n.minimum_orders ORDER BY n.minimum_orders,priority_rank;

