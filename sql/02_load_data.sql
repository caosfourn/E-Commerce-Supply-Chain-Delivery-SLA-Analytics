/* =====================================================================
   02_load_data.sql  -  Nạp 9 file CSV Olist vào SQL Server
   Trước khi chạy:
     1) Giải nén dataset vào một thư mục SQL Server đọc được, ví dụ C:\olist_data\
        (BULK INSERT đọc file từ máy chạy SQL Server, bằng quyền của service account;
         tránh để trong Desktop/Downloads của user).
     2) Sửa @folder bên dưới cho đúng đường dẫn (kết thúc bằng dấu \).
   ===================================================================== */
USE olist;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_orders_customers')
    THROW 50000, N'Dữ liệu đã được nạp trước đó. Chạy lại 01_create_schema.sql để reset rồi chạy lại file này.', 1;

/* ---------- 1. CSV -> staging ---------- */
DECLARE @folder NVARCHAR(260) = N'D:\HuynhHan\E-Commerce_Supply_Chain&Delivery_SLA_Analytics\data\raw\';    

DECLARE @files TABLE (stg_table SYSNAME, file_name NVARCHAR(200), row_term NVARCHAR(10) NOT NULL);
-- row_term: '' = để chế độ CSV tự nhận (file review có xuống dòng bên trong ô comment)
INSERT @files (stg_table, file_name, row_term) VALUES
 (N'stg.customers',            N'olist_customers_dataset.csv',        N'0x0a'),
 (N'stg.geolocation',          N'olist_geolocation_dataset.csv',      N'0x0a'),
 (N'stg.order_items',          N'olist_order_items_dataset.csv',      N'0x0a'),
 (N'stg.order_payments',       N'olist_order_payments_dataset.csv',   N'0x0a'),
 (N'stg.order_reviews',        N'olist_order_reviews_dataset.csv',    N''),
 (N'stg.orders',               N'olist_orders_dataset.csv',           N'0x0a'),
 (N'stg.products',             N'olist_products_dataset.csv',         N'0x0a'),
 (N'stg.sellers',              N'olist_sellers_dataset.csv',          N'0x0a'),
 (N'stg.category_translation', N'product_category_name_translation.csv', N'0x0a');

