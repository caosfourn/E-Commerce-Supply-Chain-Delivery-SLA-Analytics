USE olist;
GO

-- PHẦN A - KIỂM TRA CHẤT LƯỢNG DỮ LIỆU 

-- A1. Phân bố trạng thái đơn -> quyết định đơn nào được tính vào doanh thu
SELECT order_status, COUNT(*) AS n_orders,
       CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS pct
FROM dbo.orders GROUP BY order_status ORDER BY n_orders DESC;

-- A2. Số đơn theo tháng -> chọn khoảng thời gian phân tích (2016 thưa, cuối 2018 bị cắt)
SELECT DATEFROMPARTS(YEAR(order_purchase_timestamp), MONTH(order_purchase_timestamp), 1) AS order_month,
       COUNT(*) AS n_orders
FROM dbo.orders GROUP BY DATEFROMPARTS(YEAR(order_purchase_timestamp), MONTH(order_purchase_timestamp), 1)
ORDER BY order_month;

-- A3. Timestamp bị NULL theo trạng thái (đơn chưa giao thì NULL là bình thường)
SELECT order_status, COUNT(*) AS n_orders,
       SUM(CASE WHEN order_approved_at              IS NULL THEN 1 ELSE 0 END) AS null_approved,
       SUM(CASE WHEN order_delivered_carrier_date   IS NULL THEN 1 ELSE 0 END) AS null_carrier,
       SUM(CASE WHEN order_delivered_customer_date  IS NULL THEN 1 ELSE 0 END) AS null_delivered
FROM dbo.orders GROUP BY order_status ORDER BY n_orders DESC;

-- A4. Bất thường về thời gian trong đơn đã giao
SELECT
  SUM(CASE WHEN order_delivered_customer_date < order_purchase_timestamp     THEN 1 ELSE 0 END) AS delivered_before_purchase,
  SUM(CASE WHEN order_delivered_customer_date < order_delivered_carrier_date THEN 1 ELSE 0 END) AS delivered_before_carrier,
  SUM(CASE WHEN order_approved_at < order_purchase_timestamp                 THEN 1 ELSE 0 END) AS approved_before_purchase,
  SUM(CASE WHEN order_status = 'delivered' AND order_delivered_customer_date IS NULL THEN 1 ELSE 0 END) AS delivered_but_no_date
FROM dbo.orders;

-- A5. Khách hàng: customer_id (theo đơn) vs customer_unique_id (khách thực) và tỷ lệ mua lặp lại
SELECT COUNT(*)                                AS n_customer_id,
       COUNT(DISTINCT customer_unique_id)      AS n_unique_customers,
       (SELECT COUNT(*) FROM (SELECT customer_unique_id FROM dbo.customers
                              GROUP BY customer_unique_id HAVING COUNT(*) > 1) x) AS n_repeat_customers
FROM dbo.customers;

-- A6. Đơn không có item, đơn không có thanh toán, đơn không có review, đơn có nhiều review
SELECT
  (SELECT COUNT(*) FROM dbo.orders o WHERE NOT EXISTS (SELECT 1 FROM dbo.order_items i    WHERE i.order_id = o.order_id)) AS orders_no_items,
  (SELECT COUNT(*) FROM dbo.orders o WHERE NOT EXISTS (SELECT 1 FROM dbo.order_payments p WHERE p.order_id = o.order_id)) AS orders_no_payment,
  (SELECT COUNT(*) FROM dbo.orders o WHERE NOT EXISTS (SELECT 1 FROM dbo.order_reviews r  WHERE r.order_id = o.order_id)) AS orders_no_review,
  (SELECT COUNT(*) FROM (SELECT order_id FROM dbo.order_reviews GROUP BY order_id HAVING COUNT(*) > 1) x)               AS orders_multi_review;

