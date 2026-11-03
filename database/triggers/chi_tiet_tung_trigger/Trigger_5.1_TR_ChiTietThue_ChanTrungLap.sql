USE QLToaNha_BCNF;
GO
SET NOCOUNT ON;
GO

/* ============================================================================
   TRIGGER 5.1: TR_ChiTietThue_ChanTrungLap
   Thành viên 5: Khúc Tuấn Anh (CHHT001)
   Bảng:        HopDongThue
   Sự kiện:     AFTER INSERT, UPDATE
   Mục đích:    Ngăn trùng lịch thuê văn phòng cùng thời kỳ.
   Mã lỗi:      55101
   ============================================================================ */
CREATE OR ALTER TRIGGER dbo.TR_ChiTietThue_ChanTrungLap
ON dbo.HopDongThue
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    /* Chỉ kiểm tra khi có dòng ảnh hưởng */
    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;

    /* Tìm các cặp hợp đồng trùng lịch trên cùng văn phòng */
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN dbo.HopDongThue h ON h.MaVanPhong = i.MaVanPhong
                               AND h.MaHopDong <> i.MaHopDong
        WHERE i.NgayBatDau <= ISNULL(h.NgayKetThuc, CONVERT(date,'99991231'))
          AND h.NgayBatDau <= ISNULL(i.NgayKetThuc, CONVERT(date,'99991231'))
    )
    BEGIN
        ;THROW 55101, N'[TV5-5.1] Trung lich thue van phong. Moi van phong chi duoc cho thue boi mot cong ty trong cung thoi ky.', 1;
    END;
END;
GO

PRINT N'[TV5] Da tao Trigger 5.1 TR_ChiTietThue_ChanTrungLap thanh cong!';
GO
