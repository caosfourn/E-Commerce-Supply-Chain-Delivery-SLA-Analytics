USE olist;
GO

;WITH payments AS (
 SELECT order_id,SUM(payment_value) total_payment,MAX(payment_installments) max_installments
 FROM clean.order_payments GROUP BY order_id
), 
types AS (
 SELECT order_id,payment_type,SUM(payment_value) amount,
 ROW_NUMBER() OVER(PARTITION BY order_id ORDER BY SUM(payment_value) DESC,payment_type) rn
 FROM clean.order_payments GROUP BY order_id,payment_type
)

SELECT o.*,c.customer_key,YEAR(o.order_purchase_timestamp)*10000+MONTH(o.order_purchase_timestamp)*100+DAY(o.order_purchase_timestamp) date_key,
	 CASE WHEN o.order_status='delivered' AND o.order_delivered_customer_date IS NOT NULL
	 AND o.order_estimated_delivery_date IS NOT NULL THEN 1 ELSE 0 END is_eligible,
	 CASE WHEN o.order_status='delivered' AND o.order_delivered_customer_date IS NOT NULL AND o.order_estimated_delivery_date IS NOT NULL
		THEN CASE WHEN CAST(o.order_delivered_customer_date AS date)>CAST(o.order_estimated_delivery_date AS date) THEN 1 ELSE 0 END END is_late,
	 CASE WHEN o.order_status='delivered' AND o.order_delivered_customer_date>=o.order_purchase_timestamp
		THEN DATEDIFF_BIG(second,o.order_purchase_timestamp,o.order_delivered_customer_date)/86400.0 END delivery_days,
	 CASE WHEN o.order_approved_at>=o.order_purchase_timestamp THEN DATEDIFF_BIG(second,o.order_purchase_timestamp,o.order_approved_at)/86400.0 END approval_days,
	 CASE WHEN o.order_delivered_carrier_date>=o.order_approved_at AND o.order_approved_at>=o.order_purchase_timestamp
		THEN DATEDIFF_BIG(second,o.order_approved_at,o.order_delivered_carrier_date)/86400.0 END handoff_days,
	 CASE WHEN o.order_status='delivered' AND o.order_delivered_customer_date>=o.order_delivered_carrier_date AND o.order_delivered_carrier_date>=o.order_purchase_timestamp
		THEN DATEDIFF_BIG(second,o.order_delivered_carrier_date,o.order_delivered_customer_date)/86400.0 END transit_days,
	 CASE WHEN o.order_status='delivered' THEN DATEDIFF(day,CAST(o.order_estimated_delivery_date AS date),CAST(o.order_delivered_customer_date AS date)) END delay_days,
	 r.review_score,r.review_creation_date,
	 CASE WHEN r.review_score BETWEEN 1 AND 5 AND CAST(r.review_creation_date AS date)>=CAST(o.order_delivered_customer_date AS date) THEN 1 ELSE 0 END is_review_valid,
	 p.total_payment,p.max_installments,t.payment_type payment_type_main,
	 CASE WHEN o.order_delivered_customer_date<o.order_purchase_timestamp OR o.order_approved_at<o.order_purchase_timestamp
		OR o.order_delivered_carrier_date<o.order_approved_at THEN 1 ELSE 0 END has_timestamp_anomaly,
	 CASE WHEN DATEDIFF(day,o.order_purchase_timestamp,o.order_delivered_customer_date)>60 THEN 1 ELSE 0 END is_duration_outlier
INTO dwh.fact_orders FROM clean.orders o
JOIN dwh.dim_customer c ON o.customer_id=c.customer_id
LEFT JOIN clean.order_reviews r ON o.order_id=r.order_id
LEFT JOIN payments p ON o.order_id=p.order_id LEFT JOIN types t ON o.order_id=t.order_id AND t.rn=1;


ALTER TABLE dwh.fact_orders ADD PRIMARY KEY(order_id),
	FOREIGN KEY(customer_key) REFERENCES dwh.dim_customer(customer_key),
	FOREIGN KEY(date_key) REFERENCES dwh.dim_date(date_key);


SELECT i.*,o.customer_key,o.date_key,p.product_key,s.seller_key,
	 i.price+i.freight_value revenue,
	 CASE WHEN i.price>1000 OR i.freight_value>200 THEN 1 ELSE 0 END is_value_outlier,
	 2*6371.0088*ASIN(SQRT(CASE WHEN h.a>1 THEN 1 WHEN h.a<0 THEN 0 ELSE h.a END)) distance_km
INTO dwh.fact_order_items FROM clean.order_items i
JOIN dwh.fact_orders o ON i.order_id=o.order_id
JOIN dwh.dim_customer c ON o.customer_key=c.customer_key
JOIN dwh.dim_product p ON i.product_id=p.product_id
JOIN dwh.dim_seller s ON i.seller_id=s.seller_id
CROSS APPLY(SELECT POWER(SIN(RADIANS(c.lat-s.lat)/2),2)+COS(RADIANS(s.lat))*COS(RADIANS(c.lat))*POWER(SIN(RADIANS(c.lng-s.lng)/2),2) a) h;


ALTER TABLE dwh.fact_order_items ADD PRIMARY KEY(order_id,order_item_id),
	 FOREIGN KEY(order_id) REFERENCES dwh.fact_orders(order_id),
	 FOREIGN KEY(product_key) REFERENCES dwh.dim_product(product_key),
	 FOREIGN KEY(seller_key) REFERENCES dwh.dim_seller(seller_key),
	 FOREIGN KEY(customer_key) REFERENCES dwh.dim_customer(customer_key),
	 FOREIGN KEY(date_key) REFERENCES dwh.dim_date(date_key);


CREATE INDEX IX_orders_date ON dwh.fact_orders(date_key);
CREATE INDEX IX_orders_customer ON dwh.fact_orders(customer_key);

CREATE INDEX IX_items_product ON dwh.fact_order_items(product_key);
CREATE INDEX IX_items_seller ON dwh.fact_order_items(seller_key);
CREATE INDEX IX_items_customer ON dwh.fact_order_items(customer_key);
CREATE INDEX IX_items_date ON dwh.fact_order_items(date_key);
