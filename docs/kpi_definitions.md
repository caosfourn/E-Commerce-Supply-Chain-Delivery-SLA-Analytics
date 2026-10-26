# Từ điển KPI

Phạm vi mặc định: mua 2017-01 đến 2018-08. Tỷ lệ dạng 0–1, không phải 0–100. Tiền BRL.

| KPI | Công thức và nguồn | Bộ lọc / mẫu số | Ví dụ |
|---|---|---|---|
| Orders | COUNT(*) mart.vw_sales, grain order | Mọi status | 99.092 |
| Merchandise | SUM(merchandise_value), vw_sales | delivered | Một đơn có 2 item 10+20 = 30 |
| Freight | SUM(freight_value), vw_sales | delivered; báo riêng | 2 item 2+3 = 5 |
| Payment | SUM(total_payment), vw_sales | Ghi rõ status; context mọi status | 2 giao dịch 15+20 = 35 |
| AOV | Merchandise / delivered orders | Không dùng payment | 30/1 = 30 |
| Eligible | SUM(is_eligible), vw_logistics | delivered + actual/estimated not null | 96.203 |
| Late rate | SUM(is_late)/SUM(is_eligible) | Eligible | 6.531/96.203 = 6,79% |
| Median/P90 delivery | PERCENTILE_CONT(.5/.9), delivery_days | Eligible, duration >=0; NULL không vào percentile | 10,21/23,06 ngày |
| Chặng | approval/handoff/transit_days | COUNT(duration) riêng từng chặng | Transit P90 18,92 ngày |
| Delay | actual date - estimated date | Eligible; âm là sớm | Giao 11/1, hẹn 10/1 => 1 |
| Low review rate | Điểm 1–2 / is_review_valid=1 | Eligible, latest, review cùng/sau giao | Nhóm trễ 25,09% |
| Review coverage | Valid reviews / eligible | Tính riêng theo nhóm SLA | Nhóm trễ 1.630/6.531 |
| Repeat 90d | Khách có lần mua sau trong 90d / khách đủ follow-up | vw_customer, đơn đầu eligible; unique_id | Nhóm trễ 102/5.686 |
| Distance | Haversine R=6371.0088 km | fact_order_items, centroid hợp lệ | Thiếu tọa độ => NULL |

`metric_dictionary.md` được thay bằng tài liệu này. Các kết quả legacy dùng toàn bộ review là sensitivity, không phải KPI review chính.
