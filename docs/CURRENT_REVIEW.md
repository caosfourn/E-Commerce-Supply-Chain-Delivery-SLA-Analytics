# Review hiện trạng project

Ngày review: 20/10/2026.

**Ghi chú phiên bản:** tài liệu dưới đây review bộ SQL ban đầu, trước lần triển khai kế tiếp. Các vị trí dòng và findings mô tả phiên bản cũ. Bộ SQL hiện tại đã được thay theo kế hoạch; xem `runbook.md`, `metric_dictionary.md` và `data_model.md` để chạy phiên bản mới. Chưa xác nhận thực thi end-to-end trên SQL Server.

## Kết luận

Nền tảng SQL đúng hướng và có thể tiếp tục phát triển. Điểm mạnh là staging riêng, kiểu dữ liệu core rõ, composite key của items/payments, surrogate key cho review, và aggregate các bảng con trước khi join vào fact_orders.

Chưa nên xem đây là mô hình KPI hoàn chỉnh để đưa lên dashboard. Các ưu tiên chính là transaction/retry khi load, định nghĩa doanh thu và delivered, mẫu số SLA, grain của KPI seller và kiểm chứng CSV multiline.

Phạm vi đã kiểm tra: đọc đầy đủ README và 3 SQL; đọc 9 CSV bằng Python csv parser, đếm record/column, checksum và một số ngoại lệ liên quan. **Chưa thực thi SQL Server, chưa xác nhận BULK INSERT/FK/index chạy thành công, chưa có dashboard để kiểm thử.** Có `sqlcmd` trên máy nhưng chưa có cấu hình instance được xác nhận; review không tự chạy các script có DROP TABLE.

## 1. Đánh giá từng file hiện có

| File | Đánh giá | Điểm tốt | Cần làm tiếp |
|---|---|---|---|
| README.md | Ban đầu 0 byte | Chưa có nội dung để đánh giá | Đã bổ sung trang giới thiệu và trạng thái; sau này thêm kết quả và runbook hoàn chỉnh |
| sql/01_schema.sql | Nền tảng hợp lý | stg/core riêng, DECIMAL cho tiền, DATETIME2, PK hợp lý | Tách reset phá dữ liệu, ZIP dạng text, bảo vệ lỗi độ dài/parse |
| sql/02_load_data.sql | Có thể dùng làm bản đầu, cần gia cố | CSV UTF-8, TRY_CONVERT, FK/index, bảng đối chiếu count | Atomic publish, retry, audit conversion, rowcount fail gate, config path |
| sql/03_quality_checks_and_model.sql | Có tư duy phân tích tốt, đang gộp quá nhiều trách nhiệm | DQ theo trạng thái, aggregate trước join, chọn review, đối chiếu facts | Tách thành 3 file; sửa KPI/grain/date/payment; thêm metrics theo chặng |
| data/raw/ | Đủ 9 file và count kỳ vọng | Không thấy record lệch số cột qua parser | Tiếp tục kiểm tra domain, orphan, uniqueness và SQL load |
| notebooks/, dashboard/ | Chưa có file tại thời điểm bắt đầu review | Có sẵn thư mục | Làm sau khi chốt KPI và model |
| reports/ | Ban đầu chưa có output | — | Đã thêm raw_profile.json làm bằng chứng kiểm tra |

## 2. Kết quả đọc CSV thực tế

Đếm theo CSV record, không đếm dòng vật lý vì review có xuống dòng trong ô.

| Nguồn | Record |
|---|---:|
| customers | 99.441 |
| geolocation | 1.000.163 |
| order_items | 112.650 |
| order_payments | 103.886 |
| order_reviews | 99.224 |
| orders | 99.441 |
| products | 32.951 |
| sellers | 3.095 |
| category_translation | 71 |

Cả 9 count khớp số kỳ vọng trong `02_load_data.sql`. Không có record lệch số cột theo parser. Điều này không chứng minh toàn bộ dữ liệu hợp lệ về nghiệp vụ.

- Có 3.852 review record chứa newline trong trường dữ liệu: phải kiểm chứng load multiline thực sự trên SQL Server.
- Có 96.478 đơn trạng thái delivered, trong đó 8 thiếu actual delivery timestamp.
- Có 6 đơn trạng thái khác delivered nhưng có actual delivery timestamp.
- Có 23 đơn actual delivery trước carrier timestamp.
- Không có estimated delivery timestamp trống trong bản CSV hiện tại. Lỗi xử lý NULL của code vẫn là rủi ro khi parse hỏng hoặc đổi nguồn.
- 775 đơn không có item; cần kiểm tra theo trạng thái, không mặc định tất cả là lỗi.
- 547 đơn có nhiều review; việc chọn một review là cần thiết.
- 1.278 đơn có nhiều seller; outcome cấp đơn không thể quy trách nhiệm duy nhất cho một seller.
- 40 đơn có loại payment của dòng lớn nhất không phải loại có tổng payment lớn nhất.
- Có 96.096 customer_unique_id.
- Ngày mua từ 2016-09-04 đến 2018-10-17. Tháng 9/2018 chỉ có 16 đơn, tháng 10 chỉ có 4; khoảng 2017-01 đến 2018-08 hợp lý để bắt đầu, nhưng vẫn phải kiểm tra cohort maturity.

