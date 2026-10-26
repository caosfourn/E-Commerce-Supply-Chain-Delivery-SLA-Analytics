# Data dictionary

| Object | Grain / key | Nội dung |
|---|---|---|
| stg.customers/orders/items/payments/reviews/products/sellers/geolocation/category_translation | Theo CSV, chưa có khóa | Tất cả NVARCHAR; tên items đầy đủ là order_items, tương tự payments/reviews |
| clean.customers | customer_id | customer_unique_id, địa chỉ theo đơn |
| clean.orders | order_id | Status + 5 timestamp DATETIME2 |
| clean.order_items | order_id, order_item_id | product_id, seller_id; price/freight DECIMAL(10,2) |
| clean.order_payments | order_id, payment_sequential | type, installments, value |
| clean.order_reviews | review_pk; một order sau dedup | Điểm, creation, answer, nội dung review |
| clean.products | product_id | Category và kích thước; sửa lỗi tên lenght |
| clean.sellers | seller_id | Zip, city, state |
| clean.category_translation | product_category_name | Tên tiếng Anh |
| clean.geolocation | Điểm raw đã ép kiểu | Nhiều điểm/zip |
| clean.zip_centroids | zip_prefix (unique index) | AVG tọa độ hợp lệ |
| dwh.dim_customer | customer_key surrogate; customer_id unique | Snapshot địa chỉ, unique_id, lat/lng |
| dwh.dim_seller | seller_key; seller_id unique | Địa chỉ, lat/lng |
| dwh.dim_product | product_key; product_id unique | Thuộc tính và category_en |
| dwh.dim_date | date_key YYYYMMDD | date, year, quarter, month, ISO week, weekday Mon=1, weekend |
| dwh.fact_orders | order_id | customer/date FK; status, timestamps, duration, eligible/late, review, payment, flags |
| dwh.fact_order_items | order_id, order_item_id | order/product/seller/customer/date FK; tiền, distance, value flag |
| mart.vw_sales | order | Merchandise, freight, payment tách riêng |
| mart.vw_logistics | order | Facts + customer state/unique_id/month |
| mart.vw_customer | customer_unique_id | Đơn đầu toàn lịch sử; repeat_90d, has_90d_followup |
| mart.vw_seller | order, seller | Kết quả cấp đơn gắn seller; distance |
| mart.vw_category | order, category | Kết quả cấp đơn gắn ngành |

Định nghĩa duration/flags và NULL: xem [business rules](business_rules.md). DDL là nguồn đầy đủ cho kiểu dữ liệu/cột. Mọi datetime là thời gian nguồn, không tự đổi múi giờ.
