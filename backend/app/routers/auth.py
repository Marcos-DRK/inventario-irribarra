"""Inicio y cierre de sesión, con registro en bitacora_acceso."""
import time

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


# Bloqueo por intentos fallidos: tras MAX_INTENTOS errores seguidos el usuario queda
# bloqueado BLOQUEO_SEGUNDOS. Vive en memoria (se reinicia al reiniciar la API); cada
# intento fallido igual queda en bitacora_acceso.
MAX_INTENTOS = 5
BLOQUEO_SEGUNDOS = 300
_fallos: dict[str, tuple[int, float]] = {}      # usuario -> (intentos, bloqueado_hasta)


def _segundos_bloqueado(nombre: str) -> int:
    intentos, hasta = _fallos.get(nombre, (0, 0.0))
    restante = hasta - time.monotonic()
    if restante > 0:
        return int(restante) + 1
    if hasta:                                   # el bloqueo ya venció
        _fallos.pop(nombre, None)
    return 0


def _registrar_fallo(nombre: str) -> None:
    intentos, _ = _fallos.get(nombre, (0, 0.0))
    intentos += 1
    hasta = time.monotonic() + BLOQUEO_SEGUNDOS if intentos >= MAX_INTENTOS else 0.0
    _fallos[nombre] = (intentos, hasta)


@router.post("/login")
def login(datos: LoginIn, request: Request):
    nombre = datos.usuario.strip().lower()
    # El login usa el usuario de motor de mínimo privilegio (app_trabajador)
    with conexion() as con:
        espera = _segundos_bloqueado(nombre)
        if espera:
            ejecutar(con, "INSERT INTO bitacora_acceso (id_usuario, nombre_usuario, resultado, ip, detalle) "
                          "VALUES (NULL, %s, 'FALLIDO', %s, 'Cuenta bloqueada temporalmente')",
                     (nombre[:40], _ip(request)))
            raise HTTPException(status.HTTP_429_TOO_MANY_REQUESTS,
                                f"Demasiados intentos fallidos. Intente de nuevo en {-(-espera // 60)} min")

        u = uno(con, "SELECT id_usuario, nombre_usuario, nombres, apellidos, rol, estado, password_hash "
                     "FROM usuario WHERE nombre_usuario = %s", (nombre,))
        valido = u is not None and verificar_password(datos.password, u["password_hash"])
        if not valido or u["estado"] != "Activo":
            motivo = "Usuario inactivo" if valido else "Usuario o contraseña incorrectos"
            ejecutar(con, "INSERT INTO bitacora_acceso (id_usuario, nombre_usuario, resultado, ip, detalle) "
                          "VALUES (%s, %s, 'FALLIDO', %s, %s)",
                     (u["id_usuario"] if u else None, nombre[:40], _ip(request), motivo))
            _registrar_fallo(nombre)
            raise HTTPException(status.HTTP_401_UNAUTHORIZED, motivo)
        _fallos.pop(nombre, None)

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
