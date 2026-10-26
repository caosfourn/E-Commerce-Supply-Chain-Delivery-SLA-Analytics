USE olist;
GO
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