-- A7. Sản phẩm: thiếu ngành hàng, ngành hàng không có bản dịch
SELECT
  (SELECT COUNT(*) FROM dbo.products WHERE product_category_name IS NULL) AS products_no_category,
  (SELECT COUNT(DISTINCT p.product_category_name) FROM dbo.products p
     WHERE p.product_category_name IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM dbo.category_translation t WHERE t.product_category_name = p.product_category_name)) AS categories_no_translation;

-- A8. Tổng thanh toán có khớp price + freight? (lệch do voucher, làm tròn...)
WITH i AS (SELECT order_id, SUM(price + freight_value) AS items_total FROM dbo.order_items GROUP BY order_id),
     p AS (SELECT order_id, SUM(payment_value) AS paid_total FROM dbo.order_payments GROUP BY order_id)
SELECT COUNT(*) AS n_orders_compared,
       SUM(CASE WHEN ABS(i.items_total - p.paid_total) > 1 THEN 1 ELSE 0 END) AS n_mismatch_over_1
FROM i JOIN p ON p.order_id = i.order_id;

-- A9. Giá trị cực đoan (outlier)
SELECT MIN(price) AS min_price, MAX(price) AS max_price, AVG(price) AS avg_price,
       MIN(freight_value) AS min_freight, MAX(freight_value) AS max_freight,
       SUM(CASE WHEN freight_value = 0 THEN 1 ELSE 0 END) AS n_free_freight,
       SUM(CASE WHEN price <= 0 THEN 1 ELSE 0 END)        AS n_nonpositive_price
FROM dbo.order_items;

-- A10. Thời gian giao thực tế (ngày) của đơn đã giao: kiểm tra outlier
SELECT MIN(DATEDIFF(DAY, order_purchase_timestamp, order_delivered_customer_date)) AS min_days,
       MAX(DATEDIFF(DAY, order_purchase_timestamp, order_delivered_customer_date)) AS max_days,
       AVG(DATEDIFF(DAY, order_purchase_timestamp, order_delivered_customer_date) * 1.0) AS avg_days
FROM dbo.orders WHERE order_delivered_customer_date IS NOT NULL;
GO

/* =====================================================================
   PHẦN B - STAR SCHEMA (schema dw)
   Quyết định mô hình hóa (sửa tại đây nếu bạn chọn khác):
     * is_revenue_order = 1 nếu trạng thái KHÁC 'canceled' và 'unavailable'
     * in_analysis_window = 1 nếu mua từ 2017-01-01 đến 2018-08-31 (xác nhận bằng A2)
     * review_score của đơn = review MỚI NHẤT của đơn đó (một số đơn có nhiều review)
     * is_late = ngày giao thực tế > ngày dự kiến (so sánh theo NGÀY, không theo giờ)
     * Mọi bảng con (items, payments, reviews) được gộp về 1 dòng/đơn TRƯỚC khi join,
       để tránh nhân đôi doanh thu.
   ===================================================================== */

IF SCHEMA_ID(N'dw') IS NULL EXEC(N'CREATE SCHEMA dw');
GO

DROP TABLE IF EXISTS dw.fact_order_items, dw.fact_orders, dw.dim_customer, dw.dim_product, dw.dim_seller, dw.dim_date;
GO

-- dim_date
WITH d AS (
    SELECT CAST('2016-01-01' AS DATE) AS dt
    UNION ALL
    SELECT DATEADD(DAY, 1, dt) FROM d WHERE dt < '2018-12-31')
SELECT CONVERT(INT, CONVERT(CHAR(8), dt, 112))         AS date_key,
       dt                                              AS full_date,
       YEAR(dt)                                        AS [year],
       DATEPART(QUARTER, dt)                           AS [quarter],
       MONTH(dt)                                       AS [month],
       DATENAME(MONTH, dt)                             AS month_name,
       DATEFROMPARTS(YEAR(dt), MONTH(dt), 1)           AS year_month,
       DAY(dt)                                         AS [day],
       (DATEDIFF(DAY, '19000101', dt) % 7) + 1         AS day_of_week,   -- 1 = Thứ hai ... 7 = Chủ nhật
       DATENAME(WEEKDAY, dt)                           AS day_name,
       CASE WHEN (DATEDIFF(DAY, '19000101', dt) % 7) + 1 >= 6 THEN 1 ELSE 0 END AS is_weekend
