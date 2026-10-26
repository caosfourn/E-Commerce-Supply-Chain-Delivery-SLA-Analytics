-- 03: Data Quality Checks
USE olist;
GO

SET NOCOUNT ON;

DROP TABLE IF EXISTS #checks;

CREATE TABLE #checks (
    check_id     VARCHAR(100),
    severity     VARCHAR(10),
    failed_count BIGINT,
    description  NVARCHAR(1000)
);

-- Chạy các kiểm tra cơ bản (FATAL & WARN)
INSERT INTO #checks (check_id, severity, failed_count, description)

-- [FATAL] Kiểm tra tính toàn vẹn dữ liệu và miền giá trị (Bắt buộc phải hợp lệ)

-- 1. Giá hàng và phí vận chuyển phải tồn tại và không âm
SELECT 
    'item_money' AS check_id,
    'FATAL' AS severity,
    COUNT_BIG(*) AS failed_count,
    N'Item price/freight must be present and nonnegative.' AS description
FROM clean.order_items 
WHERE price IS NULL 
   OR freight_value IS NULL 
   OR price < 0 
   OR freight_value < 0

UNION ALL

-- 2. Số thứ tự sản phẩm phải là số dương
SELECT 
    'item_sequence',
    'FATAL',
    COUNT_BIG(*),
    N'Item sequence must be positive.'
FROM clean.order_items 
WHERE order_item_id <= 0

UNION ALL

-- 3. Số tiền thanh toán và số kỳ trả góp không được âm, thứ tự thanh toán phải > 0
SELECT 
    'payment_domain',
    'FATAL',
    COUNT_BIG(*),
    N'Payment amount and installments must be nonnegative; sequence positive.'
FROM clean.order_payments 
WHERE payment_value IS NULL 
   OR payment_value < 0
   OR payment_installments IS NULL 
   OR payment_installments < 0 
   OR payment_sequential <= 0

UNION ALL

-- 4. Điểm đánh giá (nếu có) phải nằm trong khoảng từ 1 đến 5
SELECT 
    'review_score',
    'FATAL',
    COUNT_BIG(*),
    N'Non-null review scores must be between 1 and 5.'
FROM clean.order_reviews 
WHERE review_score IS NOT NULL 
  AND review_score NOT BETWEEN 1 AND 5

UNION ALL

-- 5. Thời điểm đặt mua và trạng thái đơn hàng phải hợp lệ
SELECT 
    'order_required',
    'FATAL',
    COUNT_BIG(*),
    N'Purchase timestamp and known status are required.'
FROM clean.orders 
WHERE order_purchase_timestamp IS NULL 
   OR order_status IS NULL 
   OR order_status NOT IN (
       'created', 'approved', 'invoiced', 'processing',
       'shipped', 'delivered', 'canceled', 'unavailable'
   )

UNION ALL

-- [FATAL] Kiểm tra ràng buộc khóa ngoại (Orphan records)

-- 6. Mọi đơn hàng phải có khách hàng tương ứng
SELECT 
    'orphan_order_customer',
    'FATAL',
    COUNT_BIG(*),
    N'Every order must match a customer.'
FROM clean.orders o 
LEFT JOIN clean.customers c ON c.customer_id = o.customer_id 
WHERE c.customer_id IS NULL

UNION ALL

-- 7. Mọi item phải thuộc đơn hàng, sản phẩm và người bán hợp lệ
SELECT 
    'orphan_items',
    'FATAL',
    COUNT_BIG(*),
    N'Every item must match order, product and seller.'
FROM clean.order_items i
LEFT JOIN clean.orders o   ON o.order_id = i.order_id
LEFT JOIN clean.products p ON p.product_id = i.product_id
LEFT JOIN clean.sellers s  ON s.seller_id = i.seller_id
WHERE o.order_id IS NULL 
   OR p.product_id IS NULL 
   OR s.seller_id IS NULL

UNION ALL

-- 8. Mọi thanh toán phải thuộc một đơn hàng hợp lệ
SELECT 
    'orphan_payments',
    'FATAL',
    COUNT_BIG(*),
    N'Every payment must match an order.'
FROM clean.order_payments p 
LEFT JOIN clean.orders o ON o.order_id = p.order_id 
WHERE o.order_id IS NULL

UNION ALL

-- 9. Mọi đánh giá phải thuộc một đơn hàng hợp lệ
SELECT 
    'orphan_reviews',
    'FATAL',
    COUNT_BIG(*),
    N'Every review must match an order.'
FROM clean.order_reviews r 
LEFT JOIN clean.orders o ON o.order_id = r.order_id 
WHERE o.order_id IS NULL

UNION ALL

-- [WARN] Kiểm tra logic trạng thái và ngày giao hàng (SLA)

-- 10. Trạng thái 'delivered' nhưng thiếu ngày giao hàng thực tế
SELECT 
    'delivered_missing_date',
    'WARN',
    COUNT_BIG(*),
    N'Exclude from delivery/SLA metrics; preserve delivered status.'
