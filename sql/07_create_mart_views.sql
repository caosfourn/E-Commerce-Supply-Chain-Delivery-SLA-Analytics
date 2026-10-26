USE olist;
GO

CREATE OR ALTER VIEW mart.vw_logistics AS
SELECT o.*,c.customer_unique_id,c.customer_state,
	   DATEFROMPARTS(YEAR(o.order_purchase_timestamp),MONTH(o.order_purchase_timestamp),1) order_month
FROM dwh.fact_orders o 
JOIN dwh.dim_customer c ON o.customer_key=c.customer_key;
GO

CREATE OR ALTER VIEW mart.vw_sales AS
WITH items AS (SELECT order_id,SUM(price) merchandise_value,SUM(freight_value) freight_value
FROM dwh.fact_order_items GROUP BY order_id)
SELECT o.*,i.merchandise_value,i.freight_value FROM mart.vw_logistics o 
LEFT JOIN items i ON o.order_id=i.order_id;
GO

CREATE OR ALTER VIEW mart.vw_seller AS
WITH pairs AS (SELECT DISTINCT order_id,seller_key,distance_km FROM dwh.fact_order_items)
SELECT o.*,s.seller_id,s.seller_state,i.distance_km FROM pairs i JOIN mart.vw_logistics o ON i.order_id=o.order_id
JOIN dwh.dim_seller s ON i.seller_key=s.seller_key;
GO

CREATE OR ALTER VIEW mart.vw_category AS
WITH pairs AS (SELECT DISTINCT i.order_id,p.category_en 
FROM dwh.fact_order_items i
JOIN dwh.dim_product p ON i.product_key=p.product_key)
SELECT o.*,p.category_en FROM pairs p JOIN mart.vw_logistics o ON p.order_id=o.order_id;
GO

CREATE OR ALTER VIEW mart.vw_customer AS
WITH ranked AS (SELECT *,ROW_NUMBER() OVER(PARTITION BY customer_unique_id ORDER BY order_purchase_timestamp,order_id) rn
FROM mart.vw_logistics), first_orders AS (SELECT * FROM ranked WHERE rn=1)

SELECT f.*,CASE WHEN EXISTS(SELECT 1 FROM mart.vw_logistics r WHERE r.customer_unique_id=f.customer_unique_id
	AND r.order_purchase_timestamp>f.order_purchase_timestamp AND r.order_purchase_timestamp<=DATEADD(day,90,f.order_purchase_timestamp)
	AND r.order_status NOT IN('canceled','unavailable')) THEN 1 ELSE 0 END repeat_90d,
 CASE WHEN DATEADD(day,90,f.order_purchase_timestamp)<'20180901' THEN 1 ELSE 0 END has_90d_followup
FROM first_orders f;
GO
