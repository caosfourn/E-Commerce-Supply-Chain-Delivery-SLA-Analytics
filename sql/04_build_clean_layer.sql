USE olist;
GO
CREATE TABLE clean.customers (
    customer_id              CHAR(32)      NOT NULL CONSTRAINT clean_PK_customers PRIMARY KEY,
    customer_unique_id       CHAR(32)      NOT NULL,   
    customer_zip_code_prefix INT           NULL,
    customer_city            NVARCHAR(100) NULL,
    customer_state           CHAR(2)       NULL);

CREATE TABLE clean.sellers (
    seller_id              CHAR(32)      NOT NULL CONSTRAINT clean_PK_sellers PRIMARY KEY,
    seller_zip_code_prefix INT           NULL,
    seller_city            NVARCHAR(100) NULL,
    seller_state           CHAR(2)       NULL);

CREATE TABLE clean.products (
    product_id                 CHAR(32)      NOT NULL CONSTRAINT clean_PK_products PRIMARY KEY,
    product_category_name      NVARCHAR(100) NULL,
    product_name_length        INT           NULL,  
    product_description_length INT           NULL,
    product_photos_qty         INT           NULL,
    product_weight_g           DECIMAL(10,2) NULL,
    product_length_cm          DECIMAL(10,2) NULL,
    product_height_cm          DECIMAL(10,2) NULL,
    product_width_cm           DECIMAL(10,2) NULL);

CREATE TABLE clean.category_translation (
    product_category_name         NVARCHAR(100) NOT NULL CONSTRAINT clean_PK_category_translation PRIMARY KEY,
    product_category_name_english NVARCHAR(100) NULL);

CREATE TABLE clean.geolocation (        -- không có khóa chính: dữ liệu gốc có rất nhiều dòng trùng zip
    geolocation_zip_code_prefix INT           NULL,
    geolocation_lat             FLOAT         NULL,
    geolocation_lng             FLOAT         NULL,
    geolocation_city            NVARCHAR(100) NULL,
    geolocation_state           CHAR(2)       NULL);

CREATE TABLE clean.orders (
    order_id                      CHAR(32)    NOT NULL CONSTRAINT clean_PK_orders PRIMARY KEY,
    customer_id                   CHAR(32)    NOT NULL,
    order_status                  VARCHAR(20) NULL,
    order_purchase_timestamp      DATETIME2(0) NULL,
    order_approved_at             DATETIME2(0) NULL,
    order_delivered_carrier_date  DATETIME2(0) NULL,
    order_delivered_customer_date DATETIME2(0) NULL,
    order_estimated_delivery_date DATETIME2(0) NULL);

CREATE TABLE clean.order_items (
    order_id            CHAR(32)      NOT NULL,
    order_item_id       INT           NOT NULL,
    product_id          CHAR(32)      NOT NULL,
    seller_id           CHAR(32)      NOT NULL,
    shipping_limit_date DATETIME2(0)  NULL,
    price               DECIMAL(10,2) NULL,
    freight_value       DECIMAL(10,2) NULL,
    CONSTRAINT clean_PK_order_items PRIMARY KEY (order_id, order_item_id));

CREATE TABLE clean.order_payments (
    order_id             CHAR(32)      NOT NULL,
    payment_sequential   INT           NOT NULL,
    payment_type         VARCHAR(20)   NULL,
    payment_installments INT           NULL,
    payment_value        DECIMAL(10,2) NULL,
    CONSTRAINT clean_PK_order_payments PRIMARY KEY (order_id, payment_sequential));

CREATE TABLE clean.order_reviews (      
    review_pk               INT IDENTITY(1,1) NOT NULL CONSTRAINT clean_PK_order_reviews PRIMARY KEY,
    review_id               CHAR(32)       NOT NULL,
    order_id                CHAR(32)       NOT NULL,
    review_score            TINYINT        NULL,
    review_comment_title    NVARCHAR(200)  NULL,
    review_comment_message  NVARCHAR(2000) NULL,
    review_creation_date    DATETIME2(0)   NULL,
    review_answer_timestamp DATETIME2(0)   NULL);
