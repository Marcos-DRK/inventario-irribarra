"""Administración: usuarios (CRUD con baja lógica), clientes y bitácoras."""
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from ..db import conexion, consultar, ejecutar, uno
from ..security import hash_password, solo_admin

router = APIRouter(prefix="/api", tags=["Administración"])

_CAMPOS_USUARIO = ("id_usuario, rut, nombres, apellidos, correo, nombre_usuario, rol, estado, "
                   "fecha_creacion, ultimo_acceso")


# ---------------------------------------------------------------------
# Usuarios
# ---------------------------------------------------------------------
@router.get("/usuarios")
def listar_usuarios(usuario: dict = Depends(solo_admin)):
    with conexion(usuario) as con:
        return consultar(con, f"SELECT {_CAMPOS_USUARIO} FROM usuario ORDER BY rol, nombres")


class UsuarioBase(BaseModel):
    rut: str = Field(..., max_length=12)
    nombres: str = Field(..., max_length=80)
    apellidos: str = Field(..., max_length=80)
    correo: str = Field(..., max_length=120, pattern=r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
    rol: Literal["Administrador", "Trabajador"]


class UsuarioNuevoIn(UsuarioBase):
    nombre_usuario: str = Field(..., min_length=3, max_length=40, pattern=r"^[a-z0-9._-]+$")
    password: str = Field(..., min_length=8)


class UsuarioEditarIn(UsuarioBase):
    estado: Literal["Activo", "Inactivo"]


class PasswordIn(BaseModel):
    password: str = Field(..., min_length=8)


@router.post("/usuarios", status_code=201)
def crear_usuario(datos: UsuarioNuevoIn, usuario: dict = Depends(solo_admin)):
    with conexion(usuario) as con:
        _, nuevo = ejecutar(con, "INSERT INTO usuario (rut, nombres, apellidos, correo, nombre_usuario, "
                                 "password_hash, rol) VALUES (%s, %s, %s, %s, %s, %s, %s)",
                            (datos.rut, datos.nombres, datos.apellidos, datos.correo.lower(),
                             datos.nombre_usuario, hash_password(datos.password), datos.rol))
        return uno(con, f"SELECT {_CAMPOS_USUARIO} FROM usuario WHERE id_usuario = %s", (nuevo,))


@router.put("/usuarios/{id_usuario}")
def editar_usuario(id_usuario: int, datos: UsuarioEditarIn, usuario: dict = Depends(solo_admin)):
    if id_usuario == usuario["id"] and (datos.rol != "Administrador" or datos.estado != "Activo"):
        raise HTTPException(400, "No puede quitarse el rol de Administrador ni desactivarse a sí mismo")
    with conexion(usuario) as con:
        ejecutar(con, "UPDATE usuario SET rut=%s, nombres=%s, apellidos=%s, correo=%s, rol=%s, estado=%s "
                      "WHERE id_usuario=%s",
                 (datos.rut, datos.nombres, datos.apellidos, datos.correo.lower(), datos.rol, datos.estado,
                  id_usuario))
        u = uno(con, f"SELECT {_CAMPOS_USUARIO} FROM usuario WHERE id_usuario = %s", (id_usuario,))
    if not u:
        raise HTTPException(404, "Usuario no encontrado")
    return u


@router.patch("/usuarios/{id_usuario}/password")
def cambiar_password(id_usuario: int, datos: PasswordIn, usuario: dict = Depends(solo_admin)):
    with conexion(usuario) as con:
        filas, _ = ejecutar(con, "UPDATE usuario SET password_hash = %s WHERE id_usuario = %s",
                            (hash_password(datos.password), id_usuario))
    if not filas:
        raise HTTPException(404, "Usuario no encontrado")
    return {"ok": True}


@router.delete("/usuarios/{id_usuario}")
def desactivar_usuario(id_usuario: int, usuario: dict = Depends(solo_admin)):
    """Las cuentas no se borran (conservan su historial): se desactivan."""
    if id_usuario == usuario["id"]:
        raise HTTPException(400, "No puede desactivar su propia cuenta")
    with conexion(usuario) as con:
        ejecutar(con, "UPDATE usuario SET estado = 'Inactivo' WHERE id_usuario = %s", (id_usuario,))
    return {"ok": True}


# ---------------------------------------------------------------------
# Clientes
# ---------------------------------------------------------------------
@router.get("/clientes")
def clientes(usuario: dict = Depends(solo_admin)):
    with conexion(usuario) as con:
        return consultar(con, "SELECT c.*, COUNT(n.id_nota_venta) AS notas, COALESCE(SUM(n.monto_total), 0) AS total "
                              "FROM cliente c LEFT JOIN nota_venta n USING (id_cliente) "
                              "GROUP BY c.id_cliente ORDER BY c.apellidos")


# ---------------------------------------------------------------------
# Bitácoras
# ---------------------------------------------------------------------
@router.get("/bitacora/accesos")
def bitacora_accesos(limite: int = 200, usuario: dict = Depends(solo_admin)):
    with conexion(usuario) as con:
        return consultar(con, "SELECT * FROM bitacora_acceso ORDER BY id_acceso DESC LIMIT %s",
                         (min(max(limite, 1), 1000),))


@router.get("/bitacora/auditoria")
def bitacora_auditoria(tabla: str | None = None, limite: int = 200, usuario: dict = Depends(solo_admin)):
    sql, args = "SELECT * FROM bitacora_auditoria", []
    if tabla:
        sql += " WHERE tabla = %s"; args.append(tabla)
    sql += " ORDER BY id_auditoria DESC LIMIT %s"
    args.append(min(max(limite, 1), 1000))
    with conexion(usuario) as con:
        return consultar(con, sql, tuple(args))
