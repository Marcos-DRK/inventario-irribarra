"""Conexión a MySQL con el usuario de motor que corresponde al rol.

Administrador -> app_admin (rol_administrador_bd)
Trabajador    -> app_trabajador (rol_trabajador_bd, mínimo privilegio)

En cada conexión se fijan @app_usuario y @app_id_usuario, que los
triggers usan para la bitácora de auditoría y el kardex.
"""
from contextlib import contextmanager
from typing import Any, Iterator

import pymysql
from pymysql.cursors import DictCursor

from . import config


def _conectar(perfil: str) -> pymysql.connections.Connection:
    if perfil == "admin":
        usuario, clave = config.DB_ADMIN_USER, config.DB_ADMIN_PASSWORD
    else:
        usuario, clave = config.DB_TRAB_USER, config.DB_TRAB_PASSWORD
    return pymysql.connect(
        host=config.DB_HOST, port=config.DB_PORT, database=config.DB_NAME,
        user=usuario, password=clave, charset="utf8mb4",
        cursorclass=DictCursor, autocommit=True,
    )


@contextmanager
def conexion(usuario: dict | None = None) -> Iterator[pymysql.connections.Connection]:
    """Abre una conexión según el rol del usuario autenticado (o de trabajador si no hay)."""
    perfil = "admin" if usuario and usuario["rol"] == "Administrador" else "trab"
    con = _conectar(perfil)
    try:
        if usuario:
            with con.cursor() as cur:
                cur.execute("SET @app_usuario = %s, @app_id_usuario = %s",
                            (usuario["usuario"], usuario["id"]))
        yield con
    finally:
        con.close()


def consultar(con, sql: str, args: Any = None) -> list[dict]:
    with con.cursor() as cur:
        cur.execute(sql, args)
        return list(cur.fetchall())


def uno(con, sql: str, args: Any = None) -> dict | None:
    filas = consultar(con, sql, args)
    return filas[0] if filas else None


def ejecutar(con, sql: str, args: Any = None) -> tuple[int, int]:
    """Ejecuta INSERT/UPDATE/DELETE y devuelve (filas_afectadas, last_insert_id)."""
    with con.cursor() as cur:
        filas = cur.execute(sql, args)
        return filas, cur.lastrowid


def llamar(con, procedimiento: str, args: tuple = (), salidas: int = 0) -> tuple[list[dict], dict]:
    """CALL a un procedimiento. Devuelve (primer result set, valores OUT)."""
    marcas = ", ".join(["%s"] * len(args) + [f"@_out{i}" for i in range(salidas)])
    with con.cursor() as cur:
        cur.execute(f"CALL {procedimiento}({marcas})", args)
        filas = list(cur.fetchall())
        while cur.nextset():
            pass
        out: dict = {}
        if salidas:
            cur.execute("SELECT " + ", ".join(f"@_out{i} AS o{i}" for i in range(salidas)))
            out = cur.fetchone()
    return filas, out
