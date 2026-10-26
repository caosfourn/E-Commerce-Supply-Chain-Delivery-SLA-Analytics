# Quy tắc nghiệp vụ

1. Phân tích chính theo ngày mua `[2017-01-01, 2018-09-01)`. Bỏ tháng 2018-08 trong sensitivity; 2016 chỉ làm lịch sử để chọn đơn đầu.
2. Eligible = delivered + có ngày thực giao + ngày dự kiến. Không tự loại anomaly khỏi mẫu số SLA. Ngày trễ dùng ngày lịch; giao 23:59 trong ngày hẹn vẫn đúng hạn. Ineligible có is_late NULL.
3. Duration dùng số giây / 86400; thời gian âm giữ flag và trả NULL cho duration. Mỗi chặng báo mẫu số riêng. P90 các chặng không cộng thành P90 toàn hành trình.
4. Review mới nhất: creation DESC, answer DESC, review_id DESC, score DESC, title DESC, message DESC. SQL dùng collation database; tie-break chuỗi khác collation có thể khác Python nếu xuất hiện tie. Main: điểm 1–5 và creation date >= delivery date. Review trước giao chỉ cho sensitivity. Creation date là proxy thời điểm đánh giá, không chứng minh thời điểm khách thực sự viết.
5. Items và payments tổng hợp riêng về order trước JOIN. Giá trị hàng = price của delivered; freight tách riêng; payment không phải doanh thu. Cột revenue tại item = price + freight theo yêu cầu kỹ thuật, là gross order value, không phải doanh thu nền tảng.
6. dim_customer một dòng/customer_id (địa chỉ ở đơn); customer_unique_id định danh người và có thể lặp trong dimension. Không chọn một địa chỉ tùy ý cho người mua nhiều lần.
7. Duplicate nguyên dòng bỏ ở clean; business key trùng nhưng nội dung khác làm PK lỗi để điều tra, không tự chọn dữ liệu. Stg không sửa nội dung. Geolocation lấy trung bình mọi tọa độ hợp lệ theo zip; tọa độ ngoài [-90,90]/[-180,180] không dùng. Raw vẫn giữ.
8. Category thiếu => unknown; chưa có bản dịch => giữ tên Bồ Đào Nha để tránh mất nhãn.
9. Seller: một order/seller; route: một order/seller-state/customer-state; category: một order/category. Mẫu chồng lấp. Ngưỡng 30/50/100 eligible, ưu tiên số đơn trễ giảm dần.
10. Retention: chọn đơn đầu trên toàn lịch sử (mọi status), sau đó giữ cohort có đơn đầu eligible và đủ 90 ngày trước 2018-09-01. Repeat là đơn có thời gian mua lớn hơn đơn đầu và <= 90 ngày, loại canceled/unavailable. Cùng timestamp không được coi là lần quay lại. Wilson 95%; không suy luận nhân quả.
11. Outlier flags minh bạch: delivery >60 ngày; item price >1000 BRL hoặc freight >200 BRL. Đây là ngưỡng nghiệp vụ thăm dò, không phải gian lận. Giữ dữ liệu, xuất sensitivity có/không duration outliers.
12. Không thay đổi raw hoặc tự động xóa database. SQL pipeline khởi tạo chạy trên schema đích trống; rerun analysis an toàn. Reset cần theo runbook.
