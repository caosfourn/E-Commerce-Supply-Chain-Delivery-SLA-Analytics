# Olist: logistics và trải nghiệm giao hàng

Nguồn kết quả: **csv**, cohort mua từ 2017-01-01 đến trước 2018-09-01. SQL runtime chưa xác nhận trên instance thật. Dashboard ngoài phạm vi.

Mục tiêu: xác định chặng kéo dài, nhóm ưu tiên theo số đơn trễ, và mối liên quan với review/mua lại. Kiến trúc mới: stg → clean → dwh → mart; Q1–Q7 được triển khai trong A1–A8 và ba notebook.

Phương pháp: một dòng/đơn cho KPI chung; tiền hàng/payment tổng hợp riêng; review mới nhất, main cùng/sau giao; ngày trễ theo ngày lịch; duration theo giây. Retention chọn đơn đầu toàn lịch sử, 90 ngày theo dõi cố định. Review test là hai phía, rank-biserial âm nghĩa nhóm trễ có điểm thấp hơn. Phân tầng chỉ là mô tả; chưa có ước lượng hiệu ứng đã điều chỉnh hoặc suy luận nhân quả.

- **SLA và thời gian thực tế:** Late rate 6.79%; median/P90 10.21/23.06 ngày.
- **Chặng vận chuyển dài nhất:** Transit P90 18.92 ngày; handoff P90 5.99 ngày. Mẫu transit 96,018.
- **Ưu tiên theo số đơn bị ảnh hưởng:** SP, RJ, MG có 3,831 đơn trễ, chiếm 58.66% tổng đơn trễ.
- **Review thấp liên quan tới giao trễ:** Review cùng/sau giao: low-review đúng hạn 9.23%, trễ 25.09%. Mẫu 88,970/1,630; rank-biserial -0.303, Mann–Whitney p=1.88e-129.
- **Coverage review làm thay đổi kết luận:** Coverage nhóm trễ 24.96%; đúng hạn 99.22%. Khi dùng mọi timing, low-review trễ 62.40%.
- **Mua lại 90 ngày chưa cho kết luận chắc chắn:** Đơn đầu đúng hạn 2.04% (n=69,666; Wilson 95% 1.94%–2.15%); trễ 1.79% (n=5,686; 1.48%–2.17%).
- **Khoảng cách là biến kiểm soát thăm dò:** Spearman distance–transit rho=0.615, n=95,542 đơn có đủ dữ liệu. Dùng khoảng cách seller xa nhất cho mỗi đơn.

Chi tiết, khuyến nghị và kịch bản tác động: [case study](case_study.md).