FROM clean.orders 
WHERE order_status = 'delivered' 
  AND order_delivered_customer_date IS NULL

UNION ALL

-- 11. Đơn chưa giao nhưng lại có ngày giao hàng thực tế
SELECT 
    'non_delivered_with_date',
    'WARN',
    COUNT_BIG(*),
    N'Not eligible for delivered/SLA population.'
FROM clean.orders 
WHERE order_status <> 'delivered' 
  AND order_delivered_customer_date IS NOT NULL

UNION ALL

-- 12. Thiếu ngày dự kiến giao hàng
SELECT 
    'missing_estimated_date',
    'WARN',
    COUNT_BIG(*),
    N'Exclude from SLA; do not classify as on-time.'
FROM clean.orders 
WHERE order_estimated_delivery_date IS NULL

UNION ALL

-- [WARN] Kiểm tra bất thường về trình tự thời gian (Timeline sequence)

-- 13. Ngày giao hàng thực tế trước ngày đặt mua
SELECT 
    'actual_before_purchase',
    'WARN',
    COUNT_BIG(*),
    N'Exclude invalid end-to-end duration and SLA.'
FROM clean.orders 
WHERE order_delivered_customer_date < order_purchase_timestamp

UNION ALL

-- 14. Ngày dự kiến giao hàng trước ngày đặt mua
SELECT 
    'estimate_before_purchase_day',
    'WARN',
    COUNT_BIG(*),
    N'Exclude from SLA when estimated day is before purchase day.'
FROM clean.orders 
WHERE CAST(order_estimated_delivery_date AS DATE) < CAST(order_purchase_timestamp AS DATE)

UNION ALL

-- 15. Ngày duyệt đơn trước ngày đặt mua
SELECT 
    'approval_before_purchase',
    'WARN',
    COUNT_BIG(*),
    N'Approval duration unavailable.'
FROM clean.orders 
WHERE order_approved_at < order_purchase_timestamp

UNION ALL

-- 16. Ngày giao cho đối tác vận chuyển trước ngày duyệt đơn
SELECT 
    'carrier_before_approval',
    'WARN',
    COUNT_BIG(*),
    N'Handoff duration unavailable.'
FROM clean.orders 
WHERE order_delivered_carrier_date < order_approved_at

UNION ALL

-- 17. Ngày giao khách trước ngày giao cho đối tác vận chuyển
SELECT 
    'actual_before_carrier',
    'WARN',
    COUNT_BIG(*),
    N'Transit duration unavailable; SLA assessed independently.'
FROM clean.orders 
WHERE order_delivered_customer_date < order_delivered_carrier_date

UNION ALL

-- [WARN] Kiểm tra độ đầy đủ dữ liệu theo đơn hàng

-- 18. Đơn hàng không có sản phẩm nào
SELECT 
    'orders_without_items',
    'WARN',
    COUNT_BIG(*),
    N'Keep absent amounts NULL; exclude from merchandise AOV.'
FROM clean.orders o 
WHERE NOT EXISTS (
    SELECT 1 
    FROM clean.order_items i 
    WHERE i.order_id = o.order_id
)

UNION ALL

-- 19. Đơn hàng không có bản ghi thanh toán
SELECT 
    'orders_without_payments',
    'WARN',
    COUNT_BIG(*),
    N'Payment coverage is incomplete.'
FROM clean.orders o 
WHERE NOT EXISTS (
    SELECT 1 
    FROM clean.order_payments p 
    WHERE p.order_id = o.order_id
)

UNION ALL

-- 20. Đơn hàng không có đánh giá
SELECT 
    'orders_without_reviews',
    'WARN',
    COUNT_BIG(*),
    N'Review rate denominator must use reviewed orders.'
FROM clean.orders o 
WHERE NOT EXISTS (
    SELECT 1 
    FROM clean.order_reviews r 
    WHERE r.order_id = o.order_id
)

UNION ALL

-- [WARN] Kiểm tra dữ liệu sản phẩm và địa lý

-- 21. Sản phẩm thiếu tên danh mục
SELECT 
    'missing_category',
    'WARN',
    COUNT_BIG(*),
    N'Use unknown category label.'
FROM clean.products 
WHERE product_category_name IS NULL

UNION ALL

-- 22. Danh mục sản phẩm chưa có bản dịch tiếng Anh
SELECT 
    'missing_category_translation',
    'WARN',
    COUNT_BIG(*),
    N'Fallback to original category label.'
FROM clean.products p 
WHERE p.product_category_name IS NOT NULL 
  AND NOT EXISTS (
      SELECT 1 
      FROM clean.category_translation t 
      WHERE t.product_category_name = p.product_category_name
  )

UNION ALL

-- 23. Kích thước hoặc khối lượng sản phẩm không hợp lệ (<= 0)
SELECT 
    'product_dimensions',
    'WARN',
    COUNT_BIG(*),
    N'Nonpositive dimensions/weight are not valid physical measures.'
FROM clean.products 
WHERE product_weight_g <= 0 
   OR product_length_cm <= 0 
   OR product_height_cm <= 0 
   OR product_width_cm <= 0

