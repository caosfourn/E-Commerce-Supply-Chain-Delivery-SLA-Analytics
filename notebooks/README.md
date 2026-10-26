# Notebooks

Ba notebook tự chứa các bước phân tích, không gọi script phân tích bên ngoài:

| Notebook | Nội dung | View nguồn |
|---|---|---|
| 01_data_quality_eda | Grain, coverage, status, tiền hàng/freight/payment, biểu đồ theo tháng | vw_sales |
| 02_delivery_analysis | SLA/chặng, shortlist 30/50/100, retention Wilson 95%, distance Spearman | vw_logistics, vw_seller, vw_category, vw_customer |
| 03_customer_experience | Review/coverage, Mann–Whitney, rank-biserial, sensitivity, phân tầng | vw_logistics, vw_category |

Chạy SQL 00–08 trước. Cài requirements rồi mở notebook trong VS Code hoặc chạy `jupyter lab` tại root project. Chọn Python kernel, **Restart Kernel → Run All**. Mỗi notebook chạy độc lập, không cần chạy notebook khác trước.

Kết nối mặc định localhost/olist, ODBC Driver 18, Windows authentication. Nếu khác, trong PowerShell trước khi mở Jupyter: `$env:OLIST_SERVER = '.\SQLEXPRESS'`. Có thể cấu hình OLIST_DATABASE, OLIST_DRIVER hoặc OLIST_CONNECTION_STRING. `.env.example` chỉ là mẫu, không được tự nạp. Không ghi mật khẩu vào notebook. Xem `utils/db.py`.

SQL là nguồn định nghĩa is_eligible, is_late, duration, review hợp lệ, repeat_90d và distance_km. Python không đọc stg/raw và không dựng lại các trường đó. Các assertion trong notebook kiểm tra grain và miền giá trị cần cho phân tích; không thay thế SQL 08.

Mặc định chỉ hiển thị kết quả. Đặt EXPORT_RESULTS=True để xuất bảng/hình vào data/exports/sql_mart. SQL mart phải sẵn sàng; không có CSV fallback. Báo cáo được cập nhật thủ công; các outputs CSV cũ là snapshot lịch sử.
