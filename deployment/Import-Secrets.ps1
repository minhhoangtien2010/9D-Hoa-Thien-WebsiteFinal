param([string]$KeyFile, [switch]$Replace)
$ErrorActionPreference = 'Stop'
$portalArguments = @('import-secrets', '--root', $PSScriptRoot, '--input', (Join-Path $PSScriptRoot 'portable-secrets.aes.json'))
if ($KeyFile) { $portalArguments += @('--key-file', [IO.Path]::GetFullPath($KeyFile)) }
if ($Replace) { $portalArguments += '--replace' }
& (Join-Path $PSScriptRoot 'Portal.Portable.exe') @portalArguments
if ($LASTEXITCODE -ne 0) { throw 'Chua nhap duoc bi mat. Kiem tra khoa va quyen truy cap; khong chuyen file DPAPI truc tiep giua cac may.' }
