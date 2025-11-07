<#
Uninstaller: removes .cmd shims and optionally the .ps1 files from %USERPROFILE%\Scripts
Does not touch the PATH (you can remove it manually if you want).
#>


# Stop on all errors
$ErrorActionPreference = 'Stop'
$InstallDir = Join-Path $env:USERPROFILE 'Scripts'

if (-not (Test-Path $InstallDir)) {
  Write-Host "$InstallDir does not exist. Nothing to do." -ForegroundColor Yellow
  exit 0
}


$removePs1 = Read-Host "Also delete .ps1 files in $InstallDir? (y/n)"
$removePs1 = $removePs1 -match '^[yY]'

Get-ChildItem -Path $InstallDir -Filter *.cmd -File | ForEach-Object {
  Write-Host "🗑  Deleting shim: $($_.FullName)"
  Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
}

if ($removePs1) {
  Get-ChildItem -Path $InstallDir -Filter *.ps1 -File | ForEach-Object {
    Write-Host "🗑  Deleting script: $($_.FullName)"
    Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
  }
}

Write-Host "✔ Uninstallation finished."
Write-Host "ℹ️ If you want, you can remove $InstallDir from the PATH manually from Settings > System > About > Advanced system settings."
