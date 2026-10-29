"""Configuración leída desde backend/.env (lo genera db/instalar.ps1)."""
import os
from pathlib import Path

ENV_FILE = Path(__file__).resolve().parent.parent / ".env"


def _leer_env(ruta: Path) -> dict[str, str]:
    valores: dict[str, str] = {}
    if ruta.exists():
        for linea in ruta.read_text(encoding="utf-8").splitlines():
            linea = linea.strip()
            if linea and not linea.startswith("#") and "=" in linea:
                clave, valor = linea.split("=", 1)
                valores[clave.strip()] = valor.strip()
    return valores


_env = {**_leer_env(Path(os.environ.get("INVENTARIO_ENV", ENV_FILE))), **os.environ}

DB_HOST = _env.get("DB_HOST", "127.0.0.1")
DB_PORT = int(_env.get("DB_PORT", "3306"))
DB_NAME = _env.get("DB_NAME", "inventario_irribarra")
DB_ADMIN_USER = _env.get("DB_ADMIN_USER", "app_admin")
DB_ADMIN_PASSWORD = _env.get("DB_ADMIN_PASSWORD", "")
DB_TRAB_USER = _env.get("DB_TRAB_USER", "app_trabajador")
DB_TRAB_PASSWORD = _env.get("DB_TRAB_PASSWORD", "")

JWT_SECRET = _env.get("JWT_SECRET", "cambiar-este-secreto")
JWT_HORAS = int(_env.get("JWT_HORAS", "8"))

CORS_ORIGINS = _env.get("CORS_ORIGINS", "http://localhost:4200,http://127.0.0.1:4200").split(",")
