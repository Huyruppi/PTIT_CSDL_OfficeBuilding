# Ghi chú tích hợp phân tán TV7

<!-- TV6 sửa: xác định ranh giới của bản demo phân mảnh sau khi thống nhất schema 18 bảng. -->

Nguồn chuẩn để vận hành là CSDL TV3 `QLToaNha_BCNF` với 18 bảng nghiệp vụ. Ba site SQL và MongoDB TV7 là bản sao minh họa được nạp bằng script riêng, không tự đồng bộ sau khi web CRUD hoặc thực hiện giao dịch TV4. Vì vậy sai khác sau khi dữ liệu nguồn thay đổi không chứng minh web ghi sai; cần làm mới bản sao một cách có kiểm soát mới đối chiếu lại được.

Không thêm `VanPhong.TrangThai` của TV5 vào site TV7; cột này là trạng thái vận hành theo thời điểm. Các file `01`–`03` chứa `DROP DATABASE`, còn `06_MongoDB.js` xóa collection trước khi nạp. Chỉ chạy trên môi trường thử nghiệm được phép thay thế dữ liệu, không chạy trên CSDL đang dùng.

Xem [quy ước chung 18 bảng](../docs/quy-uoc-chung-18-bang.md) và [hướng dẫn web](../README.md).
