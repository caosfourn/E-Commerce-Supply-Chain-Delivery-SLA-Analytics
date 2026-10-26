# Rút gọn project — 2026-10-26

Luồng hiện hành: prepare_review_bulk.py → SQL 00–08 → SQL A1–A8 / notebook đọc mart → cập nhật báo cáo thủ công.

- scripts chỉ giữ prepare_review_bulk.py. File này kiểm tra dữ liệu và round-trip ngay khi tạo file nạp review.
- utils/db.py độc lập, chỉ kết nối SQL/read_mart; bỏ olist_helpers.py và luồng CSV phân tích song song.
- Notebook 01: bối cảnh, coverage, status, tiền; notebook 02: SLA, chặng, shortlist, retention, distance; notebook 03: review, kiểm định, độ nhạy.
- Bỏ runner, script profiling riêng, script tạo báo cáo/PDF, script kiểm thử và checker cú pháp khỏi scripts. SQL 03/08 và assertion trong notebook giữ vai trò kiểm tra dữ liệu.
- Báo cáo và outputs CSV cũ được giữ như snapshot lịch sử; PDF không tự cập nhật. Bảng/hình mới chỉ xuất khi bật EXPORT_RESULTS, vào data/exports/sql_mart.

Bản sao trước thay đổi: `tmp/scripts_notebooks_before_simplification_20261026.zip` (local, gitignored). Chứa scripts và notebooks cũ để khôi phục khi cần. Không cần đưa bản sao này lên repo portfolio.

Kiểm chứng: ba notebook qua kiểm tra cấu trúc và thực thi code cell bằng dữ liệu mart giả lập, kèm assertion độc lập về tiền, cỡ mẫu, coverage, retention và effect size. Xem reports/quality/notebook_simplification_validation.json. SQL Server localhost không kết nối được ở lần kiểm tra này, nên chưa xác nhận Run All với SQL thực tế. Không thay đổi dữ liệu database trong lần rút gọn.
