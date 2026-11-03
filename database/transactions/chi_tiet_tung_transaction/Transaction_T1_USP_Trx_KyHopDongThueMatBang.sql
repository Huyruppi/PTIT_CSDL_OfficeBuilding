USE QLToaNha_BCNF;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ============================================================================
   TRANSACTION T1: USP_Trx_KyHopDongThueMatBang
   Thành viên 4: Vũ Trung Hiếu (CHHT035)
   Mục đích:    Ký hợp đồng thuê văn phòng cho công ty theo lô phòng.
                Đảm bảo phòng thuộc đúng tòa nhà, không trùng lịch thuê,
                và không chạm vào kỳ đã phát hành hóa đơn.
   Mức cô lập:  SERIALIZABLE + sp_getapplock Exclusive
   Tham số:
     - @MaCongTy: varchar(20)
     - @MaToaNha: varchar(20)
     - @NgayBatDau: date
     - @NgayKetThuc: date (có thể NULL)
     - @DanhSachPhong: TT_DanhSachPhong (chứa danh sách MaVanPhong)
   ============================================================================ */
CREATE OR ALTER PROCEDURE dbo.USP_Trx_KyHopDongThueMatBang
 @MaCongTy varchar(20), @MaToaNha varchar(20),
 @NgayBatDau date, @NgayKetThuc date,
 @DanhSachPhong dbo.TT_DanhSachPhong READONLY
AS
BEGIN
 SET NOCOUNT ON;
 IF @@TRANCOUNT<>0 THROW 51000,N'Goi thu tuc ngoai transaction cua ung dung.',1;
 SET XACT_ABORT ON;
 SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
 BEGIN TRY
  BEGIN TRANSACTION;
  DECLARE @Khoa int;
  EXEC @Khoa=sys.sp_getapplock @Resource=N'TV4_NghiepVu',@LockMode='Exclusive',
    @LockOwner='Transaction',@LockTimeout=10000;
  IF @Khoa<0 THROW 51001,N'Khong lay duoc khoa nghiep vu.',1;
  -- TV6 sửa: giao dịch thuê chấp nhận ngày kết thúc bằng ngày bắt đầu như DDL TV3.
  IF @NgayBatDau IS NULL OR (@NgayKetThuc IS NOT NULL AND @NgayKetThuc<@NgayBatDau)
    OR NOT EXISTS(SELECT 1 FROM @DanhSachPhong)
   THROW 51101,N'Ngay thue hoac danh sach phong khong hop le.',1;
  IF NOT EXISTS(SELECT 1 FROM dbo.CongTy WHERE MaCongTy=@MaCongTy)
    OR NOT EXISTS(SELECT 1 FROM dbo.ToaNha WHERE MaToaNha=@MaToaNha)
   THROW 51102,N'Cong ty hoac toa nha khong ton tai.',1;
  IF EXISTS(SELECT 1 FROM @DanhSachPhong p LEFT JOIN dbo.VanPhong v ON v.MaVanPhong=p.MaVanPhong
    WHERE v.MaVanPhong IS NULL OR v.MaToaNha<>@MaToaNha)
   THROW 51103,N'Phong phai ton tai va thuoc dung toa nha.',1;
  IF EXISTS(SELECT 1 FROM dbo.HoaDonThang h WHERE h.MaToaNha=@MaToaNha
    AND DATEFROMPARTS(h.Nam,h.Thang,1)<=ISNULL(@NgayKetThuc,CONVERT(date,'99991231'))
    AND EOMONTH(DATEFROMPARTS(h.Nam,h.Thang,1))>=@NgayBatDau)
   THROW 51105,N'Khoang thue cham vao ky da co hoa don.',1;
  IF EXISTS(SELECT 1 FROM @DanhSachPhong p JOIN dbo.HopDongThue h WITH(UPDLOCK,HOLDLOCK)
    ON h.MaVanPhong=p.MaVanPhong
    WHERE h.NgayBatDau<=ISNULL(@NgayKetThuc,CONVERT(date,'99991231'))
    AND ISNULL(h.NgayKetThuc,CONVERT(date,'99991231'))>=@NgayBatDau)
   THROW 51106,N'Co phong trung lich thue. Huy toan bo lo.',1;
  DECLARE @Ma TABLE(MaVanPhong varchar(20) PRIMARY KEY,MaHopDong varchar(20) NOT NULL UNIQUE);
  INSERT @Ma SELECT MaVanPhong,'H'+LEFT(REPLACE(CONVERT(varchar(36),NEWID()),'-',''),19)
   FROM @DanhSachPhong;
  /* Tao ma rieng cho tung dong thue; PK van chan neu ngau nhien trung ma. */
  INSERT dbo.HopDongThue(MaHopDong,MaCongTy,MaVanPhong,NgayBatDau,NgayKetThuc)
   SELECT MaHopDong,@MaCongTy,MaVanPhong,@NgayBatDau,@NgayKetThuc FROM @Ma;
  COMMIT;
  SELECT MaHopDong,MaVanPhong FROM @Ma ORDER BY MaVanPhong;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK;
  THROW;
 END CATCH;
END;
GO

PRINT N'[TV4] Da tao Transaction T1 (USP_Trx_KyHopDongThueMatBang) thanh cong!';
GO
