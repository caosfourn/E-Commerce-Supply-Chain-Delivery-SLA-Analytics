# Phạm vi bàn giao

00–08: pipeline 4 tầng. A1–A8: bối cảnh, nhóm ưu tiên, retention, logistics/review, seller/routes, payment, distance, sensitivity. Notebook 01–03 chỉ đọc mart, tự chứa phần thống kê/biểu đồ và chạy bằng Run All. scripts chỉ giữ prepare_review_bulk.py. Case study và insight hiện có là snapshot CSV cũ, cần cập nhật thủ công khi chạy phân tích SQL mới. Dashboard ngoài phạm vi.

Còn cần xác nhận trên instance SQL Server: chạy 00–08 từ DB trống, đối chiếu A1–A8 với CSV. Không đánh dấu runtime SQL hoàn tất chỉ dựa ScriptDom.