INTO dw.dim_date
FROM d
OPTION (MAXRECURSION 0);
ALTER TABLE dw.dim_date ALTER COLUMN date_key INT NOT NULL;
ALTER TABLE dw.dim_date ADD CONSTRAINT PK_dim_date PRIMARY KEY (date_key);
GO

-- dim_product
SELECT p.product_id,
       p.product_category_name,
       COALESCE(t.product_category_name_english, p.product_category_name, N'unknown') AS category_en,
       p.product_name_length, p.product_description_length, p.product_photos_qty,
       p.product_weight_g, p.product_length_cm, p.product_height_cm, p.product_width_cm,
       p.product_length_cm * p.product_height_cm * p.product_width_cm AS product_volume_cm3
INTO dw.dim_product
FROM dbo.products p
LEFT JOIN dbo.category_translation t ON t.product_category_name = p.product_category_name;
ALTER TABLE dw.dim_product ALTER COLUMN product_id CHAR(32) NOT NULL;
ALTER TABLE dw.dim_product ADD CONSTRAINT PK_dim_product PRIMARY KEY (product_id);
GO

-- dim_seller
SELECT seller_id, seller_zip_code_prefix, seller_city, seller_state
INTO dw.dim_seller
FROM dbo.sellers;
ALTER TABLE dw.dim_seller ALTER COLUMN seller_id CHAR(32) NOT NULL;
ALTER TABLE dw.dim_seller ADD CONSTRAINT PK_dim_seller PRIMARY KEY (seller_id);
GO

-- dim_customer: 1 dòng / khách hàng thực (customer_unique_id); city/state lấy theo đơn gần nhất
WITH c AS (
    SELECT cu.customer_unique_id, cu.customer_zip_code_prefix, cu.customer_city, cu.customer_state,
           ROW_NUMBER() OVER (PARTITION BY cu.customer_unique_id
                              ORDER BY o.order_purchase_timestamp DESC, o.order_id) AS rn,
           COUNT(*) OVER (PARTITION BY cu.customer_unique_id)                       AS n_orders_all,
           MIN(o.order_purchase_timestamp) OVER (PARTITION BY cu.customer_unique_id) AS first_purchase,
           MAX(o.order_purchase_timestamp) OVER (PARTITION BY cu.customer_unique_id) AS last_purchase
    FROM dbo.customers cu
    JOIN dbo.orders o ON o.customer_id = cu.customer_id)
SELECT customer_unique_id, customer_zip_code_prefix, customer_city, customer_state,
       n_orders_all, first_purchase, last_purchase
INTO dw.dim_customer
FROM c WHERE rn = 1;
ALTER TABLE dw.dim_customer ALTER COLUMN customer_unique_id CHAR(32) NOT NULL;
ALTER TABLE dw.dim_customer ADD CONSTRAINT PK_dim_customer PRIMARY KEY (customer_unique_id);
GO

-- fact_orders: 1 dòng / đơn hàng
WITH items AS (
    SELECT order_id,
           COUNT(*)                   AS n_items,
           COUNT(DISTINCT seller_id)  AS n_sellers,
           COUNT(DISTINCT product_id) AS n_products,
           SUM(price)                 AS items_value,
           SUM(freight_value)         AS freight_value
    FROM dbo.order_items GROUP BY order_id),
pay AS (
    SELECT order_id,
           COUNT(*)                  AS n_payments,
           SUM(payment_value)        AS payment_value,
           MAX(payment_installments) AS max_installments
    FROM dbo.order_payments GROUP BY order_id),