GO


SET XACT_ABORT ON;
BEGIN TRY
BEGIN TRAN;
INSERT clean.customers (customer_id, customer_unique_id, customer_zip_code_prefix, customer_city, customer_state)
SELECT DISTINCT customer_id, customer_unique_id,
       CONVERT(INT, NULLIF(customer_zip_code_prefix, N'')),
       customer_city,
       NULLIF(REPLACE(customer_state, CHAR(13), N''), N'')
FROM stg.customers;

INSERT clean.sellers (seller_id, seller_zip_code_prefix, seller_city, seller_state)
SELECT DISTINCT seller_id,
       CONVERT(INT, NULLIF(seller_zip_code_prefix, N'')),
       seller_city,
       NULLIF(REPLACE(seller_state, CHAR(13), N''), N'')
FROM stg.sellers;

INSERT clean.products (product_id, product_category_name, product_name_length, product_description_length, product_photos_qty, product_weight_g, product_length_cm, product_height_cm, product_width_cm)
SELECT DISTINCT product_id,
       NULLIF(product_category_name, N''),
       CAST(CONVERT(DECIMAL(10,2), NULLIF(product_name_lenght, N''))        AS INT),
       CAST(CONVERT(DECIMAL(10,2), NULLIF(product_description_lenght, N'')) AS INT),
       CAST(CONVERT(DECIMAL(10,2), NULLIF(product_photos_qty, N''))        AS INT),
       CONVERT(DECIMAL(10,2), NULLIF(product_weight_g, N'')),
       CONVERT(DECIMAL(10,2), NULLIF(product_length_cm, N'')),
       CONVERT(DECIMAL(10,2), NULLIF(product_height_cm, N'')),
       CONVERT(DECIMAL(10,2), NULLIF(REPLACE(product_width_cm, CHAR(13), N''), N''))
FROM stg.products;

INSERT clean.category_translation (product_category_name, product_category_name_english)
SELECT DISTINCT product_category_name,
       NULLIF(REPLACE(product_category_name_english, CHAR(13), N''), N'')
FROM stg.category_translation;

INSERT clean.geolocation (geolocation_zip_code_prefix, geolocation_lat, geolocation_lng, geolocation_city, geolocation_state)
SELECT CONVERT(INT,   NULLIF(geolocation_zip_code_prefix, N'')),
       CONVERT(FLOAT, NULLIF(geolocation_lat, N'')),
       CONVERT(FLOAT, NULLIF(geolocation_lng, N'')),
       geolocation_city,
       NULLIF(REPLACE(geolocation_state, CHAR(13), N''), N'')
FROM stg.geolocation;

INSERT clean.orders (order_id, customer_id, order_status, order_purchase_timestamp, order_approved_at, order_delivered_carrier_date, order_delivered_customer_date, order_estimated_delivery_date)
SELECT DISTINCT order_id, customer_id, order_status,
       CONVERT(DATETIME2(0), NULLIF(order_purchase_timestamp, N'')),
       CONVERT(DATETIME2(0), NULLIF(order_approved_at, N'')),
       CONVERT(DATETIME2(0), NULLIF(order_delivered_carrier_date, N'')),
       CONVERT(DATETIME2(0), NULLIF(order_delivered_customer_date, N'')),
       CONVERT(DATETIME2(0), NULLIF(REPLACE(order_estimated_delivery_date, CHAR(13), N''), N''))
FROM stg.orders;

INSERT clean.order_items (order_id, order_item_id, product_id, seller_id, shipping_limit_date, price, freight_value)
SELECT DISTINCT order_id, CONVERT(INT, order_item_id), product_id, seller_id,
       CONVERT(DATETIME2(0), NULLIF(shipping_limit_date, N'')),
       CONVERT(DECIMAL(10,2), NULLIF(price, N'')),
       CONVERT(DECIMAL(10,2), NULLIF(REPLACE(freight_value, CHAR(13), N''), N''))
