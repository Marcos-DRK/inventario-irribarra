# =====================================================================
# Restaura inventario_irribarra desde un respaldo de db\respaldos
#   ATENCION: reemplaza la base actual por la del respaldo.
#   Los usuarios de conexion (app_admin, app_trabajador) y sus roles
#   viven fuera de la base y no se ven afectados.
#
# Uso:  powershell -ExecutionPolicy Bypass -File db\restaurar.ps1 [-Archivo ruta.sql]
#       Sin -Archivo usa el respaldo mas reciente.
# =====================================================================
param(
    [string]$Archivo,
    [string]$BinDir   = 'C:\Program Files\MySQL\MySQL Server 8.4\bin',
    [string]$DbHost   = '127.0.0.1',
    [int]   $Port     = 3306,
    [string]$RootUser = 'root',
    [switch]$SinPassword,
    [switch]$Confirmar   # omite la pregunta de confirmacion
)
$ErrorActionPreference = 'Stop'

if (-not $Archivo) {
    $ultimo = Get-ChildItem (Join-Path $PSScriptRoot 'respaldos') -Filter 'inventario_*.sql' -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1
    if (-not $ultimo) { throw 'No hay respaldos en db\respaldos' }
    $Archivo = $ultimo.FullName
}
if (-not (Test-Path $Archivo)) { throw "No existe el archivo $Archivo" }

Write-Host "Se restaurara: $Archivo" -ForegroundColor Yellow
if (-not $Confirmar) {
    $r = Read-Host 'Esto reemplaza la base inventario_irribarra actual. Escriba SI para continuar'
    if ($r -ne 'SI') { Write-Host 'Cancelado.'; return }
}

$clave = ''
if (-not $SinPassword) {
    $sec = Read-Host "Contrasena de '$RootUser' de MySQL" -AsSecureString
    $clave = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
}
$optFile = Join-Path $PSScriptRoot '_restaurar_tmp.cnf'
$clave = $clave.Replace('\', '\\').Replace('"', '\"')
"[client]`r`nuser=$RootUser`r`npassword=`"$clave`"`r`nhost=$DbHost`r`nport=$Port`r`n" |
    Set-Content -Encoding ascii $optFile
$clave = $null

try {
    cmd /c "`"$BinDir\mysql.exe`" --defaults-extra-file=`"$optFile`" --default-character-set=utf8mb4 -e `"DROP DATABASE IF EXISTS inventario_irribarra`""
    if ($LASTEXITCODE -ne 0) { throw "No se pudo eliminar la base actual (codigo $LASTEXITCODE)" }
    cmd /c "`"$BinDir\mysql.exe`" --defaults-extra-file=`"$optFile`" --default-character-set=utf8mb4 < `"$Archivo`""
    if ($LASTEXITCODE -ne 0) { throw "mysql termino con codigo $LASTEXITCODE" }
    Write-Host 'Restauracion terminada.' -ForegroundColor Green
} finally {
    Remove-Item $optFile -Force -ErrorAction SilentlyContinue
}
