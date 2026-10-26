USE olist;
GO
-- Purchase cohort [2017-01-01, 2018-09-01); rates are fractions.
SELECT order_month,order_status,COUNT(*) orders,
	 SUM(CASE WHEN order_status='delivered' THEN merchandise_value END) merchandise_value,
	 SUM(CASE WHEN order_status='delivered' THEN freight_value END) freight_value,
	 SUM(total_payment) total_payment,
	 AVG(CASE WHEN order_status='delivered' THEN merchandise_value END) merchandise_aov,
	 LAG(COUNT(*)) OVER(PARTITION BY order_status ORDER BY order_month) prior_month_orders
FROM mart.vw_sales 
WHERE order_purchase_timestamp>='20170101' AND order_purchase_timestamp<'20180901' 
GROUP BY order_month,order_status
ORDER BY order_month,order_status