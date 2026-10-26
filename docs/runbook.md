# Runbook hiện hành

SQL Server 2017+ và SSMS; Python 3.11+, ODBC Driver 18 khi kết nối SQL.

1. Chạy 00 tạo database olist (nếu chưa có) và bốn schema.
2. Chạy 01 tạo staging. Nếu bảng đã tồn tại, dừng; không chạy chồng pipeline cũ.
3. Chạy `python scripts/prepare_review_bulk.py` tại root project. Script giữ nguyên CSV gốc, tạo `data/prepared/olist_order_reviews.bulk` và manifest JSON, kiểm tra đọc ngược khớp từng trường. Sửa @folder và kiểm tra @review_file ở 02; cả hai đường dẫn phải đọc được bởi tài khoản dịch vụ SQL Server. Chạy toàn file 02: 8 bảng dùng CSV, review dùng UTF-8 character mode với field 0x1f / record 0x1e để giữ nguyên newline/quote trong comment. Nạp có transaction, lỗi rollback.
4. Chạy 03 profiling. Dữ liệu lỗi kiểu phải điều tra, không sửa raw. Chạy 04 tạo clean và ép kiểu nghiêm ngặt, PK/FK, dedup review, centroid.
5. Chạy 05 dimensions, 06 facts, 07 views, 08 quality và reconciliation. Gặp lỗi: dừng, không chạy tiếp. Các DDL 01/04/05/06 không idempotent; build trên schema mới/trống.
6. Chạy A1–A8. 08 phải không có FATAL, đọc WARN. ScriptDom chỉ là kiểm tra cú pháp, chưa xác nhận runtime SQL.

Nếu một lần chạy 05/06/07 bị lỗi hoặc tạo object dở, chạy `sql/99_reset_dwh_mart_for_rebuild.sql`, rồi chạy lại đầy đủ 05 → 06 → 07 → 08. File reset chỉ xóa object dwh/mart, không xóa stg/clean.

## Chạy lại

Nếu bước 02 lỗi 7301 tại review: tạo lại file prepared bằng lệnh trên và mở lại script 02 đã cập nhật trong SSMS, chạy toàn bộ. Không chạy lại 01 vì bảng staging đã tồn tại. Các thông báo “Đã nạp” trước lỗi chỉ là tiến độ trong transaction, không phải xác nhận COMMIT. File mới in COMMIT chỉ sau khi cả 9 bảng nạp xong. Guard review là 99.224 dòng theo snapshot Olist hiện tại; nếu đổi dataset, cập nhật số này theo manifest prepared. Khi chuyển sang máy SQL Server khác, chép cả raw và prepared sang máy đó.

Phân tích và 07 có thể chạy lại. Build 00–08 từ đầu trên một database phát triển trống; nếu cần tên khác `olist`, thay USE/CREATE DATABASE nhất quán trong các bản sao script. Không có script tự DROP DATABASE. Khi rebuild database hiện có, sao lưu trước và chỉ gỡ object của project theo thứ tự view → fact → dimension → clean → stg. Nếu 04 lỗi sau CREATE TABLE, schema có thể còn bảng rỗng; không nạp tiếp trên trạng thái đó.

## CSV và notebook

Mở từng notebook 01–03, chọn kernel đã cài requirements và dùng **Restart Kernel → Run All**. Không cần script runner. Profiling raw dùng SQL 03; kiểm tra dữ liệu và đối soát dùng SQL 08. Notebook có assertion về grain, eligible và review score trước khi tính thống kê.

Đặt OLIST_SERVER trong môi trường trước khi mở Jupyter nếu khác localhost. Notebook chỉ đọc mart qua `notebooks/utils/db.py`, không đọc CSV/stg hoặc tính lại các trường nghiệp vụ do SQL cung cấp. Không in connection string; .env không tự nạp. Kết nối lỗi thì dừng và kiểm tra SQL Server, không đổi nguồn ngầm.

EXPORT_RESULTS=True xuất bảng/hình vào `data/exports/sql_mart`. `data/exports/csv`, `reports/notebooks`, manifest cũ và báo cáo cũ là snapshot lịch sử, không được xem là outputs của notebook mới. Cập nhật insight và case study thủ công từ kết quả mới. PDF hiện có giữ nguyên snapshot, không tự tái tạo.
