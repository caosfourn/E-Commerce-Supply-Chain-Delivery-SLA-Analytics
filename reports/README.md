# Kết quả phân tích

- case_study.md / case_study.pdf: snapshot CSV trước khi đơn giản hóa, 7 insight, bằng chứng, khuyến nghị và tác động giả định; không phải kết quả notebook SQL mới.
- insights_log.md: quan sát, bằng chứng, giả thuyết, hành động, tác động.
- executive_summary.md: tóm tắt; findings.md: bản chi tiết cùng nguồn case study.
- data_quality.md: chất lượng CSV.
- quality/analysis_run_csv.json: trạng thái, checksum và phiên bản. sql_syntax_validation.txt: cú pháp, không phải runtime SQL.
- ../data/exports/csv/: snapshot cũ về retention 90d, kiểm định review, sensitivity, chặng, khoảng cách, shortlist 30/50/100.
- notebooks/ và figures/: EDA ban đầu. Review chưa lọc timing là sensitivity; dùng sensitivity.csv scenario main cho KPI chính.

Quy trình hiện tại: mở ba notebook, Restart Kernel → Run All, bật EXPORT_RESULTS để xuất vào data/exports/sql_mart. Đọc kết quả và cập nhật báo cáo Markdown thủ công; PDF hiện có không tự tái tạo. Các câu lệnh chạy script trong báo cáo lịch sử đã hết hiệu lực; xem notebooks/README.md cho cách chạy hiện hành. Dashboard ngoài phạm vi.

`quality/notebook_simplification_validation.json` ghi giới hạn kiểm tra notebook mới; không dùng kết quả kiểm tra dữ liệu giả lập để kết luận số liệu kinh doanh.