pay_main AS (   -- phương thức thanh toán chiếm giá trị lớn nhất trong đơn
    SELECT order_id, payment_type AS main_payment_type,
           ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY payment_value DESC, payment_sequential) AS rn
    FROM dbo.order_payments),
rev AS (        -- review mới nhất của đơn
    SELECT order_id, review_score,
           CASE WHEN review_comment_message IS NOT NULL THEN 1 ELSE 0 END AS has_comment,
           ROW_NUMBER() OVER (PARTITION BY order_id
                              ORDER BY review_creation_date DESC, review_answer_timestamp DESC, review_pk DESC) AS rn
    FROM dbo.order_reviews)
SELECT o.order_id,
       cu.customer_unique_id,
       cu.customer_state,
       cu.customer_city,
       o.order_status,
       o.order_purchase_timestamp,
       CAST(o.order_purchase_timestamp AS DATE) AS purchase_date,
       DATEFROMPARTS(YEAR(o.order_purchase_timestamp), MONTH(o.order_purchase_timestamp), 1) AS order_month,
       o.order_approved_at,
       o.order_delivered_carrier_date,
       o.order_delivered_customer_date,
       o.order_estimated_delivery_date,
       ISNULL(i.n_items, 0)        AS n_items,
       ISNULL(i.n_sellers, 0)      AS n_sellers,
       ISNULL(i.n_products, 0)     AS n_products,
       ISNULL(i.items_value, 0)    AS items_value,
       ISNULL(i.freight_value, 0)  AS freight_value,
       ISNULL(i.items_value, 0) + ISNULL(i.freight_value, 0) AS revenue,      -- price + freight
       pay.payment_value,
       pay.max_installments,
       pay.n_payments,
       pm.main_payment_type,
       rv.review_score,
       rv.has_comment,
       CASE WHEN o.order_status NOT IN ('canceled', 'unavailable') THEN 1 ELSE 0 END AS is_revenue_order,
       CASE WHEN o.order_purchase_timestamp >= '2017-01-01'
             AND o.order_purchase_timestamp <  '2018-09-01' THEN 1 ELSE 0 END          AS in_analysis_window,
       CASE WHEN o.order_delivered_customer_date IS NOT NULL THEN 1 ELSE 0 END         AS is_delivered,
       CAST(DATEDIFF(HOUR, o.order_purchase_timestamp, o.order_delivered_customer_date) / 24.0 AS DECIMAL(6,1)) AS delivery_days,
       CAST(DATEDIFF(HOUR, o.order_purchase_timestamp, o.order_estimated_delivery_date) / 24.0 AS DECIMAL(6,1)) AS estimated_days,
       DATEDIFF(DAY, CAST(o.order_estimated_delivery_date AS DATE),
                     CAST(o.order_delivered_customer_date AS DATE))                    AS delay_days,   -- > 0 = giao trễ
       CASE WHEN o.order_delivered_customer_date IS NULL THEN NULL
            WHEN CAST(o.order_delivered_customer_date AS DATE) > CAST(o.order_estimated_delivery_date AS DATE) THEN 1
            ELSE 0 END                                                                 AS is_late
INTO dw.fact_orders
FROM dbo.orders o
JOIN dbo.customers cu ON cu.customer_id = o.customer_id
LEFT JOIN items    i  ON i.order_id  = o.order_id
LEFT JOIN pay         ON pay.order_id = o.order_id
LEFT JOIN pay_main pm ON pm.order_id = o.order_id AND pm.rn = 1
LEFT JOIN rev      rv ON rv.order_id = o.order_id AND rv.rn = 1;
ALTER TABLE dw.fact_orders ALTER COLUMN order_id CHAR(32) NOT NULL;
ALTER TABLE dw.fact_orders ADD CONSTRAINT PK_fact_orders PRIMARY KEY (order_id);
CREATE INDEX IX_fact_orders_customer ON dw.fact_orders (customer_unique_id);
CREATE INDEX IX_fact_orders_month    ON dw.fact_orders (order_month);
GO

