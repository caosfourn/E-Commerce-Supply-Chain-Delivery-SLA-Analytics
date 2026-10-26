USE olist;
GO
-- Raw profiling before conversion: no mutation; conversion failures stop step 04.
SELECT order_status,
	   COUNT_BIG(*) orders, 
	   SUM(CASE WHEN NULLIF(order_delivered_customer_date,'') IS NULL THEN 1 ELSE 0 END) missing_delivery
FROM stg.orders 
GROUP BY order_status;

SELECT LEFT(order_purchase_timestamp,7) purchase_month,COUNT_BIG(*) orders 
FROM stg.orders 
GROUP BY LEFT(order_purchase_timestamp,7);

SELECT order_id,COUNT(*) reviews 
FROM stg.order_reviews 
GROUP BY order_id HAVING COUNT(*)>1;

SELECT COUNT(*) bad_timestamps 
FROM stg.orders 
WHERE NULLIF(order_purchase_timestamp,'') IS NOT NULL
AND TRY_CONVERT(datetime2,order_purchase_timestamp) IS NULL;