UNION ALL

-- 24. Tọa độ địa lý vượt ngoài giới hạn chuẩn
SELECT 
    'geolocation_bounds',
    'WARN',
    COUNT_BIG(*),
    N'Invalid global coordinate bounds. Geography enrichment is optional.'
FROM clean.geolocation 
WHERE geolocation_lat NOT BETWEEN -90 AND 90 
   OR geolocation_lng NOT BETWEEN -180 AND 180;

-- 3. Kiểm tra các trường hợp tổng hợp đặc biệt (Aggregate Checks)
INSERT INTO #checks (check_id, severity, failed_count, description)

-- 25. Đơn hàng có nhiều đánh giá (cần xử lý lấy đánh giá mới nhất)
SELECT 
    'multiple_reviews',
    'WARN',
    COUNT_BIG(*),
    N'Select one stable latest review per order.'
FROM (
    SELECT order_id 
    FROM clean.order_reviews 
    GROUP BY order_id 
    HAVING COUNT(*) > 1
) r

UNION ALL

-- 26. Đơn hàng có sản phẩm từ nhiều seller khác nhau
SELECT 
    'multiple_sellers',
    'WARN',
    COUNT_BIG(*),
    N'Order outcome cannot identify responsibility of one seller.'
FROM (
    SELECT order_id 
    FROM clean.order_items 
    GROUP BY order_id 
    HAVING COUNT(DISTINCT seller_id) > 1
) s;

-- 27. Đối soát tài chính: Chênh lệch giữa tổng giá trị đơn hàng (hàng + ship) và thanh toán
WITH i AS (
    SELECT 
        order_id,
        SUM(price + freight_value) AS gross 
    FROM clean.order_items 
    GROUP BY order_id
),
p AS (
    SELECT 
        order_id,
        SUM(payment_value) AS paid 
    FROM clean.order_payments 
    GROUP BY order_id
)
INSERT INTO #checks (check_id, severity, failed_count, description)
SELECT 
    'payment_gross_mismatch',
    'WARN',
    COUNT_BIG(*),
    N'Absolute delta greater than 0.01 BRL; investigate, do not assume cause.'
FROM i 
JOIN p ON p.order_id = i.order_id 
WHERE ABS(i.gross - p.paid) > 0.01;

-- 4. Báo cáo kết quả và xử lý ngoại lệ
SELECT 
    *,
    CASE 
        WHEN failed_count = 0 THEN 'PASS' 
        WHEN severity = 'FATAL' THEN 'FAIL' 
        ELSE 'WARN' 
    END AS status
FROM #checks 
ORDER BY 
    severity, 
    check_id;

-- Nếu có lỗi FATAL bị vi phạm, dừng pipeline và báo lỗi
IF EXISTS (SELECT 1 FROM #checks WHERE severity = 'FATAL' AND failed_count > 0)
BEGIN
    THROW 50022, 'Fix FATAL checks before running sql/analysis queries.', 1;
END;

DROP TABLE #checks;

GO
IF (SELECT COUNT_BIG(*) FROM clean.orders)<>(SELECT COUNT_BIG(*) FROM dwh.fact_orders)
 THROW 50100,'Order count mismatch',1;
IF (SELECT COUNT_BIG(*) FROM clean.order_items)<>(SELECT COUNT_BIG(*) FROM dwh.fact_order_items)
 THROW 50101,'Item count mismatch',1;
IF (SELECT SUM(price) FROM clean.order_items)<>(SELECT SUM(price) FROM dwh.fact_order_items)
 THROW 50102,'Merchandise mismatch',1;
IF (SELECT SUM(freight_value) FROM clean.order_items)<>(SELECT SUM(freight_value) FROM dwh.fact_order_items)
 THROW 50103,'Freight mismatch',1;
IF (SELECT SUM(payment_value) FROM clean.order_payments)<>(SELECT SUM(total_payment) FROM dwh.fact_orders)
 THROW 50104,'Payment mismatch',1;
IF (SELECT COUNT(*) FROM mart.vw_sales)<>(SELECT COUNT(*) FROM clean.orders)
 THROW 50105,'Sales view fanout',1;
SELECT 'PASS' warehouse_reconciliation;
-- Raw-to-clean: exact duplicate business rows are intentionally collapsed.
IF (SELECT COUNT(*) FROM (SELECT DISTINCT order_id FROM stg.orders) r)<>(SELECT COUNT(*) FROM clean.orders)
 THROW 50106,'Raw to clean orders mismatch',1;
IF (SELECT SUM(CONVERT(decimal(18,2),NULLIF(price,''))) FROM stg.order_items)<>(SELECT SUM(price) FROM clean.order_items)
 THROW 50107,'Raw to clean merchandise mismatch: inspect duplicate source rows',1;
IF (SELECT SUM(merchandise_value) FROM mart.vw_sales)<>(SELECT SUM(price) FROM clean.order_items)
 THROW 50108,'Mart merchandise mismatch',1;
