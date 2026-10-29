# =====================================================================
# Construye la interfaz web (Angular) para que la sirva la API.
#   Resultado: frontend\dist\frontend\browser
#   Hay que volver a ejecutarlo solo si se modifica el codigo del frontend.
#
# Uso:  powershell -ExecutionPolicy Bypass -File construir.ps1
# =====================================================================
$ErrorActionPreference = 'Stop'
$front = Join-Path $PSScriptRoot 'frontend'

Push-Location $front
try {
    if (-not (Test-Path 'node_modules')) {
        Write-Host 'Instalando dependencias de Angular (solo la primera vez, unos minutos)...'
        npm install --no-audit --no-fund
        if ($LASTEXITCODE -ne 0) { throw "npm install termino con codigo $LASTEXITCODE" }
    }
    Write-Host 'Construyendo la interfaz web...'
    npx ng build --configuration production
    if ($LASTEXITCODE -ne 0) { throw "ng build termino con codigo $LASTEXITCODE" }
    Write-Host 'Interfaz construida en frontend\dist\frontend\browser' -ForegroundColor Green
} finally {
    Pop-Location
}
