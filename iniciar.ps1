# =====================================================================
# Inicia el sistema completo en http://localhost:8000
#   La API (FastAPI) sirve tambien la interfaz web ya construida.
#   La primera vez construye la interfaz (construir.ps1).
# Requisito: MySQL (servicio MySQL84) encendido y db\instalar.ps1 ejecutado una vez.
#
# Uso:  powershell -ExecutionPolicy Bypass -File iniciar.ps1
#       (para desarrollo con recarga automatica: cd frontend; npm start -> :4200)
# =====================================================================
$ErrorActionPreference = 'Stop'
$raiz = $PSScriptRoot

$mysql = Get-Service -Name 'MySQL84' -ErrorAction SilentlyContinue
if ($mysql -and $mysql.Status -ne 'Running') {
    Write-Host 'El servicio MySQL84 esta detenido: inicielo (services.msc) antes de continuar.' -ForegroundColor Yellow
}

if (-not (Test-Path (Join-Path $raiz 'frontend\dist\frontend\browser\index.html'))) {
    & (Join-Path $raiz 'construir.ps1')
}

# Abre el navegador cuando la API responda (en segundo plano)
Start-Job -ScriptBlock {
    for ($i = 0; $i -lt 120; $i++) {
        try { Invoke-WebRequest 'http://127.0.0.1:8000/api/salud' -UseBasicParsing -TimeoutSec 2 | Out-Null; break }
        catch { Start-Sleep -Seconds 1 }
    }
    Start-Process 'http://localhost:8000'
} | Out-Null

Write-Host 'Sistema en http://localhost:8000  (cierre esta ventana o presione Ctrl+C para detenerlo)' -ForegroundColor Green
& (Join-Path $raiz 'backend\iniciar_api.ps1')
