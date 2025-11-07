param(
    [Parameter(Mandatory=$true)][string]$ItemName
)

function Get-Bw-Session {
    $loggedIn = bw login --check 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "No has hecho 'bw login' en esta máquina. Ejecútalo una vez y vuelve a intentar."
        exit 1
    }

    if (-not $env:BW_SESSION -or [string]::IsNullOrWhiteSpace($env:BW_SESSION)) {
        $env:BW_SESSION = bw unlock --raw
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($env:BW_SESSION)) {
            Write-Host "No se pudo desbloquear la bóveda."
            exit 1
        }
    }
    return $env:BW_SESSION
}

# Sync por si el Desktop tuvo cambios
bw sync | Out-Null

$session = Get-Bw-Session

# Busca por nombre usando --search y toma la mejor coincidencia
$items = bw list items --search $ItemName --session $session | ConvertFrom-Json
if (-not $items) {
    Write-Host "No se encontró ningún ítem que coincida con '$ItemName'."
    exit 1
}

# Prioriza coincidencia exacta por nombre; si no, toma la primera
$item =
    ($items | Where-Object { $_.name -eq $ItemName } | Select-Object -First 1) `
    ?? ($items | Select-Object -First 1)

# Extrae password desde login.password o desde fields
$pw = $null
if ($item.login -and $item.login.password) {
    $pw = $item.login.password
} elseif ($item.fields) {
    $candidate = $item.fields | Where-Object {
        $_.name -match '^(password|contraseña|pass|pwd)$'
    } | Select-Object -First 1
    if ($candidate) { $pw = $candidate.value }
}

if (-not $pw) {
    Write-Host "Se encontró el ítem '$($item.name)', pero no tiene contraseña en login.password ni en campos conocidos."
    Write-Host "Revisa el ítem en Bitwarden o comparte el nombre del campo personalizado."
    exit 1
}

Set-Clipboard -Value $pw
Write-Host "Contraseña de '$($item.name)' copiada al portapapeles (15s)..."
Start-Sleep -Seconds 15
Set-Clipboard -Value ''
Write-Host "Clipboard limpiado."
