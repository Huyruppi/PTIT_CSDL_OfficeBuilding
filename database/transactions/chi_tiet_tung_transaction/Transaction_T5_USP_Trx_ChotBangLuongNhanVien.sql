USE QLToaNha_BCNF;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ============================================================================
   TRANSACTION T5: USP_Trx_ChotBangLuongNhanVien
   Thành viên 4: Vũ Trung Hiếu (CHHT035)
   Mục đích:    Chốt bảng lương nhân viên tòa nhà cuối tháng.
                - Điều kiện: Tất cả công ty thuê đã được chốt hóa đơn tháng.
                - Kiểm tra mỗi tòa nhà có đúng 1 quản lý và tất cả nhân viên được phân công.
                - Tiền thưởng tính theo tỷ lệ doanh thu dịch vụ phụ trách (đối với nhân viên dịch vụ).
                - Ghi nhận vào bảng LuongThang.
   Mức cô lập:  SERIALIZABLE + sp_getapplock Exclusive
   Tham số:
     - @MaToaNha: varchar(20)
     - @Thang: tinyint (1 - 12)
     - @Nam: smallint
   ============================================================================ */
CREATE OR ALTER PROCEDURE dbo.USP_Trx_ChotBangLuongNhanVien
 @MaToaNha varchar(20),@Thang tinyint,@Nam smallint
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
  IF @Thang IS NULL OR @Thang NOT BETWEEN 1 AND 12 OR @Nam IS NULL OR @Nam NOT BETWEEN 1900 AND 9999
   THROW 51501,N'Thang hoac nam khong hop le.',1;
  IF NOT EXISTS(SELECT 1 FROM dbo.HoaDonThang WITH(UPDLOCK,HOLDLOCK)
    WHERE MaToaNha=@MaToaNha AND Thang=@Thang AND Nam=@Nam)
   THROW 51502,N'Phai chot hoa don cua toa nha truoc khi tinh luong.',1;
  DECLARE @TuKy date=DATEFROMPARTS(@Nam,@Thang,1),@DenKy date=EOMONTH(DATEFROMPARTS(@Nam,@Thang,1));
  ;WITH CongTyCanHoaDon AS(
   SELECT h.MaCongTy FROM dbo.HopDongThue h JOIN dbo.VanPhong v ON v.MaVanPhong=h.MaVanPhong
    WHERE v.MaToaNha=@MaToaNha AND h.NgayBatDau<=@DenKy AND ISNULL(h.NgayKetThuc,CONVERT(date,'99991231'))>=@TuKy
   UNION
   SELECT s.MaCongTy FROM dbo.SuDungDichVu s JOIN dbo.DichVu d ON d.MaDichVu=s.MaDichVu
    WHERE d.MaToaNha=@MaToaNha AND s.NgayBatDau<=@DenKy AND ISNULL(s.NgayKetThuc,CONVERT(date,'99991231'))>=@TuKy
  )
  SELECT MaCongTy INTO #ThieuHoaDon FROM CongTyCanHoaDon c WHERE NOT EXISTS(
   SELECT 1 FROM dbo.HoaDonThang h WHERE h.MaCongTy=c.MaCongTy AND h.MaToaNha=@MaToaNha AND h.Thang=@Thang AND h.Nam=@Nam);
  IF EXISTS(SELECT 1 FROM #ThieuHoaDon) THROW 51509,N'Con cong ty chua duoc lap hoa don trong ky.',1;
  IF EXISTS(SELECT 1 FROM dbo.LuongThang l JOIN dbo.NhanVienToaNha n ON n.MaNVTN=l.MaNVTN
      WHERE n.MaToaNha=@MaToaNha AND l.Thang=@Thang AND l.Nam=@Nam)
   THROW 51503,N'Ky da co luong. Khong tinh lai hoac ghi de.',1;
  DECLARE @Cuoi date=EOMONTH(DATEFROMPARTS(@Nam,@Thang,1));
  IF EXISTS(SELECT 1 FROM dbo.NhanVienToaNha n WHERE n.MaToaNha=@MaToaNha AND n.NgayVaoLam<=@Cuoi
    AND NOT EXISTS(SELECT 1 FROM dbo.PhanCongNVTN p
      WHERE p.MaNVTN=n.MaNVTN AND p.Thang=@Thang AND p.Nam=@Nam))
   THROW 51505,N'Co nhan vien chua duoc phan cong trong thang.',1;
  IF EXISTS(SELECT 1 FROM dbo.PhanCongNVTN p JOIN dbo.NhanVienToaNha n ON n.MaNVTN=p.MaNVTN
    LEFT JOIN dbo.DichVu d ON d.MaDichVu=p.MaDichVu
    LEFT JOIN dbo.BacCongViec b ON b.MaBac=p.MaBac
    WHERE n.MaToaNha=@MaToaNha AND p.Thang=@Thang AND p.Nam=@Nam
    AND (n.NgayVaoLam>@Cuoi OR b.MaBac IS NULL OR b.HeSoDoanhThu NOT BETWEEN 0 AND 1 OR b.LuongCoBan<=0
      OR (n.LoaiNV='QUAN_LY' AND p.MaDichVu IS NOT NULL)
      OR (n.LoaiNV='DICH_VU' AND (d.MaDichVu IS NULL OR d.MaToaNha<>@MaToaNha))
      OR n.LoaiNV NOT IN ('QUAN_LY','DICH_VU')))
   THROW 51506,N'Phan cong, bac luong hoac dich vu khong hop le.',1;
  IF (SELECT COUNT(*) FROM dbo.NhanVienToaNha WHERE MaToaNha=@MaToaNha
      AND LoaiNV='QUAN_LY' AND NgayVaoLam<=@Cuoi)<>1
   THROW 51507,N'Toa nha phai co dung mot quan ly trong thang.',1;
  /* TV3: HeSoDoanhThu la TY LE RIENG tung nhan vien, khong phai trong so.
     Quan ly khong gan MaDichVu nen doanh thu 0, thuong 0 nhu seed.
     Dich vu THANG va LUOT deu lay doanh thu tu chi tiet hoa don da chot. */
  SELECT n.MaNVTN,b.LuongCoBan,b.HeSoDoanhThu,
    CONVERT(decimal(18,2),ROUND(CAST(COALESCE(dt.DoanhThu,0) AS decimal(28,2))*b.HeSoDoanhThu,2)) AS TienThuong
  INTO #NhanVien
  FROM dbo.PhanCongNVTN p JOIN dbo.NhanVienToaNha n ON n.MaNVTN=p.MaNVTN
   JOIN dbo.BacCongViec b ON b.MaBac=p.MaBac
   OUTER APPLY(SELECT SUM(c.SoTien) AS DoanhThu
    FROM dbo.HoaDonThang h JOIN dbo.V_ChiTietHoaDon c ON c.MaHoaDon=h.MaHoaDon
    WHERE h.MaToaNha=@MaToaNha AND h.Thang=@Thang AND h.Nam=@Nam
      AND c.MaDichVu=p.MaDichVu AND c.LoaiKhoan IN ('DICH_VU_THANG','DICH_VU_LUOT')) dt
   WHERE n.MaToaNha=@MaToaNha AND p.Thang=@Thang AND p.Nam=@Nam;
  IF NOT EXISTS(SELECT 1 FROM #NhanVien) THROW 51508,N'Khong co nhan vien de tinh luong.',1;
  INSERT dbo.LuongThang(MaNVTN,Thang,Nam,LuongCoBan,TienThuong)
   SELECT MaNVTN,@Thang,@Nam,LuongCoBan,TienThuong FROM #NhanVien;
  COMMIT;
  SELECT l.MaNVTN,l.Thang,l.Nam,l.LuongCoBan,l.TienThuong,l.LuongCoBan+l.TienThuong AS TongLuong
   FROM dbo.LuongThang l JOIN #NhanVien n ON n.MaNVTN=l.MaNVTN WHERE l.Thang=@Thang AND l.Nam=@Nam;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK;
  THROW;
 END CATCH;
END;
GO

PRINT N'[TV4] Da tao Transaction T5 (USP_Trx_ChotBangLuongNhanVien) thanh cong!';
GO
