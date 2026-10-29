"""API del Sistema de Gestión de Inventario Taller Irribarra.

Ejecutar:  uvicorn app.main:app --port 8000   (desde la carpeta backend)
Documentación interactiva: http://localhost:8000/docs
Si existe la web construida (frontend/dist), también se sirve en http://localhost:8000
"""
import logging
from pathlib import Path

import pymysql
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse

from . import config
from .routers import admin, auth, inventario, operacion, reportes

log = logging.getLogger("inventario")

app = FastAPI(
    title="Inventario Taller Irribarra",
    description="API del Sistema de Gestión de Inventario (Saunas · Tinas · Wellness). "
                "Use **POST /api/auth/login** y el botón *Authorize* con el token recibido.",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=config.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["Content-Disposition"],
)

# Códigos de error de MySQL -> respuesta HTTP entendible para la interfaz
_ERRORES_MYSQL = {
    1644: (400, None),                                                   # SIGNAL de triggers/procedimientos
    1142: (403, "Su rol no tiene permiso para esta operación en la base de datos"),
    1143: (403, "Su rol no tiene permiso para esta operación en la base de datos"),
    1370: (403, "Su rol no tiene permiso para ejecutar este procedimiento"),
    1062: (409, "Ya existe un registro con ese valor único"),
    1451: (409, "No se puede eliminar: el registro está en uso"),
    1452: (400, "Referencia inválida: el registro relacionado no existe"),
    3819: (400, "El valor no cumple las reglas de la base de datos (por ejemplo, stock negativo)"),
    1048: (400, "Falta un dato obligatorio"),
    3140: (400, "JSON inválido"),
}


@app.exception_handler(pymysql.MySQLError)
async def error_mysql(_: Request, exc: pymysql.MySQLError):
    codigo = exc.args[0] if exc.args else 0
    mensaje_bd = exc.args[1] if len(exc.args) > 1 else str(exc)
    if codigo in _ERRORES_MYSQL:
        estado, mensaje = _ERRORES_MYSQL[codigo]
        return JSONResponse({"detail": mensaje or mensaje_bd, "codigo_mysql": codigo}, status_code=estado)
    if isinstance(exc, pymysql.err.OperationalError) and codigo in (2003, 1045, 1049):
        log.error("Sin conexión a MySQL: %s", mensaje_bd)
        return JSONResponse({"detail": "No hay conexión con la base de datos"}, status_code=503)
    log.exception("Error MySQL no controlado")
    return JSONResponse({"detail": f"Error de base de datos ({codigo})"}, status_code=500)


app.include_router(auth.router)
app.include_router(operacion.router)
app.include_router(inventario.router)
app.include_router(admin.router)
app.include_router(reportes.router)


@app.get("/api/salud", tags=["Sistema"])
def salud():
    from .db import conexion, uno
    with conexion() as con:
        fila = uno(con, "SELECT VERSION() AS version, DATABASE() AS base")
    return {"estado": "ok", **fila}


# ---------------------------------------------------------------------
# Interfaz web construida con `ng build` (frontend/construir.ps1).
# Va al final para que /api, /docs y /openapi.json tengan prioridad.
# ---------------------------------------------------------------------
WEB = Path(__file__).resolve().parents[2] / "frontend" / "dist" / "frontend" / "browser"

if WEB.is_dir():
    @app.get("/{ruta:path}", include_in_schema=False)
    def web(ruta: str):
        if ruta.startswith("api/"):
            raise HTTPException(404, "Ruta de API inexistente")
        archivo = (WEB / ruta).resolve()
        if ruta and archivo.is_file() and archivo.is_relative_to(WEB):
            return FileResponse(archivo)
        # Rutas de Angular (/dashboard, /comandas, ...) -> index.html
        return FileResponse(WEB / "index.html")
