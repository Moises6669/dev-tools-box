<# 
Instalador de scripts como comandos globales (usuario actual)
- Copia TODOS los .ps1 del repo (recursivo) a %USERPROFILE%\Scripts, excluyendo install/uninstall
- Añade %USERPROFILE%\Scripts al PATH de usuario (si falta)
- Crea shims .cmd por cada .ps1 para invocarlos sin extensión (PowerShell o CMD)

Uso remoto (sin clonar):
  iwr -useb https://raw.githubusercontent.com/Moises6669/dev-tools-box/main/install.ps1 | iex

Uso local (repo clonado):
  pwsh -File .\install.ps1
#>

$ErrorActionPreference = 'Stop'

# === 0) Directorio destino: %USERPROFILE%\Scripts (no requiere admin)
$InstallDir = Join-Path $env:USERPROFILE 'Scripts'
if (-not (Test-Path $InstallDir)) {
  New-Item -ItemType Directory -Path $InstallDir | Out-Null
}

# === 1) Obtener contenido del repo (local o remoto)
$RepoRoot = $null
$IsRemote = $false

if ($MyInvocation.MyCommand.Path) {
  # Ejecutado desde archivo local (repo clonado)
  $RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
} else {
  # Ejecutado de forma remota (iwr ... | iex): descargar ZIP del repo a %TEMP%
  $IsRemote = $true
  $zipUrl   = "https://github.com/Moises6669/dev-tools-box/archive/refs/heads/main.zip"
  $zipPath  = Join-Path $env:TEMP "dev-tools-box.zip"
  $rootPath = Join-Path $env:TEMP "dev-tools-box-main"

  Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
  Remove-Item -Path $rootPath -Recurse -Force -ErrorAction SilentlyContinue

  Write-Host "Descargando scripts desde GitHub..." -ForegroundColor Gray
  Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath
  Expand-Archive -Path $zipPath -DestinationPath $env:TEMP -Force
  $RepoRoot = $rootPath
}

if (-not (Test-Path $RepoRoot)) {
  throw "No encontré el contenido del repo en: $RepoRoot"
}

# === 2) Buscar TODOS los .ps1 recursivamente desde la raíz del repo (excluir install/uninstall)
$ps1Files = Get-ChildItem -Path $RepoRoot -Recurse -Filter *.ps1 -File |
            Where-Object { $_.Name -notin @('install.ps1','uninstall.ps1') }

if ($ps1Files.Count -eq 0) {
  throw "No se encontraron archivos .ps1 en $RepoRoot"
}

Write-Host "Copiando scripts → $InstallDir"
foreach ($f in $ps1Files) {
  $dest = Join-Path $InstallDir $f.Name
  Copy-Item -Path $f.FullName -Destination $dest -Force
}

# Limpieza temporal si fue remoto
if ($IsRemote) {
  Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
  Remove-Item -Path $rootPath -Recurse -Force -ErrorAction SilentlyContinue
}

# === 3) Asegurar PATH de usuario
$pathSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$env:Path.Split(';') | ForEach-Object { if ($_ -and $_.Trim()) { $null = $pathSet.Add($_.Trim()) } }
if (-not ($pathSet.Contains($InstallDir))) {
  Write-Host "Agregando $InstallDir al PATH de usuario"
  $newPath = ($env:Path.TrimEnd(';') + ';' + $InstallDir)
  setx PATH $newPath | Out-Null
  Write-Host "Abre una NUEVA consola para refrescar el PATH."
} else {
  Write-Host "$InstallDir ya está en PATH"
}

# === 4) Crear shims .cmd para invocar los .ps1 sin extensión
Get-ChildItem -Path $InstallDir -Filter *.ps1 -File | ForEach-Object {
  $base = [IO.Path]::GetFileNameWithoutExtension($_.Name)
  $shim = Join-Path $InstallDir ($base + '.cmd')
  $cmd  = "@echo off`r`nsetlocal`r`npowershell -NoProfile -ExecutionPolicy Bypass -File ""%~dp0$($base).ps1"" %*`r`n"
  Set-Content -Path $shim -Value $cmd -Encoding ASCII
}

# === 5) Sugerir ExecutionPolicy si hay bloqueo
try {
  $ep = Get-ExecutionPolicy -Scope CurrentUser -ErrorAction SilentlyContinue
  if ($ep -in @($null,'Undefined','Restricted','AllSigned')) {
    Write-Host "Si tienes bloqueo de scripts, ejecuta:" -ForegroundColor Yellow
    Write-Host "  Set-ExecutionPolicy -Scope CurrentUser RemoteSigned" -ForegroundColor Yellow
  }
} catch {}

Write-Host "✅ Instalación completada en: $InstallDir"
Write-Host "👉 Abre una nueva terminal y prueba: importar-db -Sql ""C:\ruta\dump.sql"""
