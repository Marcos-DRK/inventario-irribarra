# =====================================================================
# Instala (o reinstala desde cero) la base de datos inventario_irribarra.
#   - Genera las contraseñas de los usuarios de conexión app_admin y
#     app_trabajador (o reutiliza las de backend\.env si ya existen).
#   - Escribe backend\.env para la API.
#   - Pide la contraseña de root UNA vez y ejecuta instalar.sql.
#
# Uso:  powershell -ExecutionPolicy Bypass -File db\instalar.ps1
# =====================================================================
param(
    [string]$MysqlExe = 'C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe',
    [string]$DbHost   = '127.0.0.1',
    [int]   $Port     = 3306,
    [string]$RootUser = 'root',
    [switch]$SinPassword   # solo para pruebas con un servidor sin contraseña de root
)
$ErrorActionPreference = 'Stop'

$dbDir   = $PSScriptRoot
$envFile = Join-Path (Split-Path $dbDir -Parent) 'backend\.env'

function Nueva-Clave {
    $letras = -join ((65..90) + (97..122) | Get-Random -Count 10 | ForEach-Object { [char]$_ })
    $nums   = -join (1..6 | ForEach-Object { Get-Random -Minimum 0 -Maximum 10 })
    return "$letras-$nums" + '_Ti'
}

# Reutilizar contraseñas existentes para no romper una API ya configurada
$cfg = @{}
if (Test-Path $envFile) {
    Get-Content $envFile | Where-Object { $_ -match '^\s*([A-Z_]+)\s*=\s*(.*)$' } |
        ForEach-Object { $cfg[$Matches[1]] = $Matches[2].Trim() }
}
$pwAdmin = if ($cfg['DB_ADMIN_PASSWORD']) { $cfg['DB_ADMIN_PASSWORD'] } else { Nueva-Clave }
$pwTrab  = if ($cfg['DB_TRAB_PASSWORD'])  { $cfg['DB_TRAB_PASSWORD'] }  else { Nueva-Clave }
$jwt     = if ($cfg['JWT_SECRET'])        { $cfg['JWT_SECRET'] }        else { [guid]::NewGuid().ToString('N') + [guid]::NewGuid().ToString('N') }

New-Item -ItemType Directory -Force (Split-Path $envFile) | Out-Null
@"
DB_HOST=$DbHost
DB_PORT=$Port
DB_NAME=inventario_irribarra
DB_ADMIN_USER=app_admin
DB_ADMIN_PASSWORD=$pwAdmin
DB_TRAB_USER=app_trabajador
DB_TRAB_PASSWORD=$pwTrab
JWT_SECRET=$jwt
"@ | Set-Content -Encoding ascii $envFile
Write-Host "Configuracion de la API escrita en $envFile"

# Archivo temporal con las claves de los usuarios de conexion (se borra al terminar)
$tmpSql = Join-Path $dbDir '_instalar_tmp.sql'
"SET @pw_app_admin='$pwAdmin';`r`nSET @pw_app_trabajador='$pwTrab';`r`nSOURCE instalar.sql`r`n" |
    Set-Content -Encoding ascii $tmpSql

# Credenciales de root en un archivo de opciones temporal (no quedan en la linea de comandos)
$rootPw = ''
if (-not $SinPassword) {
    $sec = Read-Host "Contrasena de '$RootUser' de MySQL" -AsSecureString
    $rootPw = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
}
# En los archivos de opciones de MySQL, \ y " dentro de comillas deben escaparse
$rootPw = $rootPw.Replace('\', '\\').Replace('"', '\"')
$optFile = Join-Path $dbDir '_root_tmp.cnf'
"[client]`r`nuser=$RootUser`r`npassword=`"$rootPw`"`r`nhost=$DbHost`r`nport=$Port`r`n" |
    Set-Content -Encoding ascii $optFile
$rootPw = $null

Push-Location $dbDir
try {
    cmd /c "`"$MysqlExe`" --defaults-extra-file=_root_tmp.cnf --default-character-set=utf8mb4 < _instalar_tmp.sql"
    if ($LASTEXITCODE -ne 0) { throw "mysql termino con codigo $LASTEXITCODE (revisa el mensaje de error de arriba)" }
    Write-Host "Instalacion terminada." -ForegroundColor Green
} finally {
    Remove-Item $tmpSql, $optFile -Force -ErrorAction SilentlyContinue
    Pop-Location
}
