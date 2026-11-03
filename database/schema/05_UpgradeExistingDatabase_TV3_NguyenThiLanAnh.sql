USE QLToaNha_BCNF;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;

IF OBJECT_ID(N'dbo.HoaDonThang', N'U') IS NULL
    OR OBJECT_ID(N'dbo.ChiTietHoaDon', N'U') IS NULL
    OR OBJECT_ID(N'dbo.ThamSo', N'U') IS NULL
    THROW 51300, N'Khong tim thay schema BCNF can nang cap.', 1;

IF EXISTS (SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.HoaDonThang') AND name = N'MaHoaDon' AND system_type_id = TYPE_ID(N'int'))
    AND COL_LENGTH(N'dbo.ChiTietHoaDon', N'SoTien') IS NULL
    AND OBJECT_ID(N'dbo.V_ChiTietHoaDon', N'V') IS NOT NULL
BEGIN
    PRINT N'Schema da dung INT/view; tiep tuc nang cap thanh toan.';
    GOTO PaymentUpgrade;
END;

IF NOT EXISTS (SELECT 1 FROM sys.columns
        WHERE object_id = OBJECT_ID(N'dbo.HoaDonThang') AND name = N'MaHoaDon'
            AND system_type_id = TYPE_ID(N'bigint') AND is_identity = 1)
    OR NOT EXISTS (SELECT 1 FROM sys.columns
        WHERE object_id = OBJECT_ID(N'dbo.ChiTietHoaDon') AND name = N'MaHoaDon'
            AND system_type_id = TYPE_ID(N'bigint'))
    OR NOT EXISTS (SELECT 1 FROM sys.columns
        WHERE object_id = OBJECT_ID(N'dbo.ChiTietHoaDon') AND name = N'SoTien' AND is_computed = 1)
    OR (SELECT COUNT(*) FROM dbo.ThamSo WHERE TenThamSo IN
        ('SO_NGUOI_CO_BAN', 'BUOC_TANG_NGUOI', 'DIEN_TICH_CO_BAN', 'BUOC_TANG_DIEN_TICH', 'TY_LE_TANG')) <> 5
    THROW 51301, N'Schema hien tai khong phai phien ban cu duoc ho tro; khong thay doi du lieu.', 1;

IF EXISTS (SELECT 1 FROM dbo.HoaDonThang
    WHERE MaHoaDon < -2147483648 OR MaHoaDon > 2147483647)
    THROW 51302, N'MaHoaDon hien tai vuot mien int; khong the nang cap an toan.', 1;

IF EXISTS (SELECT 1 FROM sys.foreign_keys
    WHERE referenced_object_id = OBJECT_ID(N'dbo.HoaDonThang')
        AND parent_object_id <> OBJECT_ID(N'dbo.ChiTietHoaDon'))
    THROW 51303, N'Co bang khac tham chieu HoaDonThang; can mo rong migration truoc khi chay.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    SELECT MaHoaDon, MaCongTy, MaToaNha, Thang, Nam, NgayLap,
        CAST('CHUA_THANH_TOAN' AS varchar(20)) AS TrangThai,
        CAST(NULL AS date) AS NgayThanhToan, CAST(NULL AS nvarchar(100)) AS NguoiThu
    INTO #HoaDonThang_Before
    FROM dbo.HoaDonThang;

    IF COL_LENGTH(N'dbo.HoaDonThang', N'TrangThai') IS NOT NULL
        EXEC(N'UPDATE saved SET TrangThai = source.TrangThai
            FROM #HoaDonThang_Before saved JOIN dbo.HoaDonThang source ON source.MaHoaDon = saved.MaHoaDon;');
    IF COL_LENGTH(N'dbo.HoaDonThang', N'NgayThanhToan') IS NOT NULL
        EXEC(N'UPDATE saved SET NgayThanhToan = source.NgayThanhToan
            FROM #HoaDonThang_Before saved JOIN dbo.HoaDonThang source ON source.MaHoaDon = saved.MaHoaDon;');
    IF COL_LENGTH(N'dbo.HoaDonThang', N'NguoiThu') IS NOT NULL
        EXEC(N'UPDATE saved SET NguoiThu = source.NguoiThu
            FROM #HoaDonThang_Before saved JOIN dbo.HoaDonThang source ON source.MaHoaDon = saved.MaHoaDon;');

    SELECT MaChiTiet, MaHoaDon, LoaiKhoan, MaVanPhong, MaDichVu,
        SoLuong, DonGiaApDung, TyLeNgay
    INTO #ChiTietHoaDon_Before
    FROM dbo.ChiTietHoaDon;

    ALTER TABLE dbo.ThamSo DROP CONSTRAINT CK_ThamSo_SoNguoi;
    ALTER TABLE dbo.ThamSo DROP CONSTRAINT CK_ThamSo_DienTich;
    ALTER TABLE dbo.ThamSo DROP CONSTRAINT CK_ThamSo_TyLe;

    DROP TABLE dbo.ChiTietHoaDon;
    DROP TABLE dbo.HoaDonThang;

    CREATE TABLE dbo.HoaDonThang (
        MaHoaDon int IDENTITY(1,1) NOT NULL CONSTRAINT PK_HoaDonThang PRIMARY KEY,
        MaCongTy varchar(20) NOT NULL,
        MaToaNha varchar(20) NOT NULL,
        Thang tinyint NOT NULL,
        Nam smallint NOT NULL,
        NgayLap date NOT NULL CONSTRAINT DF_HoaDonThang_NgayLap DEFAULT (CONVERT(date, GETDATE())),
        TrangThai varchar(20) NOT NULL CONSTRAINT DF_HoaDon_TrangThai DEFAULT ('CHUA_THANH_TOAN'),
        NgayThanhToan date NULL,
        NguoiThu nvarchar(100) NULL,
        CONSTRAINT CK_HoaDonThang_ThanhToan CHECK (
            (TrangThai = 'CHUA_THANH_TOAN' AND NgayThanhToan IS NULL AND NguoiThu IS NULL)
            OR (TrangThai = 'DA_THANH_TOAN' AND NgayThanhToan IS NOT NULL AND NgayThanhToan >= NgayLap
                AND (NguoiThu IS NULL OR LEN(LTRIM(RTRIM(NguoiThu))) > 0))),
        CONSTRAINT FK_HoaDonThang_CongTy FOREIGN KEY (MaCongTy) REFERENCES dbo.CongTy(MaCongTy),
        CONSTRAINT FK_HoaDonThang_ToaNha FOREIGN KEY (MaToaNha) REFERENCES dbo.ToaNha(MaToaNha),
        CONSTRAINT UQ_HoaDonThang_Ky UNIQUE (MaCongTy, MaToaNha, Thang, Nam),
        CONSTRAINT CK_HoaDonThang_Thang CHECK (Thang BETWEEN 1 AND 12),
        CONSTRAINT CK_HoaDonThang_Nam CHECK (Nam BETWEEN 1900 AND 9999)
    );

    SET IDENTITY_INSERT dbo.HoaDonThang ON;
    INSERT dbo.HoaDonThang(MaHoaDon, MaCongTy, MaToaNha, Thang, Nam, NgayLap, TrangThai, NgayThanhToan, NguoiThu)
    SELECT MaHoaDon, MaCongTy, MaToaNha, Thang, Nam, NgayLap, TrangThai, NgayThanhToan, NguoiThu FROM #HoaDonThang_Before;
    SET IDENTITY_INSERT dbo.HoaDonThang OFF;

    CREATE TABLE dbo.ChiTietHoaDon (
        MaChiTiet bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_ChiTietHoaDon PRIMARY KEY,
        MaHoaDon int NOT NULL,
        LoaiKhoan varchar(20) NOT NULL,
        MaVanPhong varchar(20) NULL,
        MaDichVu varchar(20) NULL,
        SoLuong decimal(12,2) NOT NULL CONSTRAINT DF_ChiTietHoaDon_SoLuong DEFAULT (1),
        DonGiaApDung decimal(18,2) NOT NULL,
        TyLeNgay decimal(12,10) NOT NULL CONSTRAINT DF_ChiTietHoaDon_TyLe DEFAULT (1),
        CONSTRAINT FK_ChiTietHoaDon_HoaDon FOREIGN KEY (MaHoaDon) REFERENCES dbo.HoaDonThang(MaHoaDon),
        CONSTRAINT FK_ChiTietHoaDon_VanPhong FOREIGN KEY (MaVanPhong) REFERENCES dbo.VanPhong(MaVanPhong),
        CONSTRAINT FK_ChiTietHoaDon_DichVu FOREIGN KEY (MaDichVu) REFERENCES dbo.DichVu(MaDichVu),
        CONSTRAINT CK_ChiTietHoaDon_Loai CHECK (
            (LoaiKhoan = 'THUE_VAN_PHONG' AND MaVanPhong IS NOT NULL AND MaDichVu IS NULL)
            OR (LoaiKhoan IN ('DICH_VU_THANG', 'DICH_VU_LUOT') AND MaVanPhong IS NULL AND MaDichVu IS NOT NULL)),
        CONSTRAINT CK_ChiTietHoaDon_SoLuong CHECK (SoLuong > 0),
        CONSTRAINT CK_ChiTietHoaDon_DonGia CHECK (DonGiaApDung >= 0),
        CONSTRAINT CK_ChiTietHoaDon_TyLe CHECK (TyLeNgay > 0 AND TyLeNgay <= 1)
    );

    SET IDENTITY_INSERT dbo.ChiTietHoaDon ON;
    INSERT dbo.ChiTietHoaDon(MaChiTiet, MaHoaDon, LoaiKhoan, MaVanPhong, MaDichVu,
        SoLuong, DonGiaApDung, TyLeNgay)
    SELECT MaChiTiet, MaHoaDon, LoaiKhoan, MaVanPhong, MaDichVu,
        SoLuong, DonGiaApDung, TyLeNgay FROM #ChiTietHoaDon_Before;
    SET IDENTITY_INSERT dbo.ChiTietHoaDon OFF;

    CREATE INDEX IX_HoaDonThang_ToaNha_Ky ON dbo.HoaDonThang(MaToaNha, Nam, Thang);
    CREATE INDEX IX_ChiTietHoaDon_HoaDon ON dbo.ChiTietHoaDon(MaHoaDon);
    CREATE INDEX IX_ChiTietHoaDon_VanPhong ON dbo.ChiTietHoaDon(MaVanPhong);
    CREATE INDEX IX_ChiTietHoaDon_DichVu ON dbo.ChiTietHoaDon(MaDichVu);

    UPDATE dbo.ThamSo SET TenThamSo = 'NGUONG_NGUOI' WHERE TenThamSo = 'SO_NGUOI_CO_BAN';
    UPDATE dbo.ThamSo SET TenThamSo = 'BUOC_NGUOI' WHERE TenThamSo = 'BUOC_TANG_NGUOI';
    UPDATE dbo.ThamSo SET TenThamSo = 'NGUONG_DIEN_TICH' WHERE TenThamSo = 'DIEN_TICH_CO_BAN';
    UPDATE dbo.ThamSo SET TenThamSo = 'BUOC_DIEN_TICH' WHERE TenThamSo = 'BUOC_TANG_DIEN_TICH';
    UPDATE dbo.ThamSo SET TenThamSo = 'TY_LE_TANG_GIA' WHERE TenThamSo = 'TY_LE_TANG';

    ALTER TABLE dbo.ThamSo ADD
        CONSTRAINT CK_ThamSo_SoNguoi CHECK (
            TenThamSo NOT IN ('NGUONG_NGUOI', 'BUOC_NGUOI')
            OR (GiaTri > 0 AND GiaTri = FLOOR(GiaTri))),
        CONSTRAINT CK_ThamSo_DienTich CHECK (
            TenThamSo NOT IN ('NGUONG_DIEN_TICH', 'BUOC_DIEN_TICH') OR GiaTri > 0),
        CONSTRAINT CK_ThamSo_TyLe CHECK (TenThamSo <> 'TY_LE_TANG_GIA' OR GiaTri <= 1);

    EXEC sys.sp_executesql N'
        CREATE VIEW dbo.V_ChiTietHoaDon
        AS
        SELECT MaChiTiet, MaHoaDon, LoaiKhoan, MaVanPhong, MaDichVu,
            SoLuong, DonGiaApDung, TyLeNgay,
            ROUND(SoLuong * DonGiaApDung * TyLeNgay, 2) AS SoTien
        FROM dbo.ChiTietHoaDon;';

    IF (SELECT COUNT(*) FROM dbo.HoaDonThang) <> (SELECT COUNT(*) FROM #HoaDonThang_Before)
        OR (SELECT COUNT(*) FROM dbo.ChiTietHoaDon) <> (SELECT COUNT(*) FROM #ChiTietHoaDon_Before)
        THROW 51304, N'So dong hoa don thay doi trong qua trinh nang cap.', 1;

    COMMIT TRANSACTION;
    PRINT N'PASS: preserved invoice rows, migrated MaHoaDon to int, renamed parameters, created V_ChiTietHoaDon.';
END TRY
BEGIN CATCH
    IF OBJECT_ID(N'dbo.ChiTietHoaDon', N'U') IS NOT NULL AND EXISTS
        (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.ChiTietHoaDon')
            AND name = N'MaChiTiet' AND is_identity = 1)
    BEGIN TRY
        SET IDENTITY_INSERT dbo.ChiTietHoaDon OFF;
    END TRY
    BEGIN CATCH
    END CATCH;
    IF OBJECT_ID(N'dbo.HoaDonThang', N'U') IS NOT NULL AND EXISTS
        (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.HoaDonThang')
            AND name = N'MaHoaDon' AND is_identity = 1)
    BEGIN TRY
        SET IDENTITY_INSERT dbo.HoaDonThang OFF;
    END TRY
    BEGIN CATCH
    END CATCH;
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

PaymentUpgrade:
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @PaymentRowsBefore bigint = (SELECT COUNT_BIG(*) FROM dbo.HoaDonThang);
    IF COL_LENGTH(N'dbo.HoaDonThang', N'TrangThai') IS NULL
        EXEC(N'ALTER TABLE dbo.HoaDonThang ADD TrangThai varchar(20) NOT NULL
            CONSTRAINT DF_HoaDon_TrangThai DEFAULT (''CHUA_THANH_TOAN'');');
    IF COL_LENGTH(N'dbo.HoaDonThang', N'NgayThanhToan') IS NULL
        EXEC(N'ALTER TABLE dbo.HoaDonThang ADD NgayThanhToan date NULL;');
    IF COL_LENGTH(N'dbo.HoaDonThang', N'NguoiThu') IS NULL
        EXEC(N'ALTER TABLE dbo.HoaDonThang ADD NguoiThu nvarchar(100) NULL;');
    IF NOT EXISTS (SELECT 1 FROM sys.check_constraints
        WHERE parent_object_id = OBJECT_ID(N'dbo.HoaDonThang') AND name = N'CK_HoaDonThang_ThanhToan')
        EXEC(N'ALTER TABLE dbo.HoaDonThang WITH CHECK ADD CONSTRAINT CK_HoaDonThang_ThanhToan CHECK (
            (TrangThai = ''CHUA_THANH_TOAN'' AND NgayThanhToan IS NULL AND NguoiThu IS NULL)
            OR (TrangThai = ''DA_THANH_TOAN'' AND NgayThanhToan IS NOT NULL AND NgayThanhToan >= NgayLap
                AND (NguoiThu IS NULL OR LEN(LTRIM(RTRIM(NguoiThu))) > 0)));');
    ALTER TABLE dbo.HoaDonThang WITH CHECK CHECK CONSTRAINT CK_HoaDonThang_ThanhToan;
    IF (SELECT COUNT_BIG(*) FROM dbo.HoaDonThang) <> @PaymentRowsBefore
        THROW 51305, N'So dong hoa don thay doi khi nang cap thanh toan.', 1;
    COMMIT TRANSACTION;
    PRINT N'PASS: payment columns and trusted CHECK installed; invoice rows preserved.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
