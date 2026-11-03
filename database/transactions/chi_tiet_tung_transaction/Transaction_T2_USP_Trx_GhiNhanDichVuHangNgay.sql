USE QLToaNha_BCNF;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ============================================================================
   TRANSACTION T2: USP_Trx_GhiNhanDichVuHangNgay
   Thành viên 4: Vũ Trung Hiếu (CHHT035)
   Mục đích:    Ghi nhận nhật ký sử dụng dịch vụ theo lượt của nhân viên công ty.
                Kiểm tra nhân viên, dịch vụ, đăng ký và hợp đồng thuê còn hiệu lực
                vào ngày sử dụng; chặn ghi nhận vào kỳ đã phát hành hóa đơn.
   Mức cô lập:  SERIALIZABLE + sp_getapplock Exclusive
   Tham số:
     - @DanhSach: TT_DanhSachSuDung (chứa MaNVCT, MaDichVu, NgaySuDung, SoLuot)
   ============================================================================ */
CREATE OR ALTER PROCEDURE dbo.USP_Trx_GhiNhanDichVuHangNgay
 @DanhSach dbo.TT_DanhSachSuDung READONLY
AS
BEGIN
 SET NOCOUNT ON;
 SET ANSI_PADDING ON;
 SET ANSI_WARNINGS ON;
 SET ARITHABORT ON;
 SET CONCAT_NULL_YIELDS_NULL ON;
 SET NUMERIC_ROUNDABORT OFF;
 IF @@TRANCOUNT<>0 THROW 51000,N'Hay goi thu tuc ngoai transaction cua ung dung.',1;
 SET XACT_ABORT ON;
 SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
 BEGIN TRY
  BEGIN TRANSACTION;
  DECLARE @Khoa int;
  EXEC @Khoa=sys.sp_getapplock @Resource=N'TV4_NghiepVu',
    @LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
  IF @Khoa<0 THROW 51001,N'Khong lay duoc khoa nghiep vu. Thu lai sau.',1;
  IF NOT EXISTS(SELECT 1 FROM @DanhSach)
    OR EXISTS(SELECT 1 FROM @DanhSach WHERE SoLuot<=0 OR NgaySuDung>CONVERT(date,GETDATE()))
   THROW 51201,N'Lo rong, so luot khong duong hoac ngay su dung trong tuong lai.',1;
  IF EXISTS(SELECT 1 FROM @DanhSach x
    LEFT JOIN dbo.NhanVienCongTy n ON n.MaNVCT=x.MaNVCT
    LEFT JOIN dbo.DichVu d ON d.MaDichVu=x.MaDichVu
    LEFT JOIN dbo.LoaiDichVu l ON l.MaLoaiDV=d.MaLoaiDV
    WHERE n.MaNVCT IS NULL OR d.MaDichVu IS NULL OR l.KieuTinhPhi<>'LUOT'
      OR x.NgaySuDung<n.NgayVaoLam OR x.NgaySuDung>ISNULL(n.NgayNghiViec,CONVERT(date,'99991231'))
      OR NOT EXISTS(SELECT 1 FROM dbo.SuDungDichVu s WHERE s.MaCongTy=n.MaCongTy
        AND s.MaDichVu=x.MaDichVu AND s.NgayBatDau<=x.NgaySuDung
        AND ISNULL(s.NgayKetThuc,CONVERT(date,'99991231'))>=x.NgaySuDung)
      OR NOT EXISTS(SELECT 1 FROM dbo.HopDongThue h JOIN dbo.VanPhong v
        ON v.MaVanPhong=h.MaVanPhong WHERE h.MaCongTy=n.MaCongTy AND v.MaToaNha=d.MaToaNha
        AND h.NgayBatDau<=x.NgaySuDung
        AND ISNULL(h.NgayKetThuc,CONVERT(date,'99991231'))>=x.NgaySuDung))
   THROW 51202,N'Nhan vien, dich vu, dang ky hoac hop dong khong hop le vao ngay su dung.',1;
  IF EXISTS(SELECT 1 FROM @DanhSach x JOIN dbo.DichVu d ON d.MaDichVu=x.MaDichVu
    JOIN dbo.HoaDonThang k ON k.MaToaNha=d.MaToaNha
      AND k.Thang=MONTH(x.NgaySuDung) AND k.Nam=YEAR(x.NgaySuDung))
   THROW 51203,N'Khong them nhat ky vao ky da phat hanh hoa don.',1;
  IF EXISTS(SELECT 1 FROM @DanhSach x JOIN dbo.ChiTietSuDungNV c WITH(UPDLOCK,HOLDLOCK)
    ON c.MaNVCT=x.MaNVCT AND c.MaDichVu=x.MaDichVu AND c.NgaySuDung=x.NgaySuDung)
   THROW 51204,N'Lo co nhat ky da duoc ghi nhan. Khong cong don ngam.',1;
  INSERT dbo.ChiTietSuDungNV(MaNVCT,MaDichVu,NgaySuDung,SoLuot,DonGiaApDung)
   SELECT x.MaNVCT,x.MaDichVu,x.NgaySuDung,x.SoLuot,d.DonGiaCoBan
   FROM @DanhSach x JOIN dbo.DichVu d ON d.MaDichVu=x.MaDichVu;
  DECLARE @SoDong int=@@ROWCOUNT;
  COMMIT;
  SELECT @SoDong AS SoDongDaGhi;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK;
  THROW;
 END CATCH;
END;
GO

PRINT N'[TV4] Da tao Transaction T2 (USP_Trx_GhiNhanDichVuHangNgay) thanh cong!';
GO
