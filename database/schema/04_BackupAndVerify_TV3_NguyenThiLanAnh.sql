USE master;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_ID(N'QLToaNha_BCNF') IS NULL
    THROW 51200, N'Chua co database QLToaNha_BCNF.', 1;
IF (SELECT COUNT_BIG(*) FROM QLToaNha_BCNF.dbo.ChiTietSuDungNV) <> 7320
    THROW 51201, N'Du lieu seed chua du 7.320 log.', 1;
DECLARE @BackupDirectory nvarchar(260) = N'E:\Copilot\CSDL\BCNF_BanGiao',
    @DataDirectory nvarchar(260) = CONVERT(nvarchar(260), SERVERPROPERTY('InstanceDefaultDataPath')),
    @LogDirectory nvarchar(260) = CONVERT(nvarchar(260), SERVERPROPERTY('InstanceDefaultLogPath')),
    @BackupFile nvarchar(4000), @DataFile nvarchar(4000), @LogFile nvarchar(4000),
    @DataLogical sysname, @LogLogical sysname, @Sql nvarchar(max),
    @RunID varchar(32) = REPLACE(CONVERT(varchar(36), NEWID()), '-', ''),
    @RestoreDatabase sysname;

SET @RestoreDatabase = CONCAT(N'QLToaNha_BCNF_RestoreCheck_', @RunID);

IF @BackupDirectory IS NULL OR @DataDirectory IS NULL OR @LogDirectory IS NULL
    THROW 51203, N'Khong doc duoc thu muc SQL Server. Can cau hinh duong dan tren server.', 1;

SET @BackupFile = @BackupDirectory + CASE WHEN RIGHT(@BackupDirectory, 1) IN ('\','/') THEN '' ELSE '\' END
    + N'QLToaNha_BCNF_Seed_202608_202609_Updated_' + CONVERT(char(8), GETDATE(), 112)
    + N'_' + @RunID + N'.bak';
SET @DataFile = @DataDirectory + CASE WHEN RIGHT(@DataDirectory, 1) IN ('\','/') THEN '' ELSE '\' END
    + N'QLToaNha_BCNF_RestoreCheck_' + @RunID + N'.mdf';
SET @LogFile = @LogDirectory + CASE WHEN RIGHT(@LogDirectory, 1) IN ('\','/') THEN '' ELSE '\' END
    + N'QLToaNha_BCNF_RestoreCheck_' + @RunID + N'.ldf';

BACKUP DATABASE QLToaNha_BCNF TO DISK = @BackupFile
WITH COPY_ONLY, CHECKSUM, NOFORMAT, NOINIT, STATS = 10,
    NAME = N'BCNF 18 tables - seed August September 2026';

RESTORE VERIFYONLY FROM DISK = @BackupFile WITH CHECKSUM;

SELECT @DataLogical = name FROM sys.master_files WHERE database_id = DB_ID(N'QLToaNha_BCNF') AND type = 0;
SELECT @LogLogical = name FROM sys.master_files WHERE database_id = DB_ID(N'QLToaNha_BCNF') AND type = 1;

SET @Sql = N'RESTORE DATABASE ' + QUOTENAME(@RestoreDatabase) + N' FROM DISK = @Source
    WITH MOVE @DataName TO @DataTarget, MOVE @LogName TO @LogTarget, RECOVERY, CHECKSUM;';
EXEC sys.sp_executesql @Sql,
    N'@Source nvarchar(4000), @DataName sysname, @DataTarget nvarchar(4000), @LogName sysname, @LogTarget nvarchar(4000)',
    @Source = @BackupFile, @DataName = @DataLogical, @DataTarget = @DataFile,
    @LogName = @LogLogical, @LogTarget = @LogFile;

DBCC CHECKDB(@RestoreDatabase) WITH NO_INFOMSGS;

SET @Sql = N'IF (SELECT COUNT_BIG(*) FROM ' + QUOTENAME(@RestoreDatabase)
    + N'.dbo.ChiTietSuDungNV) <> 7320 OR (SELECT COUNT(*) FROM '
    + QUOTENAME(@RestoreDatabase) + N'.sys.foreign_keys) <> 23
    THROW 51204, N''Database phuc hoi khong du log hoac FK.'', 1;';
EXEC sys.sp_executesql @Sql;

SET @Sql = N'USE ' + QUOTENAME(@RestoreDatabase) + N';
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N''dbo.HoaDonThang'')
        AND name = N''TrangThai'' AND system_type_id = TYPE_ID(N''varchar'') AND max_length = 20 AND is_nullable = 0)
        OR NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N''dbo.HoaDonThang'')
        AND name = N''NgayThanhToan'' AND system_type_id = TYPE_ID(N''date'') AND is_nullable = 1)
        OR NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N''dbo.HoaDonThang'')
        AND name = N''NguoiThu'' AND system_type_id = TYPE_ID(N''nvarchar'') AND max_length = 200 AND is_nullable = 1)
        OR NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE parent_object_id = OBJECT_ID(N''dbo.HoaDonThang'')
        AND name = N''DF_HoaDon_TrangThai'' AND definition = ''(''''CHUA_THANH_TOAN'''')'')
        OR NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID(N''dbo.HoaDonThang'')
        AND name = N''CK_HoaDonThang_ThanhToan'' AND is_disabled = 0 AND is_not_trusted = 0)
        THROW 51205, N''Ban restore thieu/sai schema thanh toan.'', 1;
    IF EXISTS (SELECT MaHoaDon, TrangThai, NgayThanhToan, NguoiThu FROM dbo.HoaDonThang
        EXCEPT SELECT MaHoaDon, TrangThai, NgayThanhToan, NguoiThu FROM QLToaNha_BCNF.dbo.HoaDonThang)
        OR EXISTS (SELECT MaHoaDon, TrangThai, NgayThanhToan, NguoiThu FROM QLToaNha_BCNF.dbo.HoaDonThang
        EXCEPT SELECT MaHoaDon, TrangThai, NgayThanhToan, NguoiThu FROM dbo.HoaDonThang)
        THROW 51206, N''Du lieu thanh toan ban restore khac nguon.'', 1;
    PRINT N''PASS: restored TrangThai/NgayThanhToan/NguoiThu, DEFAULT, trusted CHECK, payment data equality'';';
EXEC sys.sp_executesql @Sql;

SELECT N'PASS: backup checksum, VERIFYONLY, restore, CHECKDB, 7320 logs, 23 FK, payment schema/data' AS KetQua,
    @BackupFile AS BackupFile,
    @RestoreDatabase AS RestoreDatabase,
    CONVERT(nvarchar(128), SERVERPROPERTY('ProductVersion')) AS SQLServerVersion;
GO