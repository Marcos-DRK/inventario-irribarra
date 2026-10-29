"""Contraseñas bcrypt, tokens JWT y dependencias de autorización por rol."""
from datetime import datetime, timedelta, timezone

import bcrypt
import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from . import config

_bearer = HTTPBearer(auto_error=False)


def hash_password(clave: str) -> str:
    return bcrypt.hashpw(clave.encode("utf-8"), bcrypt.gensalt(12)).decode("ascii")


def verificar_password(clave: str, hash_guardado: str) -> bool:
    try:
        return bcrypt.checkpw(clave.encode("utf-8"), hash_guardado.encode("ascii"))
    except ValueError:
        return False


def crear_token(usuario: dict) -> str:
    ahora = datetime.now(timezone.utc)
    payload = {
        "sub": str(usuario["id_usuario"]),
        "usr": usuario["nombre_usuario"],
        "rol": usuario["rol"],
        "nom": f'{usuario["nombres"]} {usuario["apellidos"]}',
        "iat": ahora,
        "exp": ahora + timedelta(hours=config.JWT_HORAS),
    }
    return jwt.encode(payload, config.JWT_SECRET, algorithm="HS256")


def usuario_actual(cred: HTTPAuthorizationCredentials | None = Depends(_bearer)) -> dict:
    if cred is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Debe iniciar sesión")
    try:
        datos = jwt.decode(cred.credentials, config.JWT_SECRET, algorithms=["HS256"])
    except jwt.ExpiredSignatureError:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "La sesión expiró, vuelva a ingresar")
    except jwt.InvalidTokenError:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Sesión inválida")
    return {"id": int(datos["sub"]), "usuario": datos["usr"], "rol": datos["rol"], "nombre": datos["nom"]}


def solo_admin(usuario: dict = Depends(usuario_actual)) -> dict:
    if usuario["rol"] != "Administrador":
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Acción reservada al Administrador")
    return usuario
