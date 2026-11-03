USE QLToaNha_BCNF;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ============================================================================
   TRANSACTION T4: USP_Trx_ThanhToanHoaDonVaVaoSoQuy
   Thành viên 4: Vũ Trung Hiếu (CHHT035)
   Mục đích:    Xác nhận thanh toán hóa đơn tháng (trọn gói 1 lần).
                Kiểm tra hóa đơn tồn tại, chưa thanh toán, ngày thanh toán hợp lệ,
                số tiền khớp đúng tổng tiền hóa đơn theo V_ChiTietHoaDon.
                Cập nhật TrangThai = 'DA_THANH_TOAN', NgayThanhToan, NguoiThu.
   Mức cô lập:  SERIALIZABLE + sp_getapplock Exclusive
   Tham số:
     - @MaHoaDon: int
     - @SoTien: decimal(18,2)
     - @NgayThanhToan: date
     - @NguoiThu: nvarchar(100) (tùy chọn)
     - @MaYeuCau: uniqueidentifier (tùy chọn)
   ============================================================================ */
CREATE OR ALTER PROCEDURE dbo.USP_Trx_ThanhToanHoaDonVaVaoSoQuy
 @MaHoaDon int,
 @SoTien decimal(18,2),
 @NgayThanhToan date,
 @NguoiThu nvarchar(100) = NULL,
 @MaYeuCau uniqueidentifier = NULL
AS
BEGIN
 -- TV6 sửa: tên procedure được giữ để tương thích; chỉ ghi thanh toán đủ một lần trên HoaDonThang, không tạo sổ quỹ/phiếu thu độc lập.
 -- @MaYeuCau là tham số tương thích không lưu bền vững; không cam kết tính idempotent theo mã yêu cầu.
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

  IF @MaHoaDon IS NULL OR @SoTien IS NULL OR @SoTien<=0 OR @NgayThanhToan IS NULL
   THROW 51401,N'Ma hoa don, so tien va ngay thanh toan phai hop le va khac NULL.',1;

  IF @NguoiThu IS NOT NULL AND LEN(LTRIM(RTRIM(@NguoiThu)))=0
   THROW 51404,N'Ten nguoi thu khong duoc la chuoi rong hoac toan dau cach.',1;
  SET @NguoiThu = CASE WHEN @NguoiThu IS NULL THEN NULL ELSE LTRIM(RTRIM(@NguoiThu)) END;

  DECLARE @TrangThai varchar(20), @NgayLap date, @TongTienHoaDon decimal(18,2);
  SELECT @TrangThai=h.TrangThai, @NgayLap=h.NgayLap
  FROM dbo.HoaDonThang h WITH(UPDLOCK,HOLDLOCK)
  WHERE h.MaHoaDon=@MaHoaDon;

  IF @TrangThai IS NULL
   THROW 51402,N'Hoa don khong ton tai.',1;
  IF @TrangThai='DA_THANH_TOAN'
   THROW 51403,N'Hoa don da duoc thanh toan truoc do.',1;
  IF @NgayThanhToan<@NgayLap OR @NgayThanhToan>CONVERT(date,GETDATE())
   THROW 51405,N'Ngay thanh toan phai tu NgayLap den hien tai.',1;

  SELECT @TongTienHoaDon = SUM(c.SoTien)
  FROM dbo.V_ChiTietHoaDon c
  WHERE c.MaHoaDon=@MaHoaDon;

  IF @TongTienHoaDon IS NULL OR @TongTienHoaDon<=0 OR @SoTien<>@TongTienHoaDon
   THROW 51406,N'So tien thanh toan khong khop tong tien hoa don (chi ho tro tra du 1 lan).',1;

  UPDATE dbo.HoaDonThang
  SET TrangThai='DA_THANH_TOAN',
      NgayThanhToan=@NgayThanhToan,
      NguoiThu=@NguoiThu
  WHERE MaHoaDon=@MaHoaDon AND TrangThai='CHUA_THANH_TOAN';

  IF @@ROWCOUNT<>1
   THROW 51407,N'Khong cap nhat duoc trang thai thanh toan.',1;

  COMMIT;
  SELECT h.MaHoaDon, h.MaCongTy, h.MaToaNha, h.Thang, h.Nam,
         h.TrangThai, h.NgayThanhToan, h.NguoiThu,
         @TongTienHoaDon AS SoTienDaThu, @MaYeuCau AS MaYeuCau
  FROM dbo.HoaDonThang h
  WHERE h.MaHoaDon=@MaHoaDon;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK;
  THROW;
 END CATCH;
END;
GO

PRINT N'[TV4] Da tao Transaction T4 (USP_Trx_ThanhToanHoaDonVaVaoSoQuy) thanh cong!';
GO
