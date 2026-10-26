USE olist;
GO
-- Builds all dimensions from scratch after sql/99_reset_dwh_mart_for_rebuild.sql.
 
SELECT IDENTITY(int,1,1) customer_key,c.*,g.lat,g.lng INTO dwh.dim_customer
FROM clean.customers c LEFT JOIN clean.zip_centroids g ON c.customer_zip_code_prefix=g.zip_prefix;

ALTER TABLE dwh.dim_customer ADD PRIMARY KEY(customer_key);
CREATE UNIQUE INDEX UX_customer_id ON dwh.dim_customer(customer_id);
CREATE INDEX IX_customer_person ON dwh.dim_customer(customer_unique_id);
CREATE INDEX IX_customer_state ON dwh.dim_customer(customer_state);

SELECT IDENTITY(int,1,1) seller_key,s.*,g.lat,g.lng INTO dwh.dim_seller
FROM clean.sellers s LEFT JOIN clean.zip_centroids g ON s.seller_zip_code_prefix=g.zip_prefix;

ALTER TABLE dwh.dim_seller ADD PRIMARY KEY(seller_key);
CREATE UNIQUE INDEX UX_seller_id ON dwh.dim_seller(seller_id);

SELECT IDENTITY(int,1,1) product_key,p.*,
 COALESCE(t.product_category_name_english,p.product_category_name,N'unknown') category_en
INTO dwh.dim_product FROM clean.products p LEFT JOIN clean.category_translation t
ON p.product_category_name=t.product_category_name;

ALTER TABLE dwh.dim_product ADD PRIMARY KEY(product_key);
CREATE UNIQUE INDEX UX_product_id ON dwh.dim_product(product_id);
CREATE INDEX IX_category ON dwh.dim_product(category_en);
DECLARE @min_order_date date = (SELECT CAST(MIN(order_purchase_timestamp) AS date) FROM clean.orders);
DECLARE @max_order_date date = (SELECT CAST(MAX(order_purchase_timestamp) AS date) FROM clean.orders);
IF @min_order_date IS NULL OR @max_order_date IS NULL
    THROW 50200, 'clean.orders has no purchase dates; cannot build dim_date.', 1;
CREATE TABLE dwh.dim_date (date_key int NOT NULL,[date] date NOT NULL,[year] int NOT NULL,
 [quarter] int NOT NULL,[month] int NOT NULL,[week] int NOT NULL,day_of_week int NOT NULL,is_weekend bit NOT NULL);
;WITH dates AS (
 SELECT @min_order_date d
 UNION ALL SELECT DATEADD(day,1,d) FROM dates
 WHERE d<@max_order_date
)
INSERT dwh.dim_date(date_key,[date],[year],[quarter],[month],[week],day_of_week,is_weekend)
SELECT YEAR(d)*10000+MONTH(d)*100+DAY(d),d,YEAR(d),DATEPART(quarter,d),MONTH(d),DATEPART(iso_week,d),
 (DATEDIFF(day,'19000101',d)%7)+1,
 CASE WHEN DATEDIFF(day,'19000101',d)%7 IN(5,6) THEN 1 ELSE 0 END
FROM dates OPTION(MAXRECURSION 0);

ALTER TABLE dwh.dim_date ADD PRIMARY KEY(date_key);
