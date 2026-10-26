USE olist;
GO
-- Purchase cohort [2017-01-01, 2018-09-01); rates are fractions.
SELECT payment_type_main,max_installments,
	   CASE WHEN total_payment<100 THEN '<100' WHEN total_payment<500 THEN '100-499' ELSE '500+' END payment_band,
	   COUNT(*) orders,SUM(total_payment) payment_value 
FROM mart.vw_sales 
WHERE order_purchase_timestamp>='20170101' AND order_purchase_timestamp<'20180901'
GROUP BY payment_type_main,max_installments,CASE WHEN total_payment<100 THEN '<100' WHEN total_payment<500 THEN '100-499' ELSE '500+' END
ORDER BY payment_type_main,max_installments;	
-- Main type = highest aggregated value per type; ties alphabetical. Not actual mix of all payment rows.
