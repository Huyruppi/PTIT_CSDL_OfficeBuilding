# Phần 4 Vũ Trung Hiếu theo bản 18 bảng mới

<!-- TV6 sửa: nguồn chuẩn đã chuyển sang TV3 hiện hành; bằng chứng SQL xem bộ test tích hợp của web. -->
Đã thống nhất theo `Phần của thành viên 3/BCNF_BanGiao/01_CreateSchema.sql` và seed hiện hành. Bộ test `test/transactions-sql.test.js` đã chạy trên CSDL SQL Server tạm; runner `ChayKiemThu.ps1` vẫn cần chạy riêng nếu muốn lưu log bàn giao của TV4.

## Những điểm đã sửa

- Bỏ 00_BoSung_DeXuat.sql và cả 5 bảng bổ sung. Không dùng TV4_KyKeToan hay bảng hợp đồng gộp.
- T1 nhận TT_DanhSachPhong chỉ có MaVanPhong; sinh mã 20 ký tự riêng cho mỗi dòng thuê và INSERT trực tiếp vào HopDongThue. Đây là một giao dịch thuê nhiều phòng, không lưu một hợp đồng cha chung.
- MaHoaDon dùng INT. MaChiTiet, MaSuDung vẫn BIGINT như DDL; không đổi nhầm các khóa khác.
- ChiTietHoaDon không còn cột SoTien, kể cả computed; tổng tiền đọc dbo.V_ChiTietHoaDon. INSERT chỉ ghi 7 trường đầu vào.
- Dùng NGUONG_NGUOI, BUOC_NGUOI, NGUONG_DIEN_TICH, BUOC_DIEN_TICH, TY_LE_TANG_GIA. Cách tính phí và lương theo seed mới.
- Nhận biết kỳ đã lập bằng HoaDonThang; không tạo thêm bảng chốt kỳ. Không ghi đè hóa đơn/lương tháng 8–9 có sẵn.

## Trạng thái quan trọng của mục 4.4

<!-- TV6 sửa: TV3 đã có cột trạng thái/ngày/người thu; chỉ sổ quỹ độc lập là không có. -->
18 bảng TV3 đã có `HoaDonThang.TrangThai`, `NgayThanhToan`, `NguoiThu`; tổng tiền thu suy ra từ `V_ChiTietHoaDon`. Không có bảng phiếu thu/sổ quỹ hoặc cột lưu khoản thu riêng.

`USP_Trx_ThanhToanHoaDonVaVaoSoQuy` giữ tên cũ để tương thích nhưng thực hiện thanh toán **đủ một lần** trong transaction, cập nhật ba cột của hóa đơn và chặn sai tiền/trả trùng. Mã `51400` chỉ còn dùng để nhận biết bản procedure cũ chưa nâng cấp. `MaYeuCau` là tham số tương thích, không được lưu; không hứa idempotency.

Quy ước chung đã chốt tại [tài liệu 18 bảng](../docs/quy-uoc-chung-18-bang.md): không thêm bảng; không ghi khoản thu vào `ChiPhiVanHanh`, không hỗ trợ phiếu thu, trả góp hoặc hoàn tiền.

## Chạy thử tự động trên CSDL mới

Giải nén ZIP. Mở PowerShell tại thư mục đã giải nén:

`./ChayKiemThu.ps1 -Server '.\SQLEXPRESS' -DongThoi`

Cần sqlcmd và quyền tạo database với xác thực Windows. Script từ chối tên CSDL đã tồn tại; đổi -Database thành QLToaNha_TV4_Test_18Bang2 khi muốn chạy lại. Không DROP, không phục hồi đè, không xóa database của nhóm. Script có sử dụng -C như ví dụ TV3 cho kết nối thử nghiệm.

<!-- TV6 sửa: runner dùng TV3 hiện hành và cài TV5 trước TV4. -->
Thứ tự tự động: DDL, seed, Validate từ `Phần của thành viên 3/BCNF_BanGiao` → trigger TV5 → 02_KiemTraTuongThich.sql → 00_TaoKieuDuLieu.sql → 03_Transactions.sql → 04_KiemThu.sql → 06_DoiChieuSeed.sql → tùy chọn hai kết nối thuê cùng phòng. `NguonTV3` là bản sao lịch sử, không phải nguồn chuẩn.

00 chỉ tạo hai user-defined table types để truyền danh sách; chúng không phải bảng nghiệp vụ và không làm tăng sys.tables. Không tự xóa hoặc thay các type có cùng tên; cần đối chiếu nếu đã có phiên bản khác.

## Chạy bằng SSMS

Dùng database thử nghiệm mới riêng. Khi tự chạy các file TV3, đổi tên CSDL nhất quán trên bản sao script hoặc dùng một instance thử nghiệm riêng; không bấm Execute DDL/seed trên CSDL nhóm đã có dữ liệu. Chọn đúng database trước khi chạy các file phần 4. Dừng ngay khi có batch lỗi.

Nếu dùng database cũ, migration 05 của Lan Anh chỉ được dùng theo hướng dẫn của Lan Anh và sau sao lưu. Bản cũ có thêm bảng TV4 có thể làm migration từ chối; không tự xóa bảng hoặc ép migration. Cách đơn giản để kiểm thử là tạo CSDL mới bằng runner.

## Kịch bản và kết quả kỳ vọng

File 04 dùng tòa ZH_TN, công ty và nhân viên ZH_ riêng, không sửa nguồn seed. T1 có lỗi chủ động 59099 sau INSERT để kiểm tra rollback; T2 kiểm tra lô sai và lô trùng; T3 lập hóa đơn hai tháng và chặn lập lại; T4 kiểm tra sai tiền, thanh toán đủ và chặn trả trùng; T5 tính lương và chặn tính lại.

Mỗi tháng test: 22.000.000 tiền thuê + 1.050.000 phí tháng + 125.000 lượt = 23.175.000. Thưởng nhân viên vệ sinh 52.500, nhân viên ăn uống 5.000, quản lý 0. Giữ nguyên 7.320 log, 725.400.000 hóa đơn và 208.137.000 lương của seed.

Chế độ -DongThoi tạo phòng test ZH_P3 và trigger tạm chờ 3 giây, chạy hai kết nối T1 cùng thuê phòng tháng 1/2040; yêu cầu đúng một OK và một lỗi trùng. Trigger test được gỡ trong finally. Các giá trị số của runner là kỳ vọng cho bộ dữ liệu ZH_; log thực tế của runner chỉ được tạo sau khi chạy script. Bộ test web riêng đã kiểm tra thanh toán đồng thời trên CSDL tạm.

## Giới hạn phối hợp

Phát hành hóa đơn được xem là chốt kỳ qua sự tồn tại HoaDonThang. T1/T2 tự chặn ghi vào kỳ đó; các đường CRUD khác vẫn cần quyền ghi và trigger của TV5 bảo vệ. Chưa có lịch sử giá, điều chỉnh hóa đơn, hoàn tiền hay lương theo ngày công. T5 dùng HeSoDoanhThu như tỷ lệ riêng từng người, không chia quỹ theo trọng số; quản lý không có thưởng theo seed.

<!-- TV6 sửa: trạng thái sau thống nhất 18 bảng; không tuyên bố đã kiểm thử khi chưa có log chạy mới. -->
Cả năm procedure TV4 hiện có mã nghiệp vụ để chạy thử, trong đó 4.4 chỉ là thanh toán trên hóa đơn, không phải sổ quỹ độc lập. Kết quả chạy SQL mới phải xem log thực tế của runner; không suy diễn từ log cũ.