Script tái lập: `python scripts/profile_raw.py`. Output: `reports/quality/raw_profile.json`, bao gồm SHA-256 từng CSV. Script này chỉ là audit phục vụ review, chưa phải bộ DQ đầy đủ.

## 3. Findings theo mức ưu tiên

P1: cần xử lý trước khi tin cậy pipeline/KPI. P2: cần xử lý trước khi bàn giao. P3: cải thiện khả năng bảo trì.

### P1 — Load có thể để lại dữ liệu nửa chừng

Vị trí: `sql/02_load_data.sql:12` và các INSERT từ dòng 58.

`SET XACT_ABORT ON` không tự tạo transaction bao trùm cả script. Nếu insert customers thành công rồi products lỗi, customers đã tồn tại trong khi các bước sau chưa hoàn thành. Chạy lại có thể lỗi PK vì guard chỉ kiểm tra FK_orders_customers, mà FK chưa chắc đã được tạo.

Hướng sửa: nạp staging và validate trước; bao phần publish core cùng constraints/index cần thiết bằng transaction có TRY/CATCH/ROLLBACK, hoặc quy trình batch/swap có trạng thái. Có kiểm thử failure/retry trong DB test. Không dùng chạy lại schema DROP TABLE như đường khôi phục mặc định.

### P1 — Tên revenue và population dễ dẫn đến kết luận sai

Vị trí: `sql/03_quality_checks_and_model.sql:196`, `:203`, `:230`.

`price + freight` đang mang tên revenue. `is_revenue_order` nhận cả created, approved, processing, invoiced và shipped. Đây là lựa chọn business rule chưa được giải thích; không chứng minh doanh thu thực nhận của Olist.

Hướng sửa: tách merchandise_value, freight_value, order_gross_value và payment_value. Báo delivered merchandise value với population rõ ràng. Nếu cần chỉ số booked/non-canceled value, đặt tên riêng và giữ definition. Không suy ra lợi nhuận hoặc platform revenue từ dữ liệu này.

### P1 — Delivered và SLA eligibility chưa nhất quán

Vị trí: `sql/03_quality_checks_and_model.sql:206–213`.

`is_delivered` chỉ dựa vào có ngày giao, không dựa vào status. Với bản raw hiện tại, 8 delivered thiếu ngày và 6 non-delivered có ngày làm định nghĩa này khác delivered status.

`is_late` chỉ guard actual date. Nếu estimated NULL, nhánh so sánh không đúng và ELSE 0 làm đơn thiếu dữ liệu trông như đúng hạn. Hiện raw không thiếu estimated, nhưng TRY_CONVERT vẫn có thể tạo NULL mà không audit.

Hướng sửa: tách is_delivered_status, has_delivery_timestamp, is_sla_eligible, is_late và flags từng chặng. Tỷ lệ trễ chỉ dùng eligible denominator. Không xóa đơn khỏi core để “làm sạch”.

### P1 — KPI cấp đơn lặp lại trên item fact

Vị trí: `sql/03_quality_checks_and_model.sql:225–232`.

Sao chép is_late/review_score/delivery_days sang item fact không tự sai, nhưng lấy AVG/SUM trên các cột này làm đơn nhiều item có trọng số lớn hơn. Ví dụ một đơn trễ 5 item và một đơn đúng hạn 1 item cho tỷ lệ 83,3% theo item, trong khi tỷ lệ theo đơn là 50%.

Hướng sửa: KPI tổng từ fact_orders. Theo seller/category dùng tập distinct order_id hoặc mart đúng grain. Công bố nhóm chồng lấp và chỉ gọi là “kết quả của đơn có seller tham gia”.

### P2 — Chọn main_payment_type chưa đúng với comment

Vị trí: `sql/03_quality_checks_and_model.sql:169–172`.

Code xếp hạng từng payment record. Comment mô tả phương thức chiếm giá trị lớn nhất trong đơn, nhưng một phương thức có thể xuất hiện ở nhiều sequence. Audit xác nhận 40 đơn khác nhau giữa hai cách tính, không chỉ là tình huống giả định.

Hướng sửa: GROUP BY order_id, payment_type, SUM(payment_value), sau đó ROW_NUMBER theo tổng giảm dần và tie-breaker cố định.

### P2 — CSV multiline và số dòng chưa có fail gate

Vị trí: `sql/02_load_data.sql:20–40`, `:145` trở đi.

Nhánh review bỏ ROWTERMINATOR không đủ để kết luận tự nhận mọi line ending đúng. CSV parser trong Python đọc được không đồng nghĩa BULK INSERT đã đọc đúng. Kiểm tra 99.224 records và một số comment multiline/accent sau khi nạp.

Query cuối chỉ hiển thị “KIỂM TRA LẠI”, không THROW khi lệch. Tài liệu Microsoft cho biết BULK INSERT có cơ chế MAXERRORS và dòng không import được có thể bị bỏ qua trong giới hạn lỗi. Cần fail gate theo count/reject log, không chỉ PRINT thành công.

