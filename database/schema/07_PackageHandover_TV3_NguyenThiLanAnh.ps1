param([string]$OutputPath)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$sourceDirectory = $PSScriptRoot
if (-not $sourceDirectory) { $sourceDirectory = 'E:\Copilot\CSDL\BCNF_BanGiao' }
if (-not $OutputPath) {
    $OutputPath = Join-Path (Split-Path $sourceDirectory -Parent) ('BCNF_BanGiao_' + (Get-Date -Format 'yyyyMMdd_HHmmss_fff') + '.zip')
}
if (Test-Path -LiteralPath $OutputPath) { throw 'Output already exists; choose a new ZIP path.' }
$files = @(Get-ChildItem -LiteralPath $sourceDirectory -File | Where-Object {
    $_.Extension.ToLowerInvariant() -in @('.sql', '.ps1', '.md', '.mmd', '.txt', '.bak')
})
if (-not ($files | Where-Object { $_.Extension -eq '.bak' })) { throw 'No handover backup found.' }
# TV6 sửa: gói bàn giao phải mang theo migration quy tắc 18 bảng mới.
foreach ($required in @('01_CreateSchema.sql', '02_InsertSeedData.sql', '03_Validate.sql', '04_BackupAndVerify.sql', '05_UpgradeExistingDatabase.sql', '06_ThongNhatQuyTac.sql', 'README.md', 'BCNF_18_Bang.mmd')) {
    if ($required -notin $files.Name) { throw "Missing required file: $required" }
}
$temporaryPath = $OutputPath + '.' + [Guid]::NewGuid().ToString('N') + '.partial'
try {
    $archive = [System.IO.Compression.ZipFile]::Open($temporaryPath, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($file in $files) {
            [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $file.FullName, ('BCNF_BanGiao/' + $file.Name), [System.IO.Compression.CompressionLevel]::Optimal)
        }
    } finally { $archive.Dispose() }
    $archive = [System.IO.Compression.ZipFile]::OpenRead($temporaryPath)
    try {
        if ($archive.Entries.Count -ne $files.Count) { throw 'ZIP entry count mismatch.' }
        foreach ($file in $files) {
            $entry = $archive.GetEntry('BCNF_BanGiao/' + $file.Name)
            if (-not $entry -or $entry.Length -ne $file.Length) { throw "ZIP size mismatch: $($file.Name)" }
            $hash = [System.Security.Cryptography.SHA256]::Create()
            $sourceStream = [System.IO.File]::OpenRead($file.FullName)
            $zipStream = $entry.Open()
            try {
                $sourceHash = [Convert]::ToBase64String($hash.ComputeHash($sourceStream))
                $zipHash = [Convert]::ToBase64String($hash.ComputeHash($zipStream))
                if ($sourceHash -ne $zipHash) { throw "ZIP hash mismatch: $($file.Name)" }
            } finally { $sourceStream.Dispose(); $zipStream.Dispose(); $hash.Dispose() }
        }
        if ($archive.Entries.FullName -match '\.(mdf|ndf|ldf)$') { throw 'Live database file included in ZIP.' }
    } finally { $archive.Dispose() }
    Move-Item -LiteralPath $temporaryPath -Destination $OutputPath
    Write-Output "PASS: $($files.Count) files verified by SHA256; no MDF/NDF/LDF."
    Write-Output "ZIP: $OutputPath"
} finally {
    if (Test-Path -LiteralPath $temporaryPath) { Remove-Item -LiteralPath $temporaryPath }
}
