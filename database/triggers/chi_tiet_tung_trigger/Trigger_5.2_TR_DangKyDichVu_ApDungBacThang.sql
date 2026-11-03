USE QLToaNha_BCNF;
GO
SET NOCOUNT ON;
GO

/* ============================================================================
   TRIGGER 5.2: TR_DangKyDichVu_ApDungBacThang
   Thành viên 5: Khúc Tuấn Anh (CHHT001)
   Bảng:        SuDungDichVu
   Sự kiện:     AFTER INSERT
   Mục đích:    Khi đăng ký dịch vụ hằng tháng:
                (a) Kiểm tra công ty có hợp đồng thuê tại cùng tòa nhà
                (b) Tính và hiển thị bậc giá lũy tiến hiện tại
   Công thức:   DonGiaCoBan * (1 + TY_LE_TANG_GIA * (bac_nguoi + bac_dien_tich))
   Mã lỗi:      55201
   ============================================================================ */
CREATE OR ALTER TRIGGER dbo.TR_DangKyDichVu_ApDungBacThang
ON dbo.SuDungDichVu
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;

    /* --- (a) Validate: chi dich vu THANG moi can kiem tra bac gia --- */
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN dbo.DichVu d ON d.MaDichVu = i.MaDichVu
        JOIN dbo.LoaiDichVu l ON l.MaLoaiDV = d.MaLoaiDV
        WHERE l.KieuTinhPhi = 'THANG'
          AND NOT EXISTS (
              SELECT 1 FROM dbo.HopDongThue h
              JOIN dbo.VanPhong v ON v.MaVanPhong = h.MaVanPhong
              WHERE h.MaCongTy = i.MaCongTy
                AND v.MaToaNha = d.MaToaNha
                AND h.NgayBatDau <= ISNULL(i.NgayKetThuc, CONVERT(date,'99991231'))
                AND ISNULL(h.NgayKetThuc, CONVERT(date,'99991231')) >= i.NgayBatDau
          )
    )
    BEGIN
        ;THROW 55201, N'[TV5-5.2] Cong ty chua co hop dong thue hoat dong tai toa nha cung cap dich vu. Khong the dang ky dich vu hang thang.', 1;
    END;

    /* --- (b) Tinh bac gia luy tien va thong bao --- */
    DECLARE @NguongNguoi  decimal(18,6), @BuocNguoi  decimal(18,6),
            @NguongDT     decimal(18,6), @BuocDT     decimal(18,6),
            @TyLe         decimal(18,6);

    SET ANSI_WARNINGS OFF;
    SELECT @NguongNguoi = MAX(CASE WHEN TenThamSo='NGUONG_NGUOI'      THEN GiaTri END),
           @BuocNguoi   = MAX(CASE WHEN TenThamSo='BUOC_NGUOI'        THEN GiaTri END),
           @NguongDT    = MAX(CASE WHEN TenThamSo='NGUONG_DIEN_TICH'  THEN GiaTri END),
           @BuocDT      = MAX(CASE WHEN TenThamSo='BUOC_DIEN_TICH'   THEN GiaTri END),
           @TyLe        = MAX(CASE WHEN TenThamSo='TY_LE_TANG_GIA'   THEN GiaTri END)
    FROM dbo.ThamSo
    WHERE TenThamSo IN ('NGUONG_NGUOI','BUOC_NGUOI',
                         'NGUONG_DIEN_TICH','BUOC_DIEN_TICH','TY_LE_TANG_GIA');
    SET ANSI_WARNINGS ON;

    /* Hien thi bac gia cho tung dong dang ky moi */
    DECLARE @Msg nvarchar(max) = N'';

    SELECT @Msg = @Msg
        + N'  DV=' + i.MaDichVu + N' | CT=' + i.MaCongTy
        + N' | SoNguoi=' + CAST(ng.SoNguoi AS varchar)
        + N' | DienTich=' + CAST(ISNULL(dt.DienTich,0) AS varchar)
        + N' | BacNguoi=' + CAST(
            CASE WHEN l.CoTinhTheoNguoi=1 AND ng.SoNguoi > @NguongNguoi
                 THEN CEILING((ng.SoNguoi - @NguongNguoi) / @BuocNguoi)
                 ELSE 0 END AS varchar)
        + N' | BacDT=' + CAST(
            CASE WHEN l.CoTinhTheoDienTich=1 AND ISNULL(dt.DienTich,0) > @NguongDT
                 THEN CEILING((ISNULL(dt.DienTich,0) - @NguongDT) / @BuocDT)
                 ELSE 0 END AS varchar)
        + N' | DonGiaApDung=' + CAST(
            CAST(ROUND(d.DonGiaCoBan * (1 + @TyLe * (
                CASE WHEN l.CoTinhTheoNguoi=1 AND ng.SoNguoi > @NguongNguoi
                     THEN CEILING((ng.SoNguoi - @NguongNguoi) / @BuocNguoi)
                     ELSE 0 END
              + CASE WHEN l.CoTinhTheoDienTich=1 AND ISNULL(dt.DienTich,0) > @NguongDT
                     THEN CEILING((ISNULL(dt.DienTich,0) - @NguongDT) / @BuocDT)
                     ELSE 0 END
            )), 2) AS decimal(18,2)) AS varchar)
        + CHAR(13) + CHAR(10)
    FROM inserted i
    JOIN dbo.DichVu d ON d.MaDichVu = i.MaDichVu
    JOIN dbo.LoaiDichVu l ON l.MaLoaiDV = d.MaLoaiDV
    CROSS APPLY (
        SELECT COUNT(*) AS SoNguoi
        FROM dbo.NhanVienCongTy nv
        WHERE nv.MaCongTy = i.MaCongTy
          AND nv.NgayVaoLam <= i.NgayBatDau
          AND ISNULL(nv.NgayNghiViec, CONVERT(date,'99991231')) >= i.NgayBatDau
    ) ng
    OUTER APPLY (
        SELECT CAST(SUM(v.DienTich) AS decimal(18,2)) AS DienTich
        FROM dbo.HopDongThue h
        JOIN dbo.VanPhong v ON v.MaVanPhong = h.MaVanPhong
        WHERE h.MaCongTy = i.MaCongTy
          AND v.MaToaNha = d.MaToaNha
          AND h.NgayBatDau <= i.NgayBatDau
          AND ISNULL(h.NgayKetThuc, CONVERT(date,'99991231')) >= i.NgayBatDau
    ) dt
    WHERE l.KieuTinhPhi = 'THANG';

    IF @Msg <> N''
        PRINT N'[TV5-5.2] Bac gia luy tien hien tai (SUM bac nguoi + bac DT):' + CHAR(13) + CHAR(10) + @Msg;
END;
GO

PRINT N'[TV5] Da tao Trigger 5.2 TR_DangKyDichVu_ApDungBacThang thanh cong!';
GO
