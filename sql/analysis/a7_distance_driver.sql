USE olist;
GO
-- Purchase cohort [2017-01-01, 2018-09-01); rates are fractions.
-- One row per order/seller; centroid distance is a proxy, not travelled distance.
SELECT seller_state,customer_state,
	CASE WHEN distance_km IS NULL THEN 'missing' WHEN distance_km<500 THEN '<500' WHEN distance_km<1500 THEN '500-1499' ELSE '1500+' END distance_band,
	COUNT(*) order_seller_pairs,COUNT(distance_km) geocoded_pairs,COUNT(transit_days) transit_sample,
	AVG(transit_days) mean_transit_days,AVG(1.0*is_late) late_rate
FROM mart.vw_seller WHERE order_purchase_timestamp>='20170101' AND order_purchase_timestamp<'20180901' AND is_eligible=1
GROUP BY seller_state,customer_state,
	CASE WHEN distance_km IS NULL THEN 'missing' WHEN distance_km<500 THEN '<500' WHEN distance_km<1500 THEN '500-1499' ELSE '1500+' END;
