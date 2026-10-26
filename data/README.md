# Dữ liệu đầu vào

Nguồn công bố: [Brazilian E-Commerce Public Dataset by Olist — Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce). Ngày tải và phiên bản Kaggle của các file local chưa được ghi nhận; không suy đoán từ ngày sửa file. Metadata giấy phép chưa được lưu cùng bộ dữ liệu này; kiểm tra điều kiện ở trang nguồn khi công bố lại raw.

CSV UTF-8, phân tách dấu phẩy, hàng đầu là tên cột. Review có dấu phẩy/dấu nháy và xuống dòng bên trong trường được quote; dùng CSV parser, không đếm số dòng văn bản. Timestamp nguồn không có offset; không tự đổi múi giờ. Tiền BRL, kích thước cm, cân nặng g, ZIP là prefix 5 chữ số.

| File trong raw/ | Bảng dbo | Dòng tham chiếu |
|---|---|---:|
| olist_customers_dataset.csv | customers | 99,441 |
| olist_orders_dataset.csv | orders | 99,441 |
| olist_order_items_dataset.csv | order_items | 112,650 |
| olist_order_payments_dataset.csv | order_payments | 103,886 |
| olist_order_reviews_dataset.csv | order_reviews | 99,224 |
| olist_products_dataset.csv | products | 32,951 |
| olist_sellers_dataset.csv | sellers | 3,095 |
| olist_geolocation_dataset.csv | geolocation | 1,000,163 |
| product_category_name_translation.csv | category_translation | 71 |

Giữ nguyên raw. [Audit lịch sử](../reports/quality/raw_profile.json) lưu SHA-256, số cột, records và multiline của bản CSV cũ. [Manifest phân tích cũ](../reports/quality/analysis_run_csv.json) lưu checksum của lần tính báo cáo trước khi đơn giản hóa. Quy trình hiện tại dùng SQL 03/08 để kiểm tra dữ liệu; notebook chỉ đọc mart và xuất vào `exports/sql_mart` khi bật EXPORT_RESULTS. Các snapshot cũ không được tự cập nhật.

Không cần bản processed toàn bộ dữ liệu: notebook đọc dbo hoặc raw theo cấu hình. Bảng tổng hợp và biểu đồ tái tạo nằm ở `reports/notebooks/<tên notebook>/<nguồn>/`; không sửa tay để thay đổi kết quả. Thông tin cột và grain: [data dictionary](../docs/data_dictionary.md).