-- fact_order_items: 1 dòng / sản phẩm trong đơn (dùng cho phân tích ngành hàng, seller)
SELECT i.order_id, i.order_item_id, i.product_id, i.seller_id,
       f.customer_unique_id, f.customer_state, f.purchase_date, f.order_month, f.order_status,
       i.price, i.freight_value, i.price + i.freight_value AS revenue,
       dp.category_en,
       f.is_revenue_order, f.in_analysis_window, f.is_delivered, f.is_late, f.delay_days, f.delivery_days, f.review_score
INTO dw.fact_order_items
FROM dbo.order_items i
JOIN dw.fact_orders  f  ON f.order_id   = i.order_id
LEFT JOIN dw.dim_product dp ON dp.product_id = i.product_id;
ALTER TABLE dw.fact_order_items ALTER COLUMN order_id CHAR(32) NOT NULL;
ALTER TABLE dw.fact_order_items ALTER COLUMN order_item_id INT NOT NULL;
ALTER TABLE dw.fact_order_items ADD CONSTRAINT PK_fact_order_items PRIMARY KEY (order_id, order_item_id);
CREATE INDEX IX_foi_seller   ON dw.fact_order_items (seller_id);
CREATE INDEX IX_foi_product  ON dw.fact_order_items (product_id);
CREATE INDEX IX_foi_category ON dw.fact_order_items (category_en);
GO

/* =====================================================================
   PHẦN C - ĐỐI CHIẾU: số liệu mô hình mới phải khớp bảng gốc
   ===================================================================== */
SELECT N'số đơn: orders vs fact_orders'        AS [check],
       (SELECT COUNT(*) FROM dbo.orders)       AS source_value,
       (SELECT COUNT(*) FROM dw.fact_orders)   AS model_value,
       CASE WHEN (SELECT COUNT(*) FROM dbo.orders) = (SELECT COUNT(*) FROM dw.fact_orders) THEN N'OK' ELSE N'LỆCH' END AS status
UNION ALL
SELECT N'số khách thực: customers vs dim_customer',
       (SELECT COUNT(DISTINCT customer_unique_id) FROM dbo.customers),
       (SELECT COUNT(*) FROM dw.dim_customer),
       CASE WHEN (SELECT COUNT(DISTINCT customer_unique_id) FROM dbo.customers) = (SELECT COUNT(*) FROM dw.dim_customer) THEN N'OK' ELSE N'LỆCH' END
UNION ALL
SELECT N'số dòng: order_items vs fact_order_items',
       (SELECT COUNT(*) FROM dbo.order_items),
       (SELECT COUNT(*) FROM dw.fact_order_items),
       CASE WHEN (SELECT COUNT(*) FROM dbo.order_items) = (SELECT COUNT(*) FROM dw.fact_order_items) THEN N'OK' ELSE N'LỆCH' END
UNION ALL
SELECT N'tổng price: order_items vs fact_orders',
       (SELECT CAST(SUM(price) AS BIGINT) FROM dbo.order_items),
       (SELECT CAST(SUM(items_value) AS BIGINT) FROM dw.fact_orders),
       CASE WHEN (SELECT SUM(price) FROM dbo.order_items) = (SELECT SUM(items_value) FROM dw.fact_orders) THEN N'OK' ELSE N'LỆCH' END
UNION ALL
SELECT N'tổng price: order_items vs fact_order_items',
       (SELECT CAST(SUM(price) AS BIGINT) FROM dbo.order_items),
       (SELECT CAST(SUM(price) AS BIGINT) FROM dw.fact_order_items),
       CASE WHEN (SELECT SUM(price) FROM dbo.order_items) = (SELECT SUM(price) FROM dw.fact_order_items) THEN N'OK' ELSE N'LỆCH' END;
GO
