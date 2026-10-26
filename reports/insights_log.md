# Olist: logistics và trải nghiệm giao hàng

Nguồn kết quả: **csv**, cohort mua từ 2017-01-01 đến trước 2018-09-01. SQL runtime chưa xác nhận trên instance thật. Dashboard ngoài phạm vi.

Mục tiêu: xác định chặng kéo dài, nhóm ưu tiên theo số đơn trễ, và mối liên quan với review/mua lại. Kiến trúc mới: stg → clean → dwh → mart; Q1–Q7 được triển khai trong A1–A8 và ba notebook.

Phương pháp: một dòng/đơn cho KPI chung; tiền hàng/payment tổng hợp riêng; review mới nhất, main cùng/sau giao; ngày trễ theo ngày lịch; duration theo giây. Retention chọn đơn đầu toàn lịch sử, 90 ngày theo dõi cố định. Review test là hai phía, rank-biserial âm nghĩa nhóm trễ có điểm thấp hơn. Phân tầng chỉ là mô tả; chưa có ước lượng hiệu ứng đã điều chỉnh hoặc suy luận nhân quả.
## 1. SLA và thời gian thực tế

- Quan sát: Late rate 6.79%; median/P90 10.21/23.06 ngày.
- Bằng chứng: `data/exports/csv/sensitivity.csv; sql/analysis/a4_logistics_review.sql`.
- Nguyên nhân khả dĩ / giới hạn: Ngày dự kiến có đệm; đúng hạn không đồng nghĩa giao nhanh.
- Khuyến nghị: Operations theo dõi đồng thời SLA và P90 thực tế.
- Tác động ước tính: Nếu ngăn được 10% trong 6,531 đơn trễ thì khoảng 653 đơn được cải thiện; đây là kịch bản, không phải dự báo.

## 2. Chặng vận chuyển dài nhất

- Quan sát: Transit P90 18.92 ngày; handoff P90 5.99 ngày. Mẫu transit 96,018.
- Bằng chứng: `data/exports/csv/stages.csv; a4`.
- Nguyên nhân khả dĩ / giới hạn: Chưa có log chi tiết để tách hãng vận chuyển và thời gian chờ. P90 chặng không cộng được.
- Khuyến nghị: Logistics lấy log scan cho các tuyến có nhiều đơn trễ.
- Tác động ước tính: Nếu pilot giảm 1 ngày/đơn trên 100 đơn, tiết kiệm 100 ngày-chờ cộng dồn; cần đo lại tác động.

## 3. Ưu tiên theo số đơn bị ảnh hưởng

- Quan sát: SP, RJ, MG có 3,831 đơn trễ, chiếm 58.66% tổng đơn trễ.
- Bằng chứng: `data/exports/csv/priority_states.csv; priority_routes.csv; priority_sellers.csv; a2/a5`.
- Nguyên nhân khả dĩ / giới hạn: Quy mô đơn lớn có thể giải thích số trễ cao; không quy trách nhiệm từ outcome cấp đơn.
- Khuyến nghị: Operations xem shortlist 30/50/100 trước khi chọn seller/tuyến.
- Tác động ước tính: Giảm giả định 10% số trễ tại 3 bang này tương ứng khoảng 383 đơn.

## 4. Review thấp liên quan tới giao trễ

- Quan sát: Review cùng/sau giao: low-review đúng hạn 9.23%, trễ 25.09%. Mẫu 88,970/1,630; rank-biserial -0.303, Mann–Whitney p=1.88e-129.
- Bằng chứng: `data/exports/csv/review_test.csv; sensitivity.csv; review_strata.csv; a4/a8`.
- Nguyên nhân khả dĩ / giới hạn: Có selection bias theo timing review và nhiễu nhóm khách/sản phẩm; kiểm định không chứng minh nhân quả.
- Khuyến nghị: Customer Experience chạy pilot thông báo chủ động và đo review sau giao.
- Tác động ước tính: Nếu giảm tuyệt đối 5 điểm % low-review trong 1.000 khách đủ điều kiện, kịch bản là 50 review thấp ít hơn; cần nhóm đối chứng.

## 5. Coverage review làm thay đổi kết luận

- Quan sát: Coverage nhóm trễ 24.96%; đúng hạn 99.22%. Khi dùng mọi timing, low-review trễ 62.40%.
- Bằng chứng: `data/exports/csv/sensitivity.csv; a8`.
- Nguyên nhân khả dĩ / giới hạn: Review trước giao có thể ghi nhận trải nghiệm chờ; loại chúng tạo tập khác về bản chất.
- Khuyến nghị: Analytics luôn công bố timing và mẫu số, kiểm tra lại với dữ liệu thu review chuẩn.
- Tác động ước tính: Bổ sung 100 review sau giao cho nhóm trễ tăng độ phủ khoảng 1,53 điểm % nếu tổng eligible giữ nguyên; không giả định điểm review.

## 6. Mua lại 90 ngày chưa cho kết luận chắc chắn

- Quan sát: Đơn đầu đúng hạn 2.04% (n=69,666; Wilson 95% 1.94%–2.15%); trễ 1.79% (n=5,686; 1.48%–2.17%).
- Bằng chứng: `data/exports/csv/retention_90d.csv; a3`.
- Nguyên nhân khả dĩ / giới hạn: Khoảng tin cậy chồng lấp; tỷ lệ mua lại thấp và cửa sổ quan sát ngắn.
- Khuyến nghị: CRM thử nghiệm chăm sóc sau đơn đầu, xác định cỡ mẫu trước pilot.
- Tác động ước tính: Mức nâng giả định 0,5 điểm % trên 1.000 khách là 5 khách mua lại; chưa có chứng cứ đây là hiệu quả thực.

## 7. Khoảng cách là biến kiểm soát thăm dò

- Quan sát: Spearman distance–transit rho=0.615, n=95,542 đơn có đủ dữ liệu. Dùng khoảng cách seller xa nhất cho mỗi đơn.
- Bằng chứng: `data/exports/csv/distance_correlation.csv; distance_routes.csv; a7`.
- Nguyên nhân khả dĩ / giới hạn: Centroid zip và đường chim bay là proxy; đơn nhiều seller không có timestamp giao riêng.
- Khuyến nghị: Logistics so sánh tuyến trong cùng distance band, sau đó lấy dữ liệu hành trình thật.
- Tác động ước tính: Pilot 100 đơn/tuyến là cỡ mẫu triển khai giả định; chưa lượng hóa tiết kiệm khi chưa có chi phí và tác động thực.

## Khả năng tái lập và giới hạn

Chạy `python scripts/run_analysis.py --source csv`; nguồn bảng là data/exports/csv. A8 bỏ tháng cuối, đổi timing review, bỏ duration >60 ngày; A2/A5 chạy ngưỡng 30/50/100. Giá trị tiền là BRL; không có chi phí marketing hoặc doanh thu thực nhận Olist. Các ngưỡng outlier chỉ là lựa chọn thăm dò. Xem docs/runbook.md để chạy SQL từ database trống.
