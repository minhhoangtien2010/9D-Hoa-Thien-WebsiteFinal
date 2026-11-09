param(
    [string]$OutputDirectory,
    [string]$MigrationKeyFile = (Join-Path $env:ProgramData 'HoaThienPortal\migration-key.txt'),
    [switch]$SkipSecretExport,
    [switch]$SkipArchive
)
$ErrorActionPreference = 'Stop'
$portalSourceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (!$OutputDirectory) { $OutputDirectory = Join-Path (Split-Path -Parent $portalSourceRoot) ('CuuLongHoaThien-Windows-x64-' + (Get-Date -Format 'yyyyMMdd-HHmmss')) }
$portalRelease = [IO.Path]::GetFullPath($OutputDirectory)
$MigrationKeyFile = [IO.Path]::GetFullPath($MigrationKeyFile)
if ($portalRelease.StartsWith($portalSourceRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or $portalRelease -eq $portalSourceRoot) { throw 'Thu muc publish phai nam NGOAI source de khong long bin/obj hoac secrets vao project.' }
if ($MigrationKeyFile.StartsWith($portalRelease.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Khoa di chuyen phai nam NGOAI thu muc publish/ZIP.' }
if (Test-Path -LiteralPath $portalRelease) { throw 'Thu muc dich da ton tai. Chon thu muc moi; script khong xoa file cu.' }
New-Item -ItemType Directory -Path $portalRelease | Out-Null
$portalHelperOutput = Join-Path $env:TEMP ('HoaThienPortable-helper-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $portalHelperOutput | Out-Null
Push-Location -LiteralPath $portalSourceRoot
try {
    & dotnet publish (Join-Path $portalSourceRoot 'WebGame\WebGame.csproj') -c Release -r win-x64 --self-contained true -p:UseAppHost=true -p:UseSharedCompilation=false -p:DebugType=None -p:DebugSymbols=false -o $portalRelease
    if ($LASTEXITCODE -ne 0) { throw 'Publish website that bai.' }
    & dotnet publish (Join-Path $portalSourceRoot 'tools\Portal.Portable\Portal.Portable.csproj') -c Release -r win-x64 --self-contained true -p:UseAppHost=true -p:UseSharedCompilation=false -p:DebugType=None -p:DebugSymbols=false -o $portalHelperOutput
    if ($LASTEXITCODE -ne 0) { throw 'Publish cong cu di chuyen that bai.' }
    foreach ($portalRuntimeFile in Get-ChildItem -LiteralPath $portalHelperOutput -File) {
        $portalRuntimeTarget = Join-Path $portalRelease $portalRuntimeFile.Name
        if (Test-Path -LiteralPath $portalRuntimeTarget) {
            if ((Get-FileHash -LiteralPath $portalRuntimeTarget).Hash -ne (Get-FileHash -LiteralPath $portalRuntimeFile.FullName).Hash) { throw "Runtime helper va website khac nhau: $($portalRuntimeFile.Name). Khong ghi de runtime." }
        }
        else { Copy-Item -LiteralPath $portalRuntimeFile.FullName -Destination $portalRuntimeTarget }
    }
    # Reads the configured media root, preserves legacy URLs and makes paths relative on the new machine.
    & (Join-Path $portalRelease 'Portal.Portable.exe') prepare-media --root (Join-Path $portalSourceRoot 'WebGame') --destination $portalRelease
    if ($LASTEXITCODE -ne 0) { throw 'Sao chep anh vat ly va legacy that bai.' }
    foreach ($portalScript in @('Start-Portal.ps1','Stop-Portal.ps1','Import-Secrets.ps1','Grant-PortalDataAccess.ps1','CHAY_WEBSITE.cmd','DUNG_WEBSITE.cmd','NHAP_BI_MAT.cmd','KIEM_TRA.cmd','HUONG_DAN_CHUYEN_MAY.md')) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $portalScript) -Destination $portalRelease
    }
    foreach ($portalNote in @('CAP_NHAT_TRANG_VANG_TRANG.md','RA_SOAT_HOAN_THIEN_20261109.md','KET_NOI_GOOGLE_SHEET.md','DOI_TEN_NHAN_VAT.md','INGAME_SHOP.md','DONG_GOI_CHUYEN_MAY.md')) {
        $portalUpdateNotes = Join-Path $portalSourceRoot $portalNote
        if (Test-Path -LiteralPath $portalUpdateNotes -PathType Leaf) { Copy-Item -LiteralPath $portalUpdateNotes -Destination $portalRelease }
    }
    & (Join-Path $portalRelease 'Portal.Portable.exe') self-test
    if ($LASTEXITCODE -ne 0) { throw 'Kiem tra ma hoa that bai.' }
    if (!$SkipSecretExport) {
        & (Join-Path $portalRelease 'Portal.Portable.exe') export-secrets --root (Join-Path $portalSourceRoot 'WebGame') --output (Join-Path $portalRelease 'portable-secrets.aes.json') --key-file $MigrationKeyFile
        if ($LASTEXITCODE -ne 0) { throw 'Xuat bi mat di chuyen that bai.' }
    }
    & (Join-Path $portalRelease 'Portal.Portable.exe') preflight --root $portalRelease
    if ($LASTEXITCODE -ne 0) { throw 'Ban publish chua qua kiem tra SQL/quyen thu muc.' }
    if (!$SkipArchive) {
        $portalArchive = $portalRelease + '.zip'
        Compress-Archive -LiteralPath $portalRelease -DestinationPath $portalArchive -CompressionLevel Optimal
        Write-Host "Da tao ZIP: $portalArchive"
    }
    Write-Host "Ban Windows x64: $portalRelease"
    if (!$SkipSecretExport) { Write-Host "Khoa di chuyen luu RIENG: $MigrationKeyFile" }
}
finally { Pop-Location }
# No automatic recursive deletion. The temporary helper folder contains no plaintext secret.
