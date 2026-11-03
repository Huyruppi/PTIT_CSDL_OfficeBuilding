USE QLToaNha_BCNF;
GO
SET NOCOUNT ON;
GO

/* ============================================================================
   TRIGGER 5.4: TR_CongTy_ChanXoa & TR_ToaNha_ChanXoa
   Thành viên 5: Khúc Tuấn Anh (CHHT001)
   Bảng:        CongTy, ToaNha
   Sự kiện:     INSTEAD OF DELETE
   Mục đích:    Khóa an toàn — không cho xóa CongTy/ToaNha khi còn dữ liệu phụ thuộc.
   Mã lỗi:      55401, 55402
   ============================================================================ */

/* --- 5.4a: Bảng CongTy --- */
CREATE OR ALTER TRIGGER dbo.TR_CongTy_ChanXoa
ON dbo.CongTy
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM deleted) RETURN;

    /* Kiem tra toan bo FK tham chieu den CongTy */
    DECLARE @CongTyPhuThuoc nvarchar(max) = N'';

    SELECT @CongTyPhuThuoc = @CongTyPhuThuoc + d.MaCongTy + N', '
    FROM deleted d
    WHERE EXISTS (SELECT 1 FROM dbo.HopDongThue h WHERE h.MaCongTy = d.MaCongTy)
       OR EXISTS (SELECT 1 FROM dbo.NhanVienCongTy nv WHERE nv.MaCongTy = d.MaCongTy)
       OR EXISTS (SELECT 1 FROM dbo.SuDungDichVu s WHERE s.MaCongTy = d.MaCongTy)
       OR EXISTS (SELECT 1 FROM dbo.HoaDonThang hd WHERE hd.MaCongTy = d.MaCongTy);

    IF @CongTyPhuThuoc <> N''
    BEGIN
        SET @CongTyPhuThuoc = LEFT(@CongTyPhuThuoc, LEN(@CongTyPhuThuoc) - 1);
        DECLARE @Msg54a nvarchar(400) = N'[TV5-5.4] Khong the xoa CongTy (' + @CongTyPhuThuoc + N'): con du lieu phu thuoc (HopDongThue, NhanVienCongTy, SuDungDichVu, HoaDonThang).';
        ;THROW 55401, @Msg54a, 1;
    END;

    /* Khong co phu thuoc — cho phep xoa */
    DELETE ct
    FROM dbo.CongTy ct
    JOIN deleted d ON ct.MaCongTy = d.MaCongTy;

    PRINT N'[TV5-5.4] Da xoa cong ty khong con phu thuoc.';
END;
GO

/* --- 5.4b: Bảng ToaNha --- */
CREATE OR ALTER TRIGGER dbo.TR_ToaNha_ChanXoa
ON dbo.ToaNha
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM deleted) RETURN;

    DECLARE @ToaNhaPhuThuoc nvarchar(max) = N'';

    SELECT @ToaNhaPhuThuoc = @ToaNhaPhuThuoc + d.MaToaNha + N', '
    FROM deleted d
    WHERE EXISTS (SELECT 1 FROM dbo.VanPhong v WHERE v.MaToaNha = d.MaToaNha)
       OR EXISTS (SELECT 1 FROM dbo.DichVu dv WHERE dv.MaToaNha = d.MaToaNha)
       OR EXISTS (SELECT 1 FROM dbo.NhanVienToaNha n WHERE n.MaToaNha = d.MaToaNha)
       OR EXISTS (SELECT 1 FROM dbo.HoaDonThang hd WHERE hd.MaToaNha = d.MaToaNha)
       OR EXISTS (SELECT 1 FROM dbo.ChiPhiVanHanh cp WHERE cp.MaToaNha = d.MaToaNha);

    IF @ToaNhaPhuThuoc <> N''
    BEGIN
        SET @ToaNhaPhuThuoc = LEFT(@ToaNhaPhuThuoc, LEN(@ToaNhaPhuThuoc) - 1);
        DECLARE @Msg54b nvarchar(400) = N'[TV5-5.4] Khong the xoa ToaNha (' + @ToaNhaPhuThuoc + N'): con du lieu phu thuoc (VanPhong, DichVu, NhanVienToaNha, HoaDonThang, ChiPhiVanHanh).';
        ;THROW 55402, @Msg54b, 1;
    END;

    DELETE tn
    FROM dbo.ToaNha tn
    JOIN deleted d ON tn.MaToaNha = d.MaToaNha;

    PRINT N'[TV5-5.4] Da xoa toa nha khong con phu thuoc.';
END;
GO

PRINT N'[TV5] Da tao Trigger 5.4 TR_CongTy_ChanXoa + TR_ToaNha_ChanXoa thanh cong!';
GO