Nguồn: [Microsoft BULK INSERT](https://learn.microsoft.com/en-us/sql/t-sql/statements/bulk-insert-transact-sql?view=sql-server-ver17).

### P2 — TRY_CONVERT che mất lỗi parse nếu không audit

Vị trí: phần staging → core trong `sql/02_load_data.sql`.

TRY_CONVERT hợp lý để tránh crash vì một giá trị, nhưng raw không trống mà kết quả NULL phải được ghi là conversion failure. Nếu không, model không phân biệt missing nguồn với lỗi import.

Hướng sửa: check raw non-empty AND typed NULL cho từng trường; reject/quarantine với reason, column và source key. Thêm kiểm tra score 1–5, số tiền, số nguyên, độ dài ID và khóa trùng trước khi publish.

### P2 — ISNULL(amount, 0) làm mất thông tin thiếu dữ liệu

Vị trí: `sql/03_quality_checks_and_model.sql:191–196`.

775 đơn không có item. Giá trị 0 có thể dùng cho một số tổng theo status nhưng không nên làm mất khả năng phân biệt “không có item” với “item giá trị 0”, hoặc amount bị parse lỗi.

Hướng sửa: giữ raw aggregate nullable và có has_items/is_amount_valid. Chỉ coalesce khi metric cụ thể cho phép.

### P2 — Mô hình thời gian và logistics còn thiếu

Vị trí: `sql/03_quality_checks_and_model.sql:92–111`, `:207–208`, `:227–232`.

dim_date có date_key INT nhưng fact chưa có key tương ứng; có thể nối full_date với purchase_date, cần ghi rõ. DATEDIFF(HOUR) đếm ranh giới giờ nên không phải duration chính xác đến giây.

shipping_limit_date có ở core nhưng chưa được đưa vào item fact. Chưa tách approval/handoff/transit. Không có shipment timestamp riêng từng seller/item nên so shipping_limit với carrier của order chỉ là proxy, đặc biệt với multi-seller.

Hướng sửa: dùng giây/86400.0 cho duration, date roles rõ ràng; giữ shipping_limit, thêm flags và metrics từng chặng. Không gọi proxy handoff là tỷ lệ vi phạm cam kết seller đã xác minh.

### P2 — Địa chỉ khách gần nhất không đại diện mọi đơn lịch sử

Vị trí: `sql/03_quality_checks_and_model.sql:135–152`.

dim_customer chọn city/state theo lần mua mới nhất. Nếu dùng dimension này lọc lịch sử giao hàng, đơn cũ có thể bị gán sang địa chỉ mới. fact_orders đã giữ city/state tại đơn: đây là điểm tốt cần dùng đúng trong dashboard.

Hướng sửa: phân biệt current customer attributes với order delivery geography; dùng geography cấp đơn cho SLA.

### P3 — Cần tách trách nhiệm và tài liệu hóa

- Tách A/B/C của SQL 03 thành quality/build/reconciliation.
- Sửa tên file trong thông báo lỗi `01_create_schema.sql` thành tên thực `01_schema.sql`.
- Dùng INSERT với danh sách cột đích để tránh phụ thuộc thứ tự schema.
- Dùng ZIP prefix dạng CHAR(5) và chuẩn hóa nhất quán để bảo toàn số 0 đầu khi hiển thị/join.
- Không coi review_pk identity là tie-breaker nghiệp vụ ổn định qua mọi lần load; bổ sung khóa/tie-breaker nguồn có thể tái lập.
- `DATENAME` phụ thuộc language session; quy định locale hoặc map tên tháng cố định.
- Tổng tiền hiển thị ở reconciliation đang CAST BIGINT nên mất phần thập phân, mặc dù CASE so sánh SUM gốc. Hiển thị DECIMAL để nhìn thấy chênh lệch cent; thêm freight và payment reconciliation.
- Comment A8 “lệch do voucher, làm tròn...” là giả thuyết, chưa có bằng chứng giải thích toàn bộ mismatch. Ngưỡng >1 BRL bỏ qua sai lệch nhỏ; báo cả delta và ngưỡng được chọn.
- A5 đếm customer_id lặp theo customer_unique_id chưa tự là repeat delivered buyers; cần lọc eligible orders nếu dùng chỉ số mua lặp thực sự.

## 4. Thứ tự sửa đề xuất

1. Metric dictionary: money/status/SLA/grain.
2. Transaction, retry, parse audit và rowcount gate.
3. Tách SQL 03; sửa main payment, NULL eligibility và durations.
4. Hoàn thiện grain/relationships, lead-time segments và seller attribution.
5. Chạy pipeline trong SQL Server, lưu DQ và reconciliation thực tế.
6. Làm notebook, Power BI và báo cáo theo PROJECT_PLAN.md.

Trong lần review này chưa thay đổi ba SQL hoặc CSV. Các thay đổi gồm tài liệu kế hoạch/review, README và script/output audit có thể tái lập.
