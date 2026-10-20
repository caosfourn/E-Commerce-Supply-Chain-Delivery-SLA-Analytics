USE master;
GO
IF DB_ID(N'olist') IS NULL CREATE DATABASE olist;
GO
USE olist;
GO
IF SCHEMA_ID(N'stg') IS NULL EXEC(N'CREATE SCHEMA stg');
GO

/* ---------- 1. Bảng staging: mọi cột là NVARCHAR, nạp CSV nguyên trạng ---------- */
DROP TABLE IF EXISTS stg.customers, stg.geolocation, stg.order_items, stg.order_payments,
                     stg.order_reviews, stg.orders, stg.products, stg.sellers, stg.category_translation;

CREATE TABLE stg.customers (
    customer_id NVARCHAR(100), customer_unique_id NVARCHAR(100),
    customer_zip_code_prefix NVARCHAR(100), customer_city NVARCHAR(200), customer_state NVARCHAR(100));

CREATE TABLE stg.geolocation (
    geolocation_zip_code_prefix NVARCHAR(100), geolocation_lat NVARCHAR(100),
    geolocation_lng NVARCHAR(100), geolocation_city NVARCHAR(200), geolocation_state NVARCHAR(100));

CREATE TABLE stg.order_items (
    order_id NVARCHAR(100), order_item_id NVARCHAR(100), product_id NVARCHAR(100),
    seller_id NVARCHAR(100), shipping_limit_date NVARCHAR(100),
    price NVARCHAR(100), freight_value NVARCHAR(100));

CREATE TABLE stg.order_payments (
    order_id NVARCHAR(100), payment_sequential NVARCHAR(100), payment_type NVARCHAR(100),
    payment_installments NVARCHAR(100), payment_value NVARCHAR(100));

CREATE TABLE stg.order_reviews (
    review_id NVARCHAR(100), order_id NVARCHAR(100), review_score NVARCHAR(100),
    review_comment_title NVARCHAR(4000), review_comment_message NVARCHAR(4000),
    review_creation_date NVARCHAR(100), review_answer_timestamp NVARCHAR(100));

CREATE TABLE stg.orders (
    order_id NVARCHAR(100), customer_id NVARCHAR(100), order_status NVARCHAR(100),
    order_purchase_timestamp NVARCHAR(100), order_approved_at NVARCHAR(100),
    order_delivered_carrier_date NVARCHAR(100), order_delivered_customer_date NVARCHAR(100),
    order_estimated_delivery_date NVARCHAR(100));

CREATE TABLE stg.products (
    product_id NVARCHAR(100), product_category_name NVARCHAR(200),
    product_name_lenght NVARCHAR(100), product_description_lenght NVARCHAR(100),
    product_photos_qty NVARCHAR(100), product_weight_g NVARCHAR(100),
    product_length_cm NVARCHAR(100), product_height_cm NVARCHAR(100), product_width_cm NVARCHAR(100));

CREATE TABLE stg.sellers (
    seller_id NVARCHAR(100), seller_zip_code_prefix NVARCHAR(100),
    seller_city NVARCHAR(200), seller_state NVARCHAR(100));

CREATE TABLE stg.category_translation (
    product_category_name NVARCHAR(200), product_category_name_english NVARCHAR(200));
GO

/* ---------- 2. Bảng chính (kiểu dữ liệu đúng, khóa chính) ---------- */
DROP TABLE IF EXISTS dbo.order_payments, dbo.order_items, dbo.order_reviews, dbo.orders,
                     dbo.customers, dbo.sellers, dbo.products, dbo.category_translation, dbo.geolocation;

CREATE TABLE dbo.customers (
    customer_id              CHAR(32)      NOT NULL CONSTRAINT PK_customers PRIMARY KEY,
    customer_unique_id       CHAR(32)      NOT NULL,   -- khách hàng thực (dùng cho RFM, retention)
    customer_zip_code_prefix INT           NULL,
    customer_city            NVARCHAR(100) NULL,
    customer_state           CHAR(2)       NULL);

CREATE TABLE dbo.sellers (
    seller_id              CHAR(32)      NOT NULL CONSTRAINT PK_sellers PRIMARY KEY,
    seller_zip_code_prefix INT           NULL,
    seller_city            NVARCHAR(100) NULL,
    seller_state           CHAR(2)       NULL);

CREATE TABLE dbo.products (
    product_id                 CHAR(32)      NOT NULL CONSTRAINT PK_products PRIMARY KEY,
    product_category_name      NVARCHAR(100) NULL,
    product_name_length        INT           NULL,   -- đã sửa lỗi chính tả "lenght" của dataset gốc
    product_description_length INT           NULL,
    product_photos_qty         INT           NULL,
    product_weight_g           DECIMAL(10,2) NULL,
    product_length_cm          DECIMAL(10,2) NULL,
    product_height_cm          DECIMAL(10,2) NULL,
    product_width_cm           DECIMAL(10,2) NULL);

CREATE TABLE dbo.category_translation (
    product_category_name         NVARCHAR(100) NOT NULL CONSTRAINT PK_category_translation PRIMARY KEY,
    product_category_name_english NVARCHAR(100) NULL);

CREATE TABLE dbo.geolocation (        -- không có khóa chính: dữ liệu gốc có rất nhiều dòng trùng zip
    geolocation_zip_code_prefix INT           NULL,
    geolocation_lat             FLOAT         NULL,
    geolocation_lng             FLOAT         NULL,
    geolocation_city            NVARCHAR(100) NULL,
    geolocation_state           CHAR(2)       NULL);

CREATE TABLE dbo.orders (
    order_id                      CHAR(32)    NOT NULL CONSTRAINT PK_orders PRIMARY KEY,
    customer_id                   CHAR(32)    NOT NULL,
    order_status                  VARCHAR(20) NULL,
    order_purchase_timestamp      DATETIME2(0) NULL,
    order_approved_at             DATETIME2(0) NULL,
    order_delivered_carrier_date  DATETIME2(0) NULL,
    order_delivered_customer_date DATETIME2(0) NULL,
    order_estimated_delivery_date DATETIME2(0) NULL);

CREATE TABLE dbo.order_items (
    order_id            CHAR(32)      NOT NULL,
    order_item_id       INT           NOT NULL,
    product_id          CHAR(32)      NOT NULL,
    seller_id           CHAR(32)      NOT NULL,
    shipping_limit_date DATETIME2(0)  NULL,
    price               DECIMAL(10,2) NULL,
    freight_value       DECIMAL(10,2) NULL,
    CONSTRAINT PK_order_items PRIMARY KEY (order_id, order_item_id));

CREATE TABLE dbo.order_payments (
    order_id             CHAR(32)      NOT NULL,
    payment_sequential   INT           NOT NULL,
    payment_type         VARCHAR(20)   NULL,
    payment_installments INT           NULL,
    payment_value        DECIMAL(10,2) NULL,
    CONSTRAINT PK_order_payments PRIMARY KEY (order_id, payment_sequential));

CREATE TABLE dbo.order_reviews (       -- review_id không duy nhất trong dữ liệu gốc -> dùng khóa thay thế
    review_pk               INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_order_reviews PRIMARY KEY,
    review_id               CHAR(32)       NOT NULL,
    order_id                CHAR(32)       NOT NULL,
    review_score            TINYINT        NULL,
    review_comment_title    NVARCHAR(200)  NULL,
    review_comment_message  NVARCHAR(2000) NULL,
    review_creation_date    DATETIME2(0)   NULL,
    review_answer_timestamp DATETIME2(0)   NULL);
GO

