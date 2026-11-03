USE QLToaNha_BCNF;
GO
SET NOCOUNT ON;
GO

/* ============================================================================
   TRIGGER 5.3: TR_NhatKyDichVu_KiemTraHopLe
   Thành viên 5: Khúc Tuấn Anh (CHHT001)
   Bảng:        ChiTietSuDungNV
   Sự kiện:     AFTER INSERT, UPDATE
   Mục đích:    Xác thực nhật ký sử dụng dịch vụ:
                (a) Nhân viên thuộc công ty có đăng ký dịch vụ đó
                (b) Nhân viên còn làm việc tại ngày sử dụng
                (c) Ngày sử dụng <= ngày hiện tại
                (d) Dịch vụ phải là loại tính phí theo LUỢT
                (e) Công ty có hợp đồng thuê tại tòa nhà cung cấp DV
   Mã lỗi:      55301, 55302, 55303, 55304, 55305
   ============================================================================ */
CREATE OR ALTER TRIGGER dbo.TR_NhatKyDichVu_KiemTraHopLe
ON dbo.ChiTietSuDungNV
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;

    /* (d) Dich vu phai la loai LUOT */
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN dbo.DichVu d ON d.MaDichVu = i.MaDichVu
        JOIN dbo.LoaiDichVu l ON l.MaLoaiDV = d.MaLoaiDV
        WHERE l.KieuTinhPhi <> 'LUOT'
    )
    BEGIN
        ;THROW 55304, N'[TV5-5.3] Chi tinh phi theo luot (LUOT) moi duoc ghi nhat ky su dung. Dich vu hang thang (THANG) khong ghi nhat ky.', 1;
    END;

    /* (c) Ngay su dung khong duoc vuot qua ngay hien tai */
    IF EXISTS (
        SELECT 1 FROM inserted
        WHERE NgaySuDung > CONVERT(date, GETDATE())
    )
    BEGIN
        ;THROW 55303, N'[TV5-5.3] Ngay su dung khong duoc lon hon ngay hien tai.', 1;
    END;

    /* (b) Nhan vien con lam viec tai thoi diem su dung */
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN dbo.NhanVienCongTy nv ON nv.MaNVCT = i.MaNVCT
        WHERE i.NgaySuDung < nv.NgayVaoLam
           OR (nv.NgayNghiViec IS NOT NULL AND i.NgaySuDung > nv.NgayNghiViec)
    )
    BEGIN
        ;THROW 55302, N'[TV5-5.3] Nhan vien khong con lam viec tai thoi diem su dung dich vu.', 1;
    END;

    /* (a) Cong ty cua nhan vien phai dang ky su dung dich vu do (SuDungDichVu) */
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN dbo.NhanVienCongTy nv ON nv.MaNVCT = i.MaNVCT
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.SuDungDichVu s
            WHERE s.MaCongTy = nv.MaCongTy
              AND s.MaDichVu = i.MaDichVu
              AND s.NgayBatDau <= i.NgaySuDung
              AND ISNULL(s.NgayKetThuc, CONVERT(date,'99991231')) >= i.NgaySuDung
        )
    )
    BEGIN
        ;THROW 55301, N'[TV5-5.3] Cong ty cua nhan vien chua dang ky su dung dich vu nay tai thoi diem ghi nhat ky.', 1;
    END;

    /* (e) Cong ty phai co hop dong thue van phong hieu luc tai toa nha cung cap DV vao NgaySuDung */
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN dbo.NhanVienCongTy nv ON nv.MaNVCT = i.MaNVCT
        JOIN dbo.DichVu d ON d.MaDichVu = i.MaDichVu
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.HopDongThue h
            JOIN dbo.VanPhong v ON v.MaVanPhong = h.MaVanPhong
            WHERE h.MaCongTy = nv.MaCongTy
              AND v.MaToaNha = d.MaToaNha
              AND h.NgayBatDau <= i.NgaySuDung
              AND (h.NgayKetThuc IS NULL OR h.NgayKetThuc >= i.NgaySuDung)
        )
    )
    BEGIN
        ;THROW 55305, N'[TV5-5.3] Cong ty khong co hop dong thue van phong hieu luc tai toa nha cung cap dich vu vao NgaySuDung.', 1;
    END;
END;
GO

PRINT N'[TV5] Da tao Trigger 5.3 TR_NhatKyDichVu_KiemTraHopLe thanh cong!';
GO