DECLARE @t SYSNAME, @f NVARCHAR(200), @rt NVARCHAR(10), @sql NVARCHAR(MAX);
DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT stg_table, file_name, row_term FROM @files;
OPEN c;
FETCH NEXT FROM c INTO @t, @f, @rt;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'TRUNCATE TABLE ' + @t + N';
        BULK INSERT ' + @t + N' FROM ''' + @folder + @f + N'''
        WITH (FORMAT = ''CSV'', FIELDQUOTE = ''"'', FIELDTERMINATOR = '','','
        + CASE WHEN @rt = N'' THEN N'' ELSE N' ROWTERMINATOR = ''' + @rt + N''',' END
        + N' FIRSTROW = 2, CODEPAGE = ''65001'', TABLOCK);';
    BEGIN TRY
        EXEC sys.sp_executesql @sql;
        PRINT N'Đã nạp ' + @f;
    END TRY
    BEGIN CATCH
        PRINT N'LỖI khi nạp ' + @f + N': ' + ERROR_MESSAGE();
        THROW;      -- dừng toàn bộ script, không chạy tiếp các bước sau
    END CATCH
    FETCH NEXT FROM c INTO @t, @f, @rt;
END
CLOSE c; DEALLOCATE c;

/* ---------- 2. staging -> bảng chính (ép kiểu, '' -> NULL, bỏ ký tự \r cuối dòng) ---------- */
INSERT dbo.customers
SELECT customer_id, customer_unique_id,
       TRY_CONVERT(INT, NULLIF(customer_zip_code_prefix, N'')),
       customer_city,
       NULLIF(REPLACE(customer_state, CHAR(13), N''), N'')
FROM stg.customers;

INSERT dbo.sellers
SELECT seller_id,
       TRY_CONVERT(INT, NULLIF(seller_zip_code_prefix, N'')),
       seller_city,
       NULLIF(REPLACE(seller_state, CHAR(13), N''), N'')
FROM stg.sellers;

INSERT dbo.products
SELECT product_id,
       NULLIF(product_category_name, N''),
       CAST(TRY_CONVERT(DECIMAL(10,2), NULLIF(product_name_lenght, N''))        AS INT),
       CAST(TRY_CONVERT(DECIMAL(10,2), NULLIF(product_description_lenght, N'')) AS INT),
       CAST(TRY_CONVERT(DECIMAL(10,2), NULLIF(product_photos_qty, N''))        AS INT),
       TRY_CONVERT(DECIMAL(10,2), NULLIF(product_weight_g, N'')),
       TRY_CONVERT(DECIMAL(10,2), NULLIF(product_length_cm, N'')),
       TRY_CONVERT(DECIMAL(10,2), NULLIF(product_height_cm, N'')),
       TRY_CONVERT(DECIMAL(10,2), NULLIF(REPLACE(product_width_cm, CHAR(13), N''), N''))
FROM stg.products;

INSERT dbo.category_translation
SELECT product_category_name,
       NULLIF(REPLACE(product_category_name_english, CHAR(13), N''), N'')
FROM stg.category_translation;

INSERT dbo.geolocation
SELECT TRY_CONVERT(INT,   NULLIF(geolocation_zip_code_prefix, N'')),
       TRY_CONVERT(FLOAT, NULLIF(geolocation_lat, N'')),
       TRY_CONVERT(FLOAT, NULLIF(geolocation_lng, N'')),
       geolocation_city,
       NULLIF(REPLACE(geolocation_state, CHAR(13), N''), N'')
FROM stg.geolocation;

INSERT dbo.orders
SELECT order_id, customer_id, order_status,
       TRY_CONVERT(DATETIME2(0), NULLIF(order_purchase_timestamp, N'')),
       TRY_CONVERT(DATETIME2(0), NULLIF(order_approved_at, N'')),
       TRY_CONVERT(DATETIME2(0), NULLIF(order_delivered_carrier_date, N'')),
       TRY_CONVERT(DATETIME2(0), NULLIF(order_delivered_customer_date, N'')),
       TRY_CONVERT(DATETIME2(0), NULLIF(REPLACE(order_estimated_delivery_date, CHAR(13), N''), N''))
FROM stg.orders;

INSERT dbo.order_items
SELECT order_id, TRY_CONVERT(INT, order_item_id), product_id, seller_id,
       TRY_CONVERT(DATETIME2(0), NULLIF(shipping_limit_date, N'')),
       TRY_CONVERT(DECIMAL(10,2), NULLIF(price, N'')),
       TRY_CONVERT(DECIMAL(10,2), NULLIF(REPLACE(freight_value, CHAR(13), N''), N''))
FROM stg.order_items;

INSERT dbo.order_payments
SELECT order_id, TRY_CONVERT(INT, payment_sequential), payment_type,
       TRY_CONVERT(INT, NULLIF(payment_installments, N'')),
       TRY_CONVERT(DECIMAL(10,2), NULLIF(REPLACE(payment_value, CHAR(13), N''), N''))
FROM stg.order_payments;

INSERT dbo.order_reviews
       (review_id, order_id, review_score, review_comment_title, review_comment_message,
        review_creation_date, review_answer_timestamp)
SELECT review_id, order_id,
       TRY_CONVERT(TINYINT, NULLIF(review_score, N'')),
       NULLIF(review_comment_title, N''),
       NULLIF(review_comment_message, N''),
       TRY_CONVERT(DATETIME2(0), NULLIF(review_creation_date, N'')),
       TRY_CONVERT(DATETIME2(0), NULLIF(REPLACE(review_answer_timestamp, CHAR(13), N''), N''))
FROM stg.order_reviews;

/* ---------- 3. Khóa ngoại + index phục vụ phân tích ---------- */
ALTER TABLE dbo.orders         ADD CONSTRAINT FK_orders_customers FOREIGN KEY (customer_id) REFERENCES dbo.customers(customer_id);
ALTER TABLE dbo.order_items    ADD CONSTRAINT FK_items_orders     FOREIGN KEY (order_id)    REFERENCES dbo.orders(order_id);
ALTER TABLE dbo.order_items    ADD CONSTRAINT FK_items_products   FOREIGN KEY (product_id)  REFERENCES dbo.products(product_id);
ALTER TABLE dbo.order_items    ADD CONSTRAINT FK_items_sellers    FOREIGN KEY (seller_id)   REFERENCES dbo.sellers(seller_id);
ALTER TABLE dbo.order_payments ADD CONSTRAINT FK_payments_orders  FOREIGN KEY (order_id)    REFERENCES dbo.orders(order_id);
ALTER TABLE dbo.order_reviews  ADD CONSTRAINT FK_reviews_orders   FOREIGN KEY (order_id)    REFERENCES dbo.orders(order_id);

CREATE INDEX IX_customers_unique_id  ON dbo.customers (customer_unique_id);
CREATE INDEX IX_orders_customer      ON dbo.orders (customer_id);
CREATE INDEX IX_orders_purchase_ts   ON dbo.orders (order_purchase_timestamp);
CREATE INDEX IX_items_product        ON dbo.order_items (product_id);
CREATE INDEX IX_items_seller         ON dbo.order_items (seller_id);
CREATE INDEX IX_reviews_order        ON dbo.order_reviews (order_id);
CREATE INDEX IX_geo_zip              ON dbo.geolocation (geolocation_zip_code_prefix);

/* ---------- 4. Kiểm tra: số dòng thực tế so với số dòng kỳ vọng ---------- */
SELECT t.tbl AS [table], t.actual_rows, t.expected_rows,
       CASE WHEN t.actual_rows = t.expected_rows THEN N'OK' ELSE N'KIỂM TRA LẠI' END AS status
FROM (VALUES
    (N'customers',            (SELECT COUNT(*) FROM dbo.customers),            99441),
    (N'sellers',              (SELECT COUNT(*) FROM dbo.sellers),               3095),
    (N'products',             (SELECT COUNT(*) FROM dbo.products),             32951),
    (N'category_translation', (SELECT COUNT(*) FROM dbo.category_translation),    71),
    (N'geolocation',          (SELECT COUNT(*) FROM dbo.geolocation),         1000163),
    (N'orders',               (SELECT COUNT(*) FROM dbo.orders),               99441),
    (N'order_items',          (SELECT COUNT(*) FROM dbo.order_items),         112650),
    (N'order_payments',       (SELECT COUNT(*) FROM dbo.order_payments),      103886),
    (N'order_reviews',        (SELECT COUNT(*) FROM dbo.order_reviews),        99224)
) AS t(tbl, actual_rows, expected_rows);