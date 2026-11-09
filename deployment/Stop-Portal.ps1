$ErrorActionPreference = 'Stop'
$portalRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$portalPidFile = Join-Path $portalRoot 'App_Data\logs\website.pid'
if (!(Test-Path -LiteralPath $portalPidFile)) { Write-Host 'Khong co PID website do launcher tao.'; exit 0 }
$portalProcessId = [int](Get-Content -LiteralPath $portalPidFile -Raw).Trim()
$portalProcess = Get-Process -Id $portalProcessId -ErrorAction SilentlyContinue
if ($null -eq $portalProcess) { Remove-Item -LiteralPath $portalPidFile; Write-Host 'Website da dung.'; exit 0 }
$portalExpected = [IO.Path]::GetFullPath((Join-Path $portalRoot 'WebGame.exe'))
if (![String]::Equals($portalProcess.Path, $portalExpected, [StringComparison]::OrdinalIgnoreCase)) { throw 'PID khong thuoc website trong thu muc nay; khong dung tien trinh khac.' }
Stop-Process -Id $portalProcessId
Remove-Item -LiteralPath $portalPidFile
Write-Host 'Da dung website trong thu muc nay.'
