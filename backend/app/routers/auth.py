"""Inicio y cierre de sesión, con registro en bitacora_acceso."""
from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import BaseModel

from ..db import conexion, ejecutar, uno
from ..security import crear_token, usuario_actual, verificar_password

router = APIRouter(prefix="/api/auth", tags=["Autenticación"])


class LoginIn(BaseModel):
    usuario: str
    password: str


def _ip(request: Request) -> str | None:
    return request.client.host if request.client else None


@router.post("/login")
def login(datos: LoginIn, request: Request):
    nombre = datos.usuario.strip().lower()
    # El login usa el usuario de motor de mínimo privilegio (app_trabajador)
    with conexion() as con:
        u = uno(con, "SELECT id_usuario, nombre_usuario, nombres, apellidos, rol, estado, password_hash "
                     "FROM usuario WHERE nombre_usuario = %s", (nombre,))
        valido = u is not None and verificar_password(datos.password, u["password_hash"])
        if not valido or u["estado"] != "Activo":
            motivo = "Usuario inactivo" if valido else "Usuario o contraseña incorrectos"
            ejecutar(con, "INSERT INTO bitacora_acceso (id_usuario, nombre_usuario, resultado, ip, detalle) "
                          "VALUES (%s, %s, 'FALLIDO', %s, %s)",
                     (u["id_usuario"] if u else None, nombre[:40], _ip(request), motivo))
            raise HTTPException(status.HTTP_401_UNAUTHORIZED, motivo)

        ejecutar(con, "UPDATE usuario SET ultimo_acceso = NOW() WHERE id_usuario = %s", (u["id_usuario"],))
        ejecutar(con, "INSERT INTO bitacora_acceso (id_usuario, nombre_usuario, resultado, ip) "
                      "VALUES (%s, %s, 'OK', %s)", (u["id_usuario"], nombre, _ip(request)))

    return {
        "token": crear_token(u),
        "usuario": {
            "id": u["id_usuario"], "usuario": u["nombre_usuario"], "rol": u["rol"],
            "nombre": f'{u["nombres"]} {u["apellidos"]}',
        },
    }


@router.post("/logout")
def logout(request: Request, usuario: dict = Depends(usuario_actual)):
    with conexion() as con:
        ejecutar(con, "INSERT INTO bitacora_acceso (id_usuario, nombre_usuario, resultado, ip) "
                      "VALUES (%s, %s, 'LOGOUT', %s)", (usuario["id"], usuario["usuario"], _ip(request)))
    return {"ok": True}


@router.get("/me")
def me(usuario: dict = Depends(usuario_actual)):
    return usuario
