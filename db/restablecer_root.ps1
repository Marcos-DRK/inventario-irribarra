# =====================================================================
# Restablece la contrasena de root de MySQL 8.4 (servicio MySQL84)
# cuando se olvido. Requiere ejecutarse como administrador.
#
# Pasos: detiene el servicio, arranca mysqld una vez con --init-file
# (ALTER USER root), lo apaga y vuelve a iniciar el servicio.
# El archivo con la clave nueva se borra siempre al terminar.
# =====================================================================
#Requires -RunAsAdministrator
param(
    [string]$Servicio = 'MySQL84',
    [string]$BinDir   = 'C:\Program Files\MySQL\MySQL Server 8.4\bin',
    [string]$MyIni    = 'C:\ProgramData\MySQL\MySQL Server 8.4\my.ini',
    [int]   $Port     = 3306
)
$ErrorActionPreference = 'Stop'

function Leer-Clave([string]$texto) {
    $sec = Read-Host $texto -AsSecureString
    return [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
}

$pw1 = Leer-Clave 'Nueva contrasena para root'
$pw2 = Leer-Clave 'Repite la nueva contrasena'
if ($pw1 -ne $pw2) { throw 'Las contrasenas no coinciden. No se cambio nada.' }
if ($pw1.Length -lt 6) { throw 'Usa al menos 6 caracteres. No se cambio nada.' }

$tmpDir  = Join-Path $env:ProgramData 'MySQL\MySQL Server 8.4'
$initSql = Join-Path $tmpDir '_reset_root.sql'
$optFile = Join-Path $tmpDir '_reset_root.cnf'
$sqlPw   = $pw1.Replace('\', '\\').Replace("'", "''")
$cnfPw   = $pw1.Replace('\', '\\').Replace('"', '\"')

$mysqld = $null
try {
    "ALTER USER 'root'@'localhost' IDENTIFIED BY '$sqlPw';" | Set-Content -Encoding ascii $initSql
    "[client]`r`nuser=root`r`npassword=`"$cnfPw`"`r`nhost=127.0.0.1`r`nport=$Port`r`n" |
        Set-Content -Encoding ascii $optFile

    Write-Host "Deteniendo el servicio $Servicio..."
    Stop-Service $Servicio

    Write-Host 'Aplicando la nueva contrasena...'
    $mysqld = Start-Process (Join-Path $BinDir 'mysqld.exe') -PassThru -WindowStyle Hidden `
        -ArgumentList "--defaults-file=`"$MyIni`"", "--init-file=`"$initSql`""

    $ok = $false
    for ($i = 0; $i -lt 60; $i++) {
        Start-Sleep -Seconds 1
        & (Join-Path $BinDir 'mysqladmin.exe') "--defaults-extra-file=$optFile" ping 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { $ok = $true; break }
        if ($mysqld.HasExited) { break }
    }
    if (-not $ok) { throw 'MySQL no acepto la nueva contrasena (revisa el log de errores en ProgramData\MySQL).' }

    & (Join-Path $BinDir 'mysqladmin.exe') "--defaults-extra-file=$optFile" shutdown
    $mysqld.WaitForExit(30000) | Out-Null
    $mysqld = $null
    Write-Host 'Contrasena de root cambiada.' -ForegroundColor Green
} finally {
    Remove-Item $initSql, $optFile -Force -ErrorAction SilentlyContinue
    if ($mysqld -and -not $mysqld.HasExited) { Stop-Process -Id $mysqld.Id -Force }
    Write-Host "Iniciando el servicio $Servicio..."
    Start-Service $Servicio
    Get-Service $Servicio | Format-Table Name, Status -AutoSize
}
