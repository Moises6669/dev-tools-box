param(
  [Parameter(Position=0, Mandatory=$true)]
  [string]$Sql,

  [Parameter(Position=1)]
  [string]$DbName,

  [string]$User = "root",
  [string]$DbHost = "127.0.0.1",
  [int]$Port = 3306
)

$ErrorActionPreference = 'Stop'

# --- Validar archivo SQL ---
if (-not (Test-Path $Sql)) {
  Write-Host "❌ No existe el archivo SQL: $Sql" -ForegroundColor Red
  exit 1
}

# --- Derivar nombre de BD si no se pasó ---
if (-not $DbName) {
  $DbName = [System.IO.Path]::GetFileNameWithoutExtension($Sql)
}
if (-not $DbName -or $DbName.Trim().Length -eq 0) {
  Write-Host "❌👎🏽🙊 No pude derivar el nombre de BD desde: $Sql" -ForegroundColor Red
  exit 1
}
if ($DbName -notmatch '^[A-Za-z0-9_]+$') {
  Write-Host "❌🐒 Nombre de BD inválido: '$DbName'. Usa solo letras, números o _" -ForegroundColor Red
  exit 1
}

Write-Host "🆔 Base de datos objetivo: '$DbName' (derivada del archivo)" -ForegroundColor Cyan

# --- 1) Resolver ruta a mysql.exe con persistencia ---
# Archivo de configuración junto al script (sobrevive a futuras ejecuciones)
$configFile = Join-Path $PSScriptRoot 'mysql-path.txt'

# 1.a) Intentar leer configuración previa (TRIM para quitar \r\n y comillas)
$mysqlExe = $null
if (Test-Path $configFile) {
  $mysqlExe = (Get-Content $configFile -Raw).Trim().Trim('"')
  if (-not (Test-Path $mysqlExe)) { $mysqlExe = $null }
}

# 1.b) Si no hay config válida, probar si está en el PATH
if (-not $mysqlExe) {
  $cmd = Get-Command mysql.exe -ErrorAction SilentlyContinue
  if ($cmd) { $mysqlExe = $cmd.Source }
}

# 1.c) Si no, buscar en Laragon (última versión encontrada)
if (-not $mysqlExe -and (Test-Path "C:\laragon\bin\mysql")) {
  $cand = Get-ChildItem "C:\laragon\bin\mysql" -Recurse -Filter "mysql.exe" -ErrorAction SilentlyContinue |
          Where-Object { $_.FullName -match "bin\\mysql.exe$" } |
          Sort-Object FullName -Descending | Select-Object -First 1
  if ($cand) { $mysqlExe = $cand.FullName }
}

# 1.d) Si aún no, pedir al usuario y guardar SIN salto de línea
if (-not $mysqlExe) {
  Write-Host "⚠️ No encontré mysql.exe automáticamente." -ForegroundColor Yellow
  $newPath = Read-Host "Ingresa la ruta COMPLETA de mysql.exe (por ej. C:\laragon\bin\mysql\mysql-8.x.x\bin\mysql.exe)"
  $newPath = $newPath.Trim('"').Trim()
  if (-not (Test-Path $newPath)) {
    Write-Host "❌ La ruta ingresada no es válida o no existe: $newPath" -ForegroundColor Red
    exit 1
  }
  $mysqlExe = $newPath
  Set-Content -Path $configFile -Value $mysqlExe -NoNewline
  Write-Host "✅ Ruta guardada en $configFile" -ForegroundColor Green
}

# Seguridad: re-validar por si algo cambió
if (-not (Test-Path $mysqlExe)) {
  Write-Host "❌ mysql.exe no existe en: $mysqlExe" -ForegroundColor Red
  exit 1
}

# --- 2) Credenciales ---
$secure = Read-Host "Contraseña de usuario $User" -AsSecureString
$plain  = ""
try { $plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)) } catch {}

function Get-MysqlArgs([string[]]$extra) {
  $args = @("--host=$DbHost","--port=$Port","--user=$User")
  if ($plain -and $plain.Length -gt 0) { $args += "--password=$plain" }
  if ($extra) { $args += $extra }
  return $args
}

# --- 3) Crear BD ---
Write-Host "🔧🐵 Creando base de datos '$DbName' (si no existe)..." -ForegroundColor Gray
& $mysqlExe (Get-MysqlArgs @("-e","CREATE DATABASE IF NOT EXISTS $DbName DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"))
if ($LASTEXITCODE -ne 0) {
  Write-Host "❌ Error creando la base de datos '$DbName'." -ForegroundColor Red
  exit $LASTEXITCODE
}

# --- 4) Importar SQL ---
Write-Host "📦 Importando '$Sql' a '$DbName'..." -ForegroundColor Gray
$SqlForMysql = ($Sql -replace '\\','/')
& $mysqlExe (Get-MysqlArgs @($DbName,"-e","SOURCE $SqlForMysql;"))

if ($LASTEXITCODE -eq 0) {
  Write-Host "✅🐵👍🏽 Importación completada en '$DbName'." -ForegroundColor Green
} else {
  Write-Host "❌👎🏽☠️ Falló la importación." -ForegroundColor Red
  exit $LASTEXITCODE
}
