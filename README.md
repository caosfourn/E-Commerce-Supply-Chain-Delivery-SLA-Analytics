# Olist E-Commerce Analytics: logistics và trải nghiệm giao hàng

SQL Server / T-SQL · Star schema · Python EDA · 99k đơn hàng tại Brazil (2016–2018).

Mục tiêu: xác định chặng giao hàng kéo dài, nhóm cần ưu tiên theo số đơn trễ, và mối liên quan giữa trễ giao hàng, review thấp, mua lại. **Dashboard để chủ project thực hiện sau.**

## Kết quả chính (CSV, ngày mua 2017-01 đến 2018-08)

| KPI | Kết quả |
|---|---:|
| Đơn eligible / đơn trễ | 96.203 / 6.531 |
| Late rate | 6,79% |
| Median / P90 thời gian giao | 10,21 / 23,06 ngày |
| Review 1–2 sao, đúng hạn / trễ, review cùng hoặc sau giao | 9,23% / 25,09% |
| Mua lại 90 ngày, đơn đầu đúng hạn / trễ | 2,04% / 1,79% |

Review coverage nhóm trễ thấp; kết quả nhạy với thời điểm review. Không suy ra nhân quả. Khoảng tin cậy retention chồng lấp. Đọc [case study](reports/case_study.md) và [insights](reports/insights_log.md).

## Chạy lại project

1. Đặt 9 CSV Olist vào `data/raw/` (đã có trong máy này; không commit dữ liệu nặng).
2. Python 3.11+: `python -m pip install -r requirements.txt`.
3. Chạy `python scripts/prepare_review_bulk.py` để chuẩn bị review. Đây là script duy nhất cần giữ trong `scripts/`.
4. SQL Server 2017+: trong SSMS chạy lần lượt **00 → 08** trong `sql/` khi xây database mới. Review đọc file trung gian tại `data/prepared/`; 8 bảng còn lại đọc CSV gốc. Sửa `@folder`, kiểm tra `@review_file` ở 02. Database đã có dữ liệu và hoàn tất 08 thì không cần nạp lại. Dừng nếu một bước lỗi.
5. Chạy `sql/analysis/a1_*.sql` đến `a8_*.sql`. Các truy vấn đọc `mart`.
6. Mở ba notebook trong Jupyter/VS Code, chọn kernel đã cài requirements, **Restart Kernel → Run All** cho từng notebook. Kết nối mặc định `localhost`, database `olist`, Windows authentication; đặt `OLIST_SERVER` nếu khác. Xem [hướng dẫn notebook](notebooks/README.md).
7. Đặt `EXPORT_RESULTS=True` trong notebook nếu muốn xuất bảng/hình vào `data/exports/sql_mart/`. Viết/cập nhật báo cáo thủ công từ kết quả. Không còn runner hoặc script tự viết báo cáo.

**Nguồn kết quả:** các con số và case study bên trên là snapshot CSV cũ, được giữ để tham khảo. Notebook mới chỉ đọc SQL mart; không tự chuyển sang CSV khi kết nối lỗi. Nhật ký kiểm tra phiên bản notebook mới nằm ở `reports/quality/notebook_simplification_validation.json`; đây không phải bằng chứng nạp lại toàn bộ database.

## Kiến trúc và cấu trúc

`CSV → stg (nguyên bản) → clean (ép kiểu, review mới nhất, centroid) → dwh (2 fact + 4 dim) → mart (5 view) → phân tích`.

- `sql/00...08`: pipeline mới; `sql/analysis/a1...a8`: module Q1–Q7 và phụ lục thanh toán.
- `notebooks/01_data_quality_eda.ipynb`: kiểm tra grain/coverage của mart và bối cảnh. Profiling raw nằm ở SQL 03.
- `notebooks/02_delivery_analysis.ipynb`: giao hàng, nhóm ưu tiên, retention 90 ngày, khoảng cách.
- `notebooks/03_customer_experience.ipynb`: review, Mann–Whitney, kích thước tác động, độ nhạy.
- `notebooks/utils/db.py`: chỉ kết nối SQL và đọc mart; không chứa logic KPI.
- `scripts/prepare_review_bulk.py`: chuẩn bị dữ liệu review cho SQL 02, không làm phân tích.
- `docs/`: [business rules](docs/business_rules.md), [KPI](docs/kpi_definitions.md), [dictionary](docs/data_dictionary.md), [runbook](docs/runbook.md), [ERD](docs/erd.png).
- `reports/`: case study, nhật ký insight, bằng chứng CSV. `data/exports/`: dữ liệu phân tích xuất ra.

## Giới hạn

Ngày dự kiến thường có khoảng đệm; cần đọc cùng thời gian giao thực tế. Review trước giao chỉ thuộc sensitivity. Khoảng cách là đường chim bay giữa centroid zip, không phải quãng đường xe chạy. Đơn nhiều seller/ngành hàng có thể thuộc nhiều nhóm; không cộng các nhóm để suy ra tổng. Outcome cấp đơn không quy trách nhiệm cho riêng seller. Giá hàng, freight và payment tách riêng; không có doanh thu thực nhận Olist hay chi phí marketing.

Nguồn: [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce). Checksum raw lịch sử còn trong reports/quality; manifest prepared review ghi checksum khi chạy script chuẩn bị. Dashboard để thực hiện sau.
