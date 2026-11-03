USE QLToaNha_BCNF;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ============================================================================
   TRANSACTION T3: USP_Trx_PhatHanhHoaDonThang
   Thành viên 4: Vũ Trung Hiếu (CHHT035)
   Mục đích:    Tính toán và phát hành hóa đơn tổng hợp cuối tháng cho các công ty
                trong tòa nhà, bao gồm:
                - Tiền thuê văn phòng (theo số ngày thực tế trong tháng)
                - Dịch vụ định kỳ tháng (áp dụng hệ số lũy tiến theo số người / diện tích)
                - Dịch vụ theo lượt (tính theo đơn giá lịch sử ghi nhận)
   Mức cô lập:  SERIALIZABLE + sp_getapplock Exclusive
   Tham số:
     - @MaToaNha: varchar(20)
     - @Thang: tinyint (1 - 12)
     - @Nam: smallint
   ============================================================================ */
CREATE OR ALTER PROCEDURE dbo.USP_Trx_PhatHanhHoaDonThang
 @MaToaNha varchar(20), @Thang tinyint, @Nam smallint
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
   THROW 51301,N'Thang hoac nam khong hop le.',1;
  DECLARE @Tu date=DATEFROMPARTS(@Nam,@Thang,1),@Den date=EOMONTH(DATEFROMPARTS(@Nam,@Thang,1));
  IF @Den>=CONVERT(date,GETDATE()) THROW 51302,N'Chi chot khi thang da ket thuc.',1;
  IF NOT EXISTS(SELECT 1 FROM dbo.ToaNha WHERE MaToaNha=@MaToaNha)
   THROW 51303,N'Toa nha khong ton tai.',1;
  IF EXISTS(SELECT 1 FROM dbo.HoaDonThang WITH(UPDLOCK,HOLDLOCK)
    WHERE MaToaNha=@MaToaNha AND Thang=@Thang AND Nam=@Nam)
   THROW 51304,N'Ky da co hoa don. Khong ghi de hoac lap bo sung ngam.',1;
  DECLARE @NguongNguoi decimal(18,6),@BuocNguoi decimal(18,6),
    @NguongDT decimal(18,6),@BuocDT decimal(18,6),@TyLe decimal(18,6);
  SELECT @NguongNguoi=MAX(CASE WHEN TenThamSo='NGUONG_NGUOI' THEN GiaTri END),
    @BuocNguoi=MAX(CASE WHEN TenThamSo='BUOC_NGUOI' THEN GiaTri END),
    @NguongDT=MAX(CASE WHEN TenThamSo='NGUONG_DIEN_TICH' THEN GiaTri END),
    @BuocDT=MAX(CASE WHEN TenThamSo='BUOC_DIEN_TICH' THEN GiaTri END),
    @TyLe=MAX(CASE WHEN TenThamSo='TY_LE_TANG_GIA' THEN GiaTri END)
   FROM dbo.ThamSo;
  IF @NguongNguoi IS NULL OR @BuocNguoi IS NULL OR @NguongDT IS NULL OR @BuocDT IS NULL OR @TyLe IS NULL
    OR @NguongNguoi<1 OR @BuocNguoi<=0 OR @NguongDT<0 OR @BuocDT<=0 OR @TyLe NOT BETWEEN 0 AND 1
    OR @NguongNguoi<>FLOOR(@NguongNguoi) OR @BuocNguoi<>FLOOR(@BuocNguoi)
   THROW 51305,N'Thieu hoac sai tham so bac thang.',1;
  /* Kiem tra du lieu nguon chong lich; khong de double-count khi trigger chua co. */
  IF EXISTS(SELECT 1 FROM dbo.HopDongThue a JOIN dbo.HopDongThue b
    ON a.MaVanPhong=b.MaVanPhong AND a.MaHopDong<b.MaHopDong
    JOIN dbo.VanPhong v ON v.MaVanPhong=a.MaVanPhong
    WHERE v.MaToaNha=@MaToaNha AND a.NgayBatDau<=@Den AND b.NgayBatDau<=@Den
      AND ISNULL(a.NgayKetThuc,CONVERT(date,'99991231'))>=@Tu
      AND ISNULL(b.NgayKetThuc,CONVERT(date,'99991231'))>=@Tu
      AND a.NgayBatDau<=ISNULL(b.NgayKetThuc,CONVERT(date,'99991231'))
      AND b.NgayBatDau<=ISNULL(a.NgayKetThuc,CONVERT(date,'99991231')))
   THROW 51306,N'Du lieu nguon co hop dong chong lich.',1;
  CREATE TABLE #Ngay(Ngay date NOT NULL PRIMARY KEY);
  ;WITH n AS(SELECT @Tu AS Ngay UNION ALL SELECT DATEADD(day,1,Ngay) FROM n WHERE Ngay<@Den)
   INSERT #Ngay SELECT Ngay FROM n OPTION(MAXRECURSION 31);
  CREATE TABLE #Dong(
   MaCongTy varchar(20) NOT NULL,LoaiKhoan varchar(20) NOT NULL,
   MaVanPhong varchar(20) NULL,MaDichVu varchar(20) NULL,
   SoLuong decimal(12,2) NOT NULL,DonGiaApDung decimal(18,2) NOT NULL,
   TyLeNgay decimal(12,10) NOT NULL
  );
  /* Tien thue: moi ngay thuoc hop dong duoc tinh ca ngay dau va ngay cuoi. */
  INSERT #Dong(MaCongTy,LoaiKhoan,MaVanPhong,MaDichVu,SoLuong,DonGiaApDung,TyLeNgay)
   SELECT h.MaCongTy,'THUE_VAN_PHONG',v.MaVanPhong,NULL,v.DienTich,t.DonGiaThueM2,
    CAST(COUNT(*)*1.0/DAY(@Den) AS decimal(12,10))
   FROM dbo.HopDongThue h JOIN dbo.VanPhong v ON v.MaVanPhong=h.MaVanPhong
   JOIN dbo.ViTri t ON t.MaViTri=v.MaViTri JOIN #Ngay n ON h.NgayBatDau<=n.Ngay
     AND ISNULL(h.NgayKetThuc,CONVERT(date,'99991231'))>=n.Ngay
   WHERE v.MaToaNha=@MaToaNha
   GROUP BY h.MaCongTy,v.MaVanPhong,v.DienTich,t.DonGiaThueM2;
  /* So nguoi tinh tren cong ty; dien tich tinh rieng toa nha, theo tung ngay.
     Theo seed TV3: <=10 nguoi=0 bac, (10,15]=1 bac, (15,20]=2 bac.
     Dien tich <=100=0 bac; (100,110]=1 bac; (110,120]=2 bac.
     Cong don bac nguoi va dien tich; khong lay MAX hai bac. */
  ;WITH sd AS(
   SELECT DISTINCT s.MaCongTy,s.MaDichVu,n.Ngay
   FROM dbo.SuDungDichVu s JOIN dbo.DichVu d ON d.MaDichVu=s.MaDichVu
   JOIN dbo.LoaiDichVu l ON l.MaLoaiDV=d.MaLoaiDV
   JOIN #Ngay n ON s.NgayBatDau<=n.Ngay AND ISNULL(s.NgayKetThuc,CONVERT(date,'99991231'))>=n.Ngay
   WHERE d.MaToaNha=@MaToaNha AND l.KieuTinhPhi='THANG'
  )
  SELECT sd.MaCongTy,sd.MaDichVu,sd.Ngay,
   CAST(ROUND(CAST(d.DonGiaCoBan AS decimal(18,2))*CAST(1+@TyLe*CAST((
    CASE WHEN l.CoTinhTheoNguoi=1 AND ng.SoNguoi>@NguongNguoi
      THEN CEILING((ng.SoNguoi-@NguongNguoi)/@BuocNguoi) ELSE 0 END
    +CASE WHEN l.CoTinhTheoDienTich=1 AND dt.DienTich>@NguongDT
      THEN CEILING((dt.DienTich-@NguongDT)/@BuocDT) ELSE 0 END) AS decimal(18,2))
      AS decimal(18,6)),2) AS decimal(18,2)) AS DonGia,
   dt.DienTich
  INTO #PhiNgay FROM sd JOIN dbo.DichVu d ON d.MaDichVu=sd.MaDichVu
   JOIN dbo.LoaiDichVu l ON l.MaLoaiDV=d.MaLoaiDV
   CROSS APPLY(SELECT COUNT(*) AS SoNguoi FROM dbo.NhanVienCongTy nv
    WHERE nv.MaCongTy=sd.MaCongTy AND nv.NgayVaoLam<=sd.Ngay
      AND ISNULL(nv.NgayNghiViec,CONVERT(date,'99991231'))>=sd.Ngay) ng
   CROSS APPLY(SELECT CAST(SUM(v.DienTich) AS decimal(18,2)) AS DienTich FROM dbo.HopDongThue h
    JOIN dbo.VanPhong v ON v.MaVanPhong=h.MaVanPhong
    WHERE h.MaCongTy=sd.MaCongTy AND v.MaToaNha=@MaToaNha AND h.NgayBatDau<=sd.Ngay
      AND ISNULL(h.NgayKetThuc,CONVERT(date,'99991231'))>=sd.Ngay) dt;
  IF EXISTS(SELECT 1 FROM #PhiNgay WHERE DienTich IS NULL)
   THROW 51307,N'Dang ky dich vu thang co ngay khong co hop dong thue cung toa.',1;
  INSERT #Dong(MaCongTy,LoaiKhoan,MaVanPhong,MaDichVu,SoLuong,DonGiaApDung,TyLeNgay)
   SELECT MaCongTy,'DICH_VU_THANG',NULL,MaDichVu,1,DonGia,
    CAST(COUNT(*)*1.0/DAY(@Den) AS decimal(12,10))
   FROM #PhiNgay GROUP BY MaCongTy,MaDichVu,DonGia;
  /* Nhom theo don gia lich su; khong lay gia hien tai de tinh lai nhat ky. */
  INSERT #Dong(MaCongTy,LoaiKhoan,MaVanPhong,MaDichVu,SoLuong,DonGiaApDung,TyLeNgay)
   SELECT nv.MaCongTy,'DICH_VU_LUOT',NULL,c.MaDichVu,SUM(CONVERT(bigint,c.SoLuot)),c.DonGiaApDung,1
   FROM dbo.ChiTietSuDungNV c JOIN dbo.NhanVienCongTy nv ON nv.MaNVCT=c.MaNVCT
   JOIN dbo.DichVu d ON d.MaDichVu=c.MaDichVu
   WHERE d.MaToaNha=@MaToaNha AND c.NgaySuDung BETWEEN @Tu AND @Den
   GROUP BY nv.MaCongTy,c.MaDichVu,c.DonGiaApDung;
  IF NOT EXISTS(SELECT 1 FROM #Dong) THROW 51308,N'Ky khong co khoan thu de lap hoa don.',1;
  DECLARE @HD TABLE(MaHoaDon int NOT NULL,MaCongTy varchar(20) NOT NULL PRIMARY KEY);
  INSERT dbo.HoaDonThang(MaCongTy,MaToaNha,Thang,Nam,NgayLap)
   OUTPUT inserted.MaHoaDon,inserted.MaCongTy INTO @HD
   SELECT DISTINCT MaCongTy,@MaToaNha,@Thang,@Nam,CONVERT(date,GETDATE()) FROM #Dong;
  INSERT dbo.ChiTietHoaDon(MaHoaDon,LoaiKhoan,MaVanPhong,MaDichVu,SoLuong,DonGiaApDung,TyLeNgay)
   SELECT h.MaHoaDon,d.LoaiKhoan,d.MaVanPhong,d.MaDichVu,d.SoLuong,d.DonGiaApDung,d.TyLeNgay
   FROM #Dong d JOIN @HD h ON h.MaCongTy=d.MaCongTy;
  COMMIT;
  SELECT h.MaHoaDon,h.MaCongTy,SUM(CONVERT(decimal(18,2),ROUND(d.SoLuong*d.DonGiaApDung*d.TyLeNgay,2))) AS TongTien
   FROM @HD h JOIN #Dong d ON d.MaCongTy=h.MaCongTy GROUP BY h.MaHoaDon,h.MaCongTy;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK;
  THROW;
 END CATCH;
END;
GO

PRINT N'[TV4] Da tao Transaction T3 (USP_Trx_PhatHanhHoaDonThang) thanh cong!';
GO
