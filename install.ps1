<# 
Instalador de scripts como comandos globales (usuario actual)
- Copia .\scripts\*.ps1 a $HOME\Scripts (crea si no existe)
- Añade $HOME\Scripts al PATH de usuario (si falta)
- Crea shims .cmd por cada .ps1 para invocarlos sin extensión
Uso local (repo clonado):
  pwsh -File .\install.ps1
Uso remoto (one-liner desde GitHub Raw, cuando publiques):
  iwr -useb "https://raw.githubusercontent.com/<USER>/<REPO>/main/install.ps1" | iex
#>

$ErrorActionPreference = 'Stop'

# Destination directory: %USERPROFILE%\Scripts (no admin required)
$InstallDir = Join-Path $env:USERPROFILE 'Scripts'
if (-not (Test-Path $InstallDir)) {
  New-Item -ItemType Directory -Path $InstallDir | Out-Null
}

# Find "scripts" folder if it exists (cloned repo)
$Here = Split-Path -Parent $MyInvocation.MyCommand.Definition
if (-not $Here) { $Here = (Get-Location).Path }
$SourceDir = Join-Path $Here 'scripts'

if (Test-Path $SourceDir) {
  Write-Host "📦 Copiando scripts desde: $SourceDir → $InstallDir"
  Copy-Item -Path (Join-Path $SourceDir '*.ps1') -Destination $InstallDir -Force -ErrorAction Stop
} else {
  Write-Host "⚠️ No encontré carpeta local 'scripts'. Si ejecutaste por one-liner, sube los scripts al repo y/o ajusta este instalador para descargarlos." -ForegroundColor Yellow
}

# === 2) Asegurar PATH de usuario
$pathEntries = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$env:Path.Split(';') | ForEach-Object { if ($_ -and $_.Trim()) { $null = $pathEntries.Add($_.Trim()) } }
if (-not ($pathEntries.Contains($InstallDir))) {
  Write-Host "➕ Agregando $InstallDir al PATH de usuario"
  $newPath = ($env:Path.TrimEnd(';') + ';' + $InstallDir)
  setx PATH $newPath | Out-Null
  Write-Host "ℹ️ Abre una NUEVA consola para que el PATH se refresque."
} else {
  Write-Host "✅ $InstallDir ya está en PATH"
}

# Create .cmd shims to invoke .ps1 scripts without extension
Get-ChildItem -Path $InstallDir -Filter *.ps1 -File | ForEach-Object {
  $base = [IO.Path]::GetFileNameWithoutExtension($_.Name)
  $shim = Join-Path $InstallDir ($base + '.cmd')
  # shim permite: base args... tanto en PowerShell como en CMD
  $cmd = "@echo off`r`n" +
         "setlocal`r`n" +
         "powershell -NoProfile -ExecutionPolicy Bypass -File ""%~dp0$($base).ps1"" %*`r`n"
  Set-Content -Path $shim -Value $cmd -Encoding ASCII
}

#  Suggest ExecutionPolicy if scripts are blocked
try {
  $ep = Get-ExecutionPolicy -Scope CurrentUser -ErrorAction SilentlyContinue
  if ($ep -in @($null,'Undefined','Restricted','AllSigned')) {
    Write-Host "ℹ️ Si tienes bloqueo de scripts, ejecuta:" -ForegroundColor Yellow
    Write-Host "   Set-ExecutionPolicy -Scope CurrentUser RemoteSigned" -ForegroundColor Yellow
  }
} catch {}

Write-Host "☠️👍🏽🐵 Instalación completada en: $InstallDir"
Write-Host "👉 Abre una nueva terminal y ejecuta: importar-db -Sql ""C:\ruta\dump.sql"""
