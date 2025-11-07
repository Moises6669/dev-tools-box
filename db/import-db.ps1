param(
  [Parameter(Position=0, Mandatory=$true)]
  [string]$Sql,

  [Parameter(Position=1)]
  [string]$DbName,

  [string]$User = "root",
  [string]$DbHost = "127.0.0.1",
  [int]$Port = 3306
)

if (-not (Test-Path $Sql)) {
  Write-Host "❌ No existe el archivo SQL: $Sql" -ForegroundColor Red
  exit 1
}

# 1) Derivar nombre de BD desde el archivo si no se pasa -DbName
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

# 2) ruta fija para mysql.exe de Laragon

# Ruta por defecto y archivo de configuración
$configFile = Join-Path $PSScriptRoot 'mysql-path.txt'
$defaultMysqlExe = "C:\laragon\bin\mysql\mysql-8.0.30-winx64\bin\mysql.exe"

# Leer ruta guardada si existe
if (Test-Path $configFile) {
  $mysqlExe = Get-Content $configFile -Raw
} else {
  $mysqlExe = $defaultMysqlExe
}

if (-not (Test-Path $mysqlExe)) {
  Write-Host "⚠️ No encontré mysql.exe en la ruta especificada: $mysqlExe" -ForegroundColor Yellow
  $newPath = Read-Host "Por favor ingresa la ruta completa de mysql.exe"
  # Limpiar comillas si el usuario las pone
  $newPath = $newPath.Trim('"')
  if (-not (Test-Path $newPath)) {
    Write-Host "❌ La ruta ingresada no es válida o no existe: $newPath" -ForegroundColor Red
    exit 1
  }
  $mysqlExe = $newPath
  Set-Content -Path $configFile -Value $mysqlExe
  Write-Host "✅ Ruta guardada en $configFile" -ForegroundColor Green
}

# 3) Pedir contraseña (si queda vacía, se intenta sin --password)
$secure = Read-Host "Contraseña de usuario $User" -AsSecureString
$plain  = ""
try { $plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)) } catch {}

# Helper para armar args sin comillas raras
function Get-MysqlArgs([string[]]$extra) {
  $args = @("--host=$DbHost","--port=$Port","--user=$User")
  if ($plain -and $plain.Length -gt 0) { $args += "--password=$plain" }
  if ($extra) { $args += $extra }
  return $args
}

# 4) Crear la BD (sin backticks)
Write-Host "🔧🐵👍🏽 Creando base de datos '$DbName'" -ForegroundColor Gray
& $mysqlExe (Get-MysqlArgs @("-e","CREATE DATABASE IF NOT EXISTS $DbName DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"))
if ($LASTEXITCODE -ne 0) {
  Write-Host "❌👎🏽🙊 Error creando la base de datos '$DbName'." -ForegroundColor Red
  exit $LASTEXITCODE
}

# 5) Importa el SQL usando SOURCE
Write-Host "📦 Importando '$Sql' a '$DbName'..." -ForegroundColor Gray
$SqlForMysql = ($Sql -replace '\\','/')
& $mysqlExe (Get-MysqlArgs @($DbName,"-e","SOURCE $SqlForMysql;"))

if ($LASTEXITCODE -eq 0) {
  Write-Host "✅🐵👍🏽 Importación completada en '$DbName'." -ForegroundColor Green
} else {
  Write-Host "❌👎🏽☠️ Falló la importación." -ForegroundColor Red
  exit $LASTEXITCODE
}
