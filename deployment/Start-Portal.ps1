param(
    [ValidateRange(1024,65535)][int]$Port = 5188,
    [ValidateSet('127.0.0.1','localhost','0.0.0.0')][string]$ListenAddress = '127.0.0.1',
    [switch]$SkipPreflight,
    [switch]$NoBrowser
)
$ErrorActionPreference = 'Stop'
$portalRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$portalExecutable = Join-Path $portalRoot 'WebGame.exe'
$portalHelper = Join-Path $portalRoot 'Portal.Portable.exe'
if (!(Test-Path -LiteralPath $portalExecutable -PathType Leaf)) { throw 'Khong tim thay WebGame.exe. Chay script trong ban publish Windows x64.' }
Push-Location -LiteralPath $portalRoot
try {
    if (!$SkipPreflight) {
        $portalPreflightEnvironment = $env:ASPNETCORE_ENVIRONMENT
        try {
            $env:ASPNETCORE_ENVIRONMENT = 'Production'
            & $portalHelper preflight --root $portalRoot
            if ($LASTEXITCODE -ne 0) { throw 'Kiem tra truoc khi chay chua dat. Xu ly ket noi SQL/quyen thu muc roi thu lai.' }
        }
        finally { $env:ASPNETCORE_ENVIRONMENT = $portalPreflightEnvironment }
    }
    $portalListener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $Port)
    try { $portalListener.Start() }
    catch { throw "Cong $Port dang duoc su dung. Dong ban website cu hoac chon -Port khac." }
    finally { $portalListener.Stop() }
    $portalLogs = Join-Path $portalRoot 'App_Data\logs'
    New-Item -ItemType Directory -Path $portalLogs -Force | Out-Null
    $portalStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $portalStdout = Join-Path $portalLogs "website-$portalStamp.log"
    $portalStderr = Join-Path $portalLogs "website-$portalStamp.error.log"
    $portalOldEnvironment = $env:ASPNETCORE_ENVIRONMENT
    try {
        $env:ASPNETCORE_ENVIRONMENT = 'Production'
        $portalProcess = Start-Process -FilePath $portalExecutable -WorkingDirectory $portalRoot -ArgumentList @('--urls', "http://${ListenAddress}:$Port") -RedirectStandardOutput $portalStdout -RedirectStandardError $portalStderr -WindowStyle Hidden -PassThru
    }
    finally { $env:ASPNETCORE_ENVIRONMENT = $portalOldEnvironment }
    $portalProcess.Id | Set-Content -LiteralPath (Join-Path $portalLogs 'website.pid') -Encoding Ascii
    $portalUrl = "http://127.0.0.1:$Port"
    $portalReady = $false
    for ($portalAttempt = 0; $portalAttempt -lt 45; $portalAttempt++) {
        $portalProcess.Refresh()
        if ($portalProcess.HasExited) { throw "Website da dung. Xem log trong App_Data\logs (khong dang cong khai file log)." }
        try {
            $portalResponse = Invoke-WebRequest -Uri $portalUrl -UseBasicParsing -TimeoutSec 2
            if ($portalResponse.StatusCode -eq 200) { $portalReady = $true; break }
        }
        catch { }
        Start-Sleep -Milliseconds 800
    }
    if (!$portalReady) { throw "Website chua san sang. Tien trinh $($portalProcess.Id) van chay; xem App_Data\logs." }
    Write-Host "Website dang chay: $portalUrl (PID $($portalProcess.Id))"
    Write-Host 'Dung website: chay DUNG_WEBSITE.cmd. Khong chay hai ban website neu khong can thiet.'
    if (!$NoBrowser) { Start-Process -FilePath $portalUrl }
}
finally { Pop-Location }
