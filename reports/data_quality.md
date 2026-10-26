# Báo cáo chất lượng và quyết định preprocessing

Nguồn tính toán: **CSV**, chạy ngày 2026-10-23 (UTC). Cohort ngày mua **[2017-01-01, 2018-09-01)**. Dấu phẩy phân cách hàng nghìn, dấu chấm thập phân. SLA là so sánh ngày giao thực tế với ngày dự kiến; chỉ tính đơn delivered đủ mốc hợp lệ. Kết quả CSV chưa xác nhận việc nạp hoặc kết quả trên SQL Server.

Các số bên dưới dùng **toàn bộ nguồn**, trừ dòng ghi rõ cohort. Bộ kiểm tra xuất từ notebook 01, không phải bản sao mọi check SQL.

| Kiểm tra | Số dòng vi phạm/quan sát |
|---|---:|
| delivered_without_date | 8 |
| non_delivered_with_date | 6 |
| actual_before_purchase | 0 |
| actual_before_carrier | 23 |
| approval_before_purchase | 0 |
| carrier_before_approval | 1,359 |
| invalid_item_money | 0 |
| invalid_payment_money | 0 |
| invalid_review_score | 0 |
| invalid_coordinates | 0 |

Khóa thiếu/trùng trên các bảng có khóa nghiệp vụ: **0**. Orphan trên sáu quan hệ đã kiểm tra: **0**.

Đơn có nhiều review: **547**; đây không tự động là lỗi dữ liệu. Orders thiếu item/payment/review:

- orders_without_items: **775**.
- orders_without_payments: **1**.
- orders_without_reviews: **768**.


Trong 98,665 đơn có cả gross và payment, có 303 đơn lệch hơn 0.01 BRL. Không ép hai đại lượng bằng nhau: chưa có dữ liệu nghiệp vụ đủ để giải thích từng khoản lệch.

## Quyết định xử lý

| Tình huống | Xử lý và ảnh hưởng |
|---|---|
| Thiếu actual/estimate | Giữ đơn, không tính SLA nếu thiếu mốc cần thiết; cohort loại 8 delivered |
| Thứ tự timestamp bất thường | Không sửa mốc nguồn; loại riêng duration không hợp lệ, giữ SLA nếu đủ điều kiện |
| Nhiều item/payment | Gộp từng bảng về một dòng/đơn trước JOIN để tránh nhân tiền |
| Nhiều review | Chọn mới nhất theo quy tắc tie-break trong helper và SQL; không xóa raw |
| Comment trống | Không loại review có score hợp lệ; comment là tùy chọn |
| Category thiếu/bản dịch thiếu | Fallback nhãn nguồn rồi unknown |
| ZIP lặp trong geolocation | Không JOIN thẳng raw geolocation vào orders |
| Outlier | Giữ dữ liệu hợp lệ, trình bày median/P90; chưa áp dụng winsorization |
| Cohort cuối snapshot | Báo sensitivity bỏ tháng cuối; không coi chưa giao là chắc chắn trễ |

## Bằng chứng

- [Kiểm tra Python](quality/dq_results_csv.csv): FATAL phải bằng 0 trước công bố; WARN cần quy tắc xử lý, không bắt buộc xóa hàng.
- [Đối chiếu với số tham chiếu CSV](quality/reference_checks_csv.csv): counts và tổng tiền; không phải đối chiếu raw → SQL khi source=csv.
- [Missingness](notebooks/01_data_quality_eda/csv/missing.csv), [theo trạng thái](notebooks/01_data_quality_eda/csv/missing_by_status.csv), [orphans](notebooks/01_data_quality_eda/csv/orphans.csv).
- [Audit CSV gốc](quality/raw_profile.json): header/count/checksum và multiline. Manifest của lần chạy phân tích lưu checksum hiện tại.

## Việc cần xác nhận trên SQL Server

Chạy 01 → 02 → 03 trong SSMS theo runbook; lưu kết quả count, multiline review và FATAL/WARN. Sau đó chạy analysis hoặc runner với `--source sql` để đối chiếu. Hiện báo cáo này không khẳng định các script SQL đã chạy thành công. Không có dashboard/PBIX trong phần bàn giao này.
