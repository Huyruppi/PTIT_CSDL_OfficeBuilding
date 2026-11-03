USE QLToaNha_BCNF;
GO
SET NOCOUNT ON;
GO

/* ============================================================================
   TRIGGER 5.5: TR_ChiTietThue_DongBoDienTich
   Thành viên 5: Khúc Tuấn Anh (CHHT001)
   Bảng:        HopDongThue
   Sự kiện:     AFTER INSERT, UPDATE, DELETE
   Mục đích:    Tự động đồng bộ:
                (a) VanPhong.TrangThai = 'DANG_THUE' nếu có hợp đồng hoạt động,
                    'TRONG' nếu không.
                (b) In thông báo tổng diện tích đang thuê theo tòa nhà
                    (phục vụ dashboard / báo cáo).
   ============================================================================ */
CREATE OR ALTER TRIGGER dbo.TR_ChiTietThue_DongBoDienTich
ON dbo.HopDongThue
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @HomNay date = CONVERT(date, GETDATE());

    /* Thu thap tat ca MaVanPhong bi anh huong (inserted + deleted) */
    DECLARE @VP TABLE (MaVanPhong varchar(20) PRIMARY KEY);

    INSERT @VP (MaVanPhong)
    SELECT MaVanPhong FROM inserted
    UNION
    SELECT MaVanPhong FROM deleted;

    IF NOT EXISTS (SELECT 1 FROM @VP) RETURN;

    /* (a) Cap nhat TrangThai cho cac van phong bi anh huong */
    UPDATE vp
    SET TrangThai = CASE
        WHEN EXISTS (
            SELECT 1 FROM dbo.HopDongThue h
            WHERE h.MaVanPhong = vp.MaVanPhong
              AND h.NgayBatDau <= @HomNay
              AND ISNULL(h.NgayKetThuc, CONVERT(date,'99991231')) >= @HomNay
        ) THEN 'DANG_THUE'
        ELSE 'TRONG'
    END
    FROM dbo.VanPhong vp
    JOIN @VP a ON a.MaVanPhong = vp.MaVanPhong;

    /* (b) Thong bao tong dien tich dang thue theo toa nha */
    DECLARE @Msg nvarchar(max) = N'';

    SELECT @Msg = @Msg
        + N'  ToaNha=' + tn.MaToaNha
        + N' | TongDienTichThue=' + CAST(ISNULL(SUM(
            CASE WHEN h.MaHopDong IS NOT NULL THEN v.DienTich ELSE 0 END
          ), 0) AS varchar)
        + N' m2 | SoVP_DangThue=' + CAST(SUM(
            CASE WHEN h.MaHopDong IS NOT NULL THEN 1 ELSE 0 END
          ) AS varchar)
        + N'/' + CAST(COUNT(*) AS varchar)
        + CHAR(13) + CHAR(10)
    FROM dbo.VanPhong v
    JOIN dbo.ToaNha tn ON tn.MaToaNha = v.MaToaNha
    LEFT JOIN dbo.HopDongThue h ON h.MaVanPhong = v.MaVanPhong
        AND h.NgayBatDau <= @HomNay
        AND ISNULL(h.NgayKetThuc, CONVERT(date,'99991231')) >= @HomNay
    WHERE v.MaToaNha IN (
        SELECT DISTINCT v2.MaToaNha
        FROM @VP a2 JOIN dbo.VanPhong v2 ON v2.MaVanPhong = a2.MaVanPhong
    )
    GROUP BY tn.MaToaNha;

    IF @Msg <> N''
        PRINT N'[TV5-5.5] Dong bo trang thai van phong. Thong ke toa nha:' + CHAR(13) + CHAR(10) + @Msg;
END;
GO

PRINT N'[TV5] Da tao Trigger 5.5 TR_ChiTietThue_DongBoDienTich thanh cong!';
GO
