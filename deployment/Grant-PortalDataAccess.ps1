param([Parameter(Mandatory=$true)][string]$Identity)
$ErrorActionPreference = 'Stop'
# Run in elevated PowerShell only when using IIS/a separate Windows service identity.
$portalAccount = New-Object Security.Principal.NTAccount($Identity)
$null = $portalAccount.Translate([Security.Principal.SecurityIdentifier])
$portalSecretDirectory = Join-Path $env:ProgramData 'HoaThienPortal'
if (!(Test-Path -LiteralPath $portalSecretDirectory -PathType Container)) { throw 'Nhap bi mat truoc khi cap quyen.' }
$portalPrivateAcl = Get-Acl -LiteralPath $portalSecretDirectory
$portalPrivateRule = New-Object Security.AccessControl.FileSystemAccessRule($Identity, 'Modify', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
$portalPrivateAcl.AddAccessRule($portalPrivateRule)
Set-Acl -LiteralPath $portalSecretDirectory -AclObject $portalPrivateAcl
foreach ($portalFile in Get-ChildItem -LiteralPath $portalSecretDirectory -File -Filter '*.dpapi') {
    $portalFileAcl = Get-Acl -LiteralPath $portalFile.FullName
    $portalFileRule = New-Object Security.AccessControl.FileSystemAccessRule($Identity, 'Modify', 'Allow')
    $portalFileAcl.AddAccessRule($portalFileRule)
    Set-Acl -LiteralPath $portalFile.FullName -AclObject $portalFileAcl
}
$portalDataDirectory = Join-Path $PSScriptRoot 'App_Data'
New-Item -ItemType Directory -Path $portalDataDirectory -Force | Out-Null
$portalDataAcl = Get-Acl -LiteralPath $portalDataDirectory
$portalDataAcl.AddAccessRule($portalPrivateRule)
Set-Acl -LiteralPath $portalDataDirectory -AclObject $portalDataAcl
Write-Host 'Da cap quyen Modify cho tai khoan Windows duoc chi dinh. Khong cap cho Everyone.'
