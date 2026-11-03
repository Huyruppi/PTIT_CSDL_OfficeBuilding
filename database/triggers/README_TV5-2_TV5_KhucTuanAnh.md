# Phần 5 — Trigger (TV5: Khúc Tuấn Anh, CHHT001)

## Tổng quan

6 trigger trên schema QLToaNha_BCNF (18 bảng), phối hợp với TV3 (DDL) và TV4 (Transactions).

## Danh sách file

| File | Nội dung |
|------|----------|
| `05_Phan5_Triggers.sql` | ALTER TABLE bổ sung + 6 trigger |
| `05_Phan5_KiemThu.sql` | Script kiểm thử 15 test cases |
| `04_Triggers.sql` | Bản sao `05_Phan5_Triggers.sql` — bàn giao TV6 theo bảng phân công |
| `README_TV5.md` | File này |

## Thứ tự chạy

```
01_CreateSchema.sql        -- TV3
02_InsertSeedData.sql       -- TV3
03_Validate.sql             -- TV3
00_TaoKieuDuLieu.sql        -- TV4
03_Transactions.sql         -- TV4
05_Phan5_Triggers.sql       -- TV5 (file này)
05_Phan5_KiemThu.sql        -- TV5 test
```

## Danh sách trigger

| # | Tên trigger | Bảng | Sự kiện | Mục đích |
|---|-------------|------|---------|----------|
| 5.1 | TR_ChiTietThue_ChanTrungLap | HopDongThue | AFTER INSERT, UPDATE | Ngăn trùng lịch thuê văn phòng |
| 5.2 | TR_DangKyDichVu_ApDungBacThang | SuDungDichVu | AFTER INSERT | Kiểm tra lease + tính bậc giá lũy tiến |
| 5.3 | TR_NhatKyDichVu_KiemTraHopLe | ChiTietSuDungNV | AFTER INSERT, UPDATE | Xác thực nhật ký sử dụng DV |
| 5.4a | TR_CongTy_ChanXoa | CongTy | INSTEAD OF DELETE | Khóa an toàn xóa công ty |
| 5.4b | TR_ToaNha_ChanXoa | ToaNha | INSTEAD OF DELETE | Khóa an toàn xóa tòa nhà |
| 5.5 | TR_ChiTietThue_DongBoDienTich | HopDongThue | AFTER INSERT, UPDATE, DELETE | Đồng bộ trạng thái VP + thống kê diện tích |

## Mã lỗi bàn giao TV6

| Mã lỗi | Trigger | Ý nghĩa |
|---------|---------|---------|
| 55101 | 5.1 | Trùng lịch thuê văn phòng |
| 55201 | 5.2 | Công ty chưa có hợp đồng thuê tại tòa nhà cung cấp DV |
| 55301 | 5.3 | Công ty chưa đăng ký sử dụng dịch vụ |
| 55302 | 5.3 | Nhân viên không còn làm việc tại thời điểm sử dụng |
| 55303 | 5.3 | Ngày sử dụng lớn hơn ngày hiện tại |
| 55304 | 5.3 | Dịch vụ không phải loại tính phí theo lượt |
| 55305 | 5.3 | Công ty không có hợp đồng thuê hiệu lực tại tòa nhà cung cấp DV vào NgàySửDụng |
| 55401 | 5.4 | Không thể xóa công ty còn dữ liệu phụ thuộc |
| 55402 | 5.4 | Không thể xóa tòa nhà còn dữ liệu phụ thuộc |

## Thay đổi schema

- **ALTER TABLE VanPhong ADD TrangThai** varchar(20) NOT NULL DEFAULT 'TRONG'
  - Giá trị: `'TRONG'` (trống) hoặc `'DANG_THUE'` (đang thuê)
  - CHECK CONSTRAINT `CK_VanPhong_TrangThai` giới hạn chỉ nhận 2 giá trị trên
  - Không thêm bảng mới — vẫn giữ 18 bảng
  - ⚠️ TV3 cần sửa `03_Validate.sql` dòng 136: chỉ định tường minh danh sách cột khi INSERT VanPhong

## Ghi chú kỹ thuật

- **Công thức bậc giá (5.2)**: `DonGiaCoBan × (1 + TY_LE_TANG_GIA × (bậc_người + bậc_diện_tích))` — dùng **SUM** hai bậc (theo TV4 T3), không lấy MAX
- **Trigger 5.2**: Kiểm tra lease dựa trên kỳ đăng ký DV (`i.NgayBatDau..i.NgayKetThuc`), KHÔNG dùng `GETDATE()` để tương thích dữ liệu lịch sử
- **Trigger 5.3**: 5 điều kiện kiểm tra (a–e), bao gồm check 55305 — công ty phải có hợp đồng thuê VP hiệu lực tại tòa nhà cung cấp DV
- **Trigger 5.4**: Thông báo lỗi THROW bao gồm danh sách mã đối tượng bị vướng phụ thuộc
- **Trigger 5.5**: Dùng `SUM(CASE...ELSE 0 END)` thay `COUNT(CASE...END)` để tránh NULL warning
- **Trigger 5.1 + 5.5**: Cùng fire trên HopDongThue AFTER INSERT/UPDATE; 5.1 kiểm tra trước, nếu lỗi thì 5.5 không chạy
- **Test data**: Dùng tiền tố `ZH_` (giống TV4) để cách ly khỏi seed TV3
- **Phối hợp TV3**: Cần nhắc TV3 sửa `03_Validate.sql` dòng 136 — chỉ định tường minh cột khi INSERT VanPhong (tránh lỗi 213)
- **Mã lỗi TV4 vs TV5**: SP giao dịch TV4 trả `51xxx`; trigger TV5 trả `55xxx` khi DML trực tiếp
