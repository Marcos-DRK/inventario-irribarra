# =====================================================================
# Inicia la API en http://localhost:8000  (documentacion en /docs)
# La primera vez crea el entorno virtual e instala las dependencias.
#
# Uso:  powershell -ExecutionPolicy Bypass -File backend\iniciar_api.ps1
# =====================================================================
param(
    # Ruta corta fuera del proyecto: Windows limita las rutas a 260 caracteres
    [string]$Venv = (Join-Path $env:USERPROFILE '.inventario-irribarra\venv'),
    [int]$Puerto = 8000
)
$ErrorActionPreference = 'Stop'
$backend = $PSScriptRoot
$py = Join-Path $Venv 'Scripts\python.exe'

if (-not (Test-Path (Join-Path $backend '.env'))) {
    throw 'Falta backend\.env: primero ejecuta db\instalar.ps1'
}

if (-not (Test-Path $py)) {
    Write-Host "Creando entorno virtual en $Venv ..."
    python -m venv $Venv
    & $py -m pip install --disable-pip-version-check -q -r (Join-Path $backend 'requirements.txt')
}

Push-Location $backend
try {
    Write-Host "API en http://localhost:$Puerto  (documentacion: http://localhost:$Puerto/docs)" -ForegroundColor Green
    & $py -m uvicorn app.main:app --host 127.0.0.1 --port $Puerto
} finally {
    Pop-Location
}
