param([string]$Server = '.\SQLEXPRESS')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Data
$scriptDirectory = Join-Path (Get-Location) 'CSDL/BCNF_BanGiao'
if ($PSScriptRoot) { $scriptDirectory = $PSScriptRoot }
Start-Transcript -LiteralPath (Join-Path $scriptDirectory 'Upgrade_Paths_Result.txt') -Force | Out-Null
$connection = New-Object System.Data.SqlClient.SqlConnection("Server=$Server;Database=master;Integrated Security=True;TrustServerCertificate=True")
$connection.Open()
function Invoke-TestSql([string]$Sql) {
    $command = $connection.CreateCommand()
    $command.CommandTimeout = 180
    $command.CommandText = $Sql
    try { [void]$command.ExecuteNonQuery() } finally { $command.Dispose() }
}
function Invoke-TestScript([string]$FileName, [string]$Database) {
    $sql = (Get-Content -LiteralPath (Join-Path $scriptDirectory $FileName) -Raw).Replace('QLToaNha_BCNF', $Database)
    foreach ($batch in [regex]::Split($sql, '(?im)^\s*GO\s*\r?$')) {
        if ($batch.Trim()) { Invoke-TestSql $batch }
    }
}
function Save-Invoices {
    Invoke-TestSql @'
SELECT MaHoaDon, MaCongTy, MaToaNha, Thang, Nam, NgayLap INTO #BeforeInvoices FROM dbo.HoaDonThang;
SELECT MaChiTiet, MaHoaDon, LoaiKhoan, MaVanPhong, MaDichVu, SoLuong, DonGiaApDung, TyLeNgay
INTO #BeforeDetails FROM dbo.ChiTietHoaDon;
'@
}
function Assert-Invoices {
    Invoke-TestSql @'
IF EXISTS (SELECT * FROM #BeforeInvoices EXCEPT SELECT MaHoaDon, MaCongTy, MaToaNha, Thang, Nam, NgayLap FROM dbo.HoaDonThang)
OR EXISTS (SELECT MaHoaDon, MaCongTy, MaToaNha, Thang, Nam, NgayLap FROM dbo.HoaDonThang EXCEPT SELECT * FROM #BeforeInvoices)
OR EXISTS (SELECT * FROM #BeforeDetails EXCEPT SELECT MaChiTiet, MaHoaDon, LoaiKhoan, MaVanPhong, MaDichVu, SoLuong, DonGiaApDung, TyLeNgay FROM dbo.ChiTietHoaDon)
OR EXISTS (SELECT MaChiTiet, MaHoaDon, LoaiKhoan, MaVanPhong, MaDichVu, SoLuong, DonGiaApDung, TyLeNgay FROM dbo.ChiTietHoaDon EXCEPT SELECT * FROM #BeforeDetails)
    THROW 51400, 'Invoice IDs or data changed during upgrade.', 1;
DROP TABLE #BeforeInvoices;
DROP TABLE #BeforeDetails;
'@
}
try {
    $runID = [Guid]::NewGuid().ToString('N')
    $freshDatabase = "BCNF_TestFresh_$runID"
    Invoke-TestScript '01_CreateSchema.sql' $freshDatabase
    Invoke-TestScript '02_InsertSeedData.sql' $freshDatabase
    Invoke-TestScript '03_Validate.sql' $freshDatabase
    Invoke-TestSql @'
IF (SELECT COUNT(*) FROM dbo.HoaDonThang WHERE TrangThai = 'DA_THANH_TOAN' AND NguoiThu = N'Thu ngan mau') <> 6
OR (SELECT COUNT(*) FROM dbo.HoaDonThang WHERE TrangThai = 'CHUA_THANH_TOAN' AND NgayThanhToan IS NULL AND NguoiThu IS NULL) <> 6
    THROW 51401, 'Fresh seed must include six paid and six unpaid invoices.', 1;
'@
    Save-Invoices
    Invoke-TestScript '05_UpgradeExistingDatabase.sql' $freshDatabase
    # TV6 sửa: kiểm tra migration bốn CHECK có thể chạy lặp trên database mới.
    Invoke-TestScript '06_ThongNhatQuyTac.sql' $freshDatabase
    Invoke-TestScript '06_ThongNhatQuyTac.sql' $freshDatabase
    Assert-Invoices
    Write-Output "PASS: fresh schema, 6 paid/6 unpaid seed, validation, rerun upgrade: $freshDatabase"
    Invoke-TestSql @'
ALTER TABLE dbo.HoaDonThang DROP CONSTRAINT CK_HoaDonThang_ThanhToan;
ALTER TABLE dbo.HoaDonThang DROP CONSTRAINT DF_HoaDon_TrangThai;
ALTER TABLE dbo.HoaDonThang DROP COLUMN TrangThai, NgayThanhToan, NguoiThu;
'@
    Save-Invoices
    Invoke-TestScript '05_UpgradeExistingDatabase.sql' $freshDatabase
    Invoke-TestScript '06_ThongNhatQuyTac.sql' $freshDatabase
    Assert-Invoices
    Invoke-TestScript '03_Validate.sql' $freshDatabase
    Invoke-TestSql @'
UPDATE dbo.HoaDonThang SET TrangThai = 'DA_THANH_TOAN', NgayThanhToan = NgayLap, NguoiThu = N'Preserved collector'
WHERE MaHoaDon = (SELECT MIN(MaHoaDon) FROM dbo.HoaDonThang);
SELECT MaHoaDon, TrangThai, NgayThanhToan, NguoiThu INTO #BeforePayments FROM dbo.HoaDonThang;
'@
    Invoke-TestScript '05_UpgradeExistingDatabase.sql' $freshDatabase
    Invoke-TestSql @'
IF EXISTS (SELECT * FROM #BeforePayments EXCEPT SELECT MaHoaDon, TrangThai, NgayThanhToan, NguoiThu FROM dbo.HoaDonThang)
OR EXISTS (SELECT MaHoaDon, TrangThai, NgayThanhToan, NguoiThu FROM dbo.HoaDonThang EXCEPT SELECT * FROM #BeforePayments)
    THROW 51402, 'Existing payment data changed on rerun.', 1;
DROP TABLE #BeforePayments;
'@
    Write-Output 'PASS: INT/view without payment columns upgraded; IDs/details and paid history preserved on rerun.'
    $legacyDatabase = "BCNF_TestLegacy_$runID"
    $backupPath = (Resolve-Path (Join-Path $scriptDirectory '../QLToaNha_BCNF_Seed_202608_202609.bak')).Path.Replace("'", "''")
    $command = $connection.CreateCommand()
    $command.CommandText = "RESTORE FILELISTONLY FROM DISK = N'$backupPath';"
    $files = New-Object System.Data.DataTable
    $reader = $command.ExecuteReader()
    try { $files.Load($reader) } finally { $reader.Dispose(); $command.Dispose() }
    $moves = @()
    foreach ($file in $files.Rows) {
        $logicalName = $file.LogicalName.Replace("'", "''")
        $extension = if ($file.Type -eq 'L') { 'ldf' } else { 'mdf' }
        $propertyName = if ($file.Type -eq 'L') { 'InstanceDefaultLogPath' } else { 'InstanceDefaultDataPath' }
        $command = $connection.CreateCommand()
        $command.CommandText = "SELECT CONVERT(nvarchar(260), SERVERPROPERTY('$propertyName'));"
        try { $serverDirectory = [string]$command.ExecuteScalar() } finally { $command.Dispose() }
        if ([string]::IsNullOrWhiteSpace($serverDirectory)) { throw "SQL Server did not return $propertyName." }
        $target = (Join-Path $serverDirectory "${legacyDatabase}_$($file.FileId).$extension").Replace("'", "''")
        $moves += "MOVE N'$logicalName' TO N'$target'"
    }
    Invoke-TestSql "USE master; RESTORE DATABASE [$legacyDatabase] FROM DISK = N'$backupPath' WITH CHECKSUM, RECOVERY, $($moves -join ', ');"
    Invoke-TestSql "USE [$legacyDatabase];"
    Save-Invoices
    Invoke-TestScript '05_UpgradeExistingDatabase.sql' $legacyDatabase
    Invoke-TestScript '06_ThongNhatQuyTac.sql' $legacyDatabase
    Assert-Invoices
    Invoke-TestScript '03_Validate.sql' $legacyDatabase
    Invoke-TestScript '05_UpgradeExistingDatabase.sql' $legacyDatabase
    Write-Output "PASS: original legacy backup upgraded and validated; invoice IDs/details preserved: $legacyDatabase"
    Write-Output 'PASS: all upgrade paths. Isolated test databases retained; source database not replaced.'
} finally {
    $connection.Dispose()
    Stop-Transcript | Out-Null
}
