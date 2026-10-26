# Workflow

CSV → stg → clean → dwh → mart → A1–A8 / Python → case study.

Xem [runbook](runbook.md). Dashboard hoãn theo yêu cầu. Notebook chỉ đọc mart: SQL tính trường nghiệp vụ, Python tổng hợp/vẽ biểu đồ/kiểm định; không có luồng CSV phân tích song song. Chỉ giữ scripts/prepare_review_bulk.py để chuẩn bị review. Chạy notebook bằng Run All và cập nhật báo cáo thủ công.