FROM stg.order_items;

INSERT clean.order_payments (order_id, payment_sequential, payment_type, payment_installments, payment_value)
SELECT DISTINCT order_id, CONVERT(INT, payment_sequential), payment_type,
       CONVERT(INT, NULLIF(payment_installments, N'')),
       CONVERT(DECIMAL(10,2), NULLIF(REPLACE(payment_value, CHAR(13), N''), N''))
FROM stg.order_payments;

INSERT clean.order_reviews
       (review_id, order_id, review_score, review_comment_title, review_comment_message,
        review_creation_date, review_answer_timestamp)
SELECT DISTINCT review_id, order_id,
       CONVERT(TINYINT, NULLIF(review_score, N'')),
       NULLIF(review_comment_title, N''),
       NULLIF(review_comment_message, N''),
       CONVERT(DATETIME2(0), NULLIF(review_creation_date, N'')),
       CONVERT(DATETIME2(0), NULLIF(REPLACE(review_answer_timestamp, CHAR(13), N''), N''))
FROM stg.order_reviews;

ALTER TABLE clean.orders         ADD CONSTRAINT clean_FK_orders_customers FOREIGN KEY (customer_id) REFERENCES clean.customers(customer_id);
ALTER TABLE clean.order_items    ADD CONSTRAINT clean_FK_items_orders     FOREIGN KEY (order_id)    REFERENCES clean.orders(order_id);
ALTER TABLE clean.order_items    ADD CONSTRAINT clean_FK_items_products   FOREIGN KEY (product_id)  REFERENCES clean.products(product_id);
ALTER TABLE clean.order_items    ADD CONSTRAINT clean_FK_items_sellers    FOREIGN KEY (seller_id)   REFERENCES clean.sellers(seller_id);
ALTER TABLE clean.order_payments ADD CONSTRAINT clean_FK_payments_orders  FOREIGN KEY (order_id)    REFERENCES clean.orders(order_id);
ALTER TABLE clean.order_reviews  ADD CONSTRAINT clean_FK_reviews_orders   FOREIGN KEY (order_id)    REFERENCES clean.orders(order_id);

CREATE INDEX IX_customers_unique_id  ON clean.customers (customer_unique_id);
CREATE INDEX IX_orders_customer      ON clean.orders (customer_id);
CREATE INDEX IX_orders_purchase_ts   ON clean.orders (order_purchase_timestamp);
CREATE INDEX IX_items_product        ON clean.order_items (product_id);
CREATE INDEX IX_items_seller         ON clean.order_items (seller_id);
CREATE INDEX IX_reviews_order        ON clean.order_reviews (order_id);
CREATE INDEX IX_geo_zip              ON clean.geolocation (geolocation_zip_code_prefix);


;WITH ranked AS (
 SELECT *, ROW_NUMBER() OVER(PARTITION BY order_id ORDER BY review_creation_date DESC,
 review_answer_timestamp DESC, review_id DESC, review_score DESC,
 review_comment_title DESC, review_comment_message DESC) rn FROM clean.order_reviews
) DELETE FROM ranked WHERE rn>1;
SELECT geolocation_zip_code_prefix zip_prefix,
 AVG(CASE WHEN geolocation_lat BETWEEN -90 AND 90 AND geolocation_lng BETWEEN -180 AND 180 THEN geolocation_lat END) lat,
 AVG(CASE WHEN geolocation_lat BETWEEN -90 AND 90 AND geolocation_lng BETWEEN -180 AND 180 THEN geolocation_lng END) lng
INTO clean.zip_centroids FROM clean.geolocation GROUP BY geolocation_zip_code_prefix;
CREATE UNIQUE INDEX IX_zip ON clean.zip_centroids(zip_prefix);
COMMIT;
END TRY
BEGIN CATCH
IF XACT_STATE()<>0 ROLLBACK;
THROW;
END CATCH;
