# =====================================================================
# Respaldo logico de inventario_irribarra (mysqldump)
#   Incluye estructura, datos, triggers, procedimientos y vistas.
#   Archivo: db\respaldos\inventario_AAAAMMDD_HHMM.sql
#   Conserva los ultimos 15 respaldos.
#
# Uso:  powershell -ExecutionPolicy Bypass -File db\respaldo.ps1
# (Se puede programar diario con el Programador de tareas de Windows)
# =====================================================================
param(
    [string]$BinDir   = 'C:\Program Files\MySQL\MySQL Server 8.4\bin',
    [string]$DbHost   = '127.0.0.1',
    [int]   $Port     = 3306,
    [string]$RootUser = 'root',
    [int]   $Conservar = 15,
    [switch]$SinPassword   # solo para pruebas con un servidor sin contrasena de root
)
$ErrorActionPreference = 'Stop'

$destino = Join-Path $PSScriptRoot 'respaldos'
New-Item -ItemType Directory -Force $destino | Out-Null
$archivo = Join-Path $destino ("inventario_{0:yyyyMMdd_HHmm}.sql" -f (Get-Date))

$clave = ''
if (-not $SinPassword) {
    $sec = Read-Host "Contrasena de '$RootUser' de MySQL" -AsSecureString
    $clave = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
}
$optFile = Join-Path $PSScriptRoot '_respaldo_tmp.cnf'
$clave = $clave.Replace('\', '\\').Replace('"', '\"')
"[client]`r`nuser=$RootUser`r`npassword=`"$clave`"`r`nhost=$DbHost`r`nport=$Port`r`n" |
    Set-Content -Encoding ascii $optFile
$clave = $null

try {
    cmd /c "`"$BinDir\mysqldump.exe`" --defaults-extra-file=`"$optFile`" --single-transaction --routines --triggers --events --no-tablespaces --set-gtid-purged=OFF --default-character-set=utf8mb4 --databases inventario_irribarra --result-file=`"$archivo`""
    if ($LASTEXITCODE -ne 0) { throw "mysqldump termino con codigo $LASTEXITCODE" }
} finally {
    Remove-Item $optFile -Force -ErrorAction SilentlyContinue
}

$tam = [math]::Round((Get-Item $archivo).Length / 1KB, 1)
Write-Host "Respaldo creado: $archivo ($tam KB)" -ForegroundColor Green

# Rotacion: conservar solo los mas recientes
Get-ChildItem $destino -Filter 'inventario_*.sql' | Sort-Object Name -Descending |
    Select-Object -Skip $Conservar | Remove-Item -Force
