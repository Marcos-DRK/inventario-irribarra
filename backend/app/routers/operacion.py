"""Operación del taller: dashboard, notas de venta, integración y comandas (Kanban)."""
from datetime import date
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from ..db import conexion, consultar, ejecutar, llamar, uno
from ..security import solo_admin, usuario_actual

router = APIRouter(prefix="/api", tags=["Operación"])

ETAPAS = ["EnEspera", "Fabricacion", "Pintura", "QA", "Finalizado"]


# ---------------------------------------------------------------------
# Dashboard
# ---------------------------------------------------------------------
@router.get("/dashboard")
def dashboard(usuario: dict = Depends(usuario_actual)):
    with conexion(usuario) as con:
        kpis = uno(con, "SELECT * FROM v_dashboard_kpis")
        notas = consultar(con, "SELECT id_nota_venta, folio, cliente, productos, estado, monto_total "
                               "FROM v_notas_venta ORDER BY id_nota_venta DESC LIMIT 5")
        alertas = consultar(con, "SELECT id_alerta, tipo, material, unidad_medida, stock_disponible, "
                                 "stock_requerido, folio FROM v_alertas WHERE estado = 'Pendiente' "
                                 "ORDER BY fecha_alerta DESC LIMIT 6")
    return {"kpis": kpis, "notas_recientes": notas, "alertas": alertas}


# ---------------------------------------------------------------------
# Notas de venta
# ---------------------------------------------------------------------
@router.get("/notas-venta")
def listar_notas(estado: str | None = None, usuario: dict = Depends(usuario_actual)):
    sql = "SELECT * FROM v_notas_venta"
    args: tuple = ()
    if estado:
        sql += " WHERE estado = %s"
        args = (estado,)
    with conexion(usuario) as con:
        return consultar(con, sql + " ORDER BY fecha_venta DESC, id_nota_venta DESC", args)


@router.get("/notas-venta/siguiente-folio")
def siguiente_folio(usuario: dict = Depends(usuario_actual)):
    with conexion(usuario) as con:
        fila = uno(con, "SELECT COALESCE(MAX(CAST(folio AS UNSIGNED)), 1940) + 1 AS folio "
                        "FROM nota_venta WHERE folio REGEXP '^[0-9]+$'")
    return {"folio": str(fila["folio"])}


@router.get("/notas-venta/{id_nota}")
def detalle_nota(id_nota: int, usuario: dict = Depends(usuario_actual)):
    with conexion(usuario) as con:
        cab = uno(con, "SELECT n.*, c.direccion, c.comuna, c.telefono, c.correo "
                       "FROM v_notas_venta n JOIN cliente c USING (id_cliente) WHERE n.id_nota_venta = %s",
                  (id_nota,))
        if not cab:
            raise HTTPException(404, "Nota de venta no encontrada")
        detalles = consultar(con, "SELECT d.id_detalle, d.cantidad, d.precio_unitario, d.subtotal, "
                                  "d.diseno_personalizado, p.codigo_sku, p.nombre AS producto, "
                                  "c.id_comanda, c.estado AS estado_comanda "
                                  "FROM detalle_nota_venta d JOIN producto p USING (id_producto) "
                                  "LEFT JOIN comanda c ON c.id_detalle = d.id_detalle "
                                  "WHERE d.id_nota_venta = %s", (id_nota,))
        # Verificación de stock: requerido por la nota vs disponible
        # (stock actual menos lo comprometido por OTRAS comandas en espera)
        verificacion = consultar(con, """
            SELECT m.id_material, m.codigo_interno, m.nombre AS material, m.unidad_medida,
                   req.requerido, m.stock_actual,
                   m.stock_actual - COALESCE(otros.comprometido, 0) AS disponible
              FROM (SELECT r.id_material, SUM(r.cantidad_requerida * d.cantidad) AS requerido
                      FROM detalle_nota_venta d
                      JOIN receta_producto r ON r.id_producto = d.id_producto
                     WHERE d.id_nota_venta = %s
                     GROUP BY r.id_material) req
              JOIN material m ON m.id_material = req.id_material
              LEFT JOIN (SELECT r.id_material, SUM(r.cantidad_requerida * d.cantidad) AS comprometido
                           FROM comanda c
                           JOIN detalle_nota_venta d ON d.id_detalle = c.id_detalle
                           JOIN receta_producto r ON r.id_producto = d.id_producto
                          WHERE c.estado = 'EnEspera' AND d.id_nota_venta <> %s
                          GROUP BY r.id_material) otros ON otros.id_material = req.id_material
             ORDER BY (m.stock_actual - COALESCE(otros.comprometido, 0)) - req.requerido, m.nombre
        """, (id_nota, id_nota))
        alertas = consultar(con, "SELECT * FROM v_alertas WHERE id_nota_venta = %s ORDER BY id_alerta",
                            (id_nota,))

    ya_descontado = cab["estado"] in ("Aprobada", "Facturada") and any(
        d["estado_comanda"] and d["estado_comanda"] != "EnEspera" for d in detalles)
    for v in verificacion:
        if ya_descontado:
            v["estado"] = "Descontado"
        elif v["disponible"] < v["requerido"]:
            v["estado"] = "Falta"
        elif v["disponible"] == v["requerido"]:
            v["estado"] = "Justo"
        else:
            v["estado"] = "OK"
    faltantes = sum(1 for v in verificacion if v["estado"] == "Falta")
    return {"nota": cab, "detalles": detalles, "verificacion": verificacion,
            "insumos_faltantes": faltantes, "alertas": alertas}


@router.post("/notas-venta/{id_nota}/procesar")
def procesar_nota(id_nota: int, usuario: dict = Depends(solo_admin)):
    """Vuelve a verificar el stock y aprueba la nota si ya no hay faltantes."""
    with conexion(usuario) as con:
        _, out = llamar(con, "sp_procesar_nota_venta", (id_nota,), salidas=1)
    return {"id_nota_venta": id_nota, "estado": out["o0"]}


# ---------------------------------------------------------------------
# Integración con la plataforma web de ventas (JSON)
# ---------------------------------------------------------------------
class ClienteIn(BaseModel):
    rut: str = Field(..., max_length=12, examples=["9222333-4"])
    nombres: str
    apellidos: str
    direccion: str | None = None
    comuna: str | None = None
    telefono: str | None = None
    correo: str | None = None


class DetalleVentaIn(BaseModel):
    codigo_sku: str = Field(..., examples=["SAU-BAR-220"])
    cantidad: int = Field(..., gt=0)
    precio_unitario: float | None = Field(None, ge=0, description="Si se omite se usa el precio del catálogo")
    diseno_personalizado: str | None = None


class NotaVentaIn(BaseModel):
    folio: str = Field(..., max_length=20)
    fecha_venta: date | None = None
    fecha_despacho: date | None = None
    origen: Literal["Plataforma", "Manual"] = "Plataforma"
    cliente: ClienteIn
    detalles: list[DetalleVentaIn] = Field(..., min_length=1)


@router.post("/integracion/notas-venta", status_code=201)
def recibir_nota_venta(nota: NotaVentaIn, usuario: dict = Depends(solo_admin)):
    """Recibe una nota de venta desde la plataforma web (o el simulador).
    El procedimiento la registra, verifica el stock y la aprueba o rechaza en una sola transacción."""
    with conexion(usuario) as con:
        _, out = llamar(con, "sp_registrar_nota_venta_json",
                        (nota.model_dump_json(exclude_none=True), usuario["id"]), salidas=2)
    return {"id_nota_venta": out["o0"], "estado": out["o1"]}


# ---------------------------------------------------------------------
# Comandas (tablero Kanban)
# ---------------------------------------------------------------------
@router.get("/comandas")
def kanban(usuario: dict = Depends(usuario_actual)):
    with conexion(usuario) as con:
        filas = consultar(con, "SELECT * FROM v_kanban_comandas "
                               "ORDER BY FIELD(estado,'EnEspera','Fabricacion','Pintura','QA','Finalizado'), "
                               "fecha_despacho IS NULL, fecha_despacho, id_comanda")
    return {"etapas": ETAPAS, "comandas": filas}


@router.get("/comandas/trabajadores")
def trabajadores(usuario: dict = Depends(usuario_actual)):
    with conexion(usuario) as con:
        return consultar(con, "SELECT id_usuario, CONCAT(nombres, ' ', apellidos) AS nombre "
                              "FROM usuario WHERE rol = 'Trabajador' AND estado = 'Activo' ORDER BY nombres")


class EstadoComandaIn(BaseModel):
    estado: Literal["EnEspera", "Fabricacion", "Pintura", "QA", "Finalizado"]


@router.patch("/comandas/{id_comanda}/estado")
def mover_comanda(id_comanda: int, datos: EstadoComandaIn, usuario: dict = Depends(usuario_actual)):
    """Mueve la comanda en el Kanban. Al pasar a Fabricación el trigger descuenta el stock."""
    with conexion(usuario) as con:
        filas, _ = ejecutar(con, "UPDATE comanda SET estado = %s, "
                                 "id_trabajador_asignado = COALESCE(id_trabajador_asignado, %s) "
                                 "WHERE id_comanda = %s",
                            (datos.estado, usuario["id"] if usuario["rol"] == "Trabajador" else None, id_comanda))
        if not filas and not uno(con, "SELECT 1 AS x FROM comanda WHERE id_comanda = %s", (id_comanda,)):
            raise HTTPException(404, "Comanda no encontrada")
        return uno(con, "SELECT * FROM v_kanban_comandas WHERE id_comanda = %s", (id_comanda,))


class AsignarIn(BaseModel):
    id_trabajador: int | None


@router.patch("/comandas/{id_comanda}/asignar")
def asignar_comanda(id_comanda: int, datos: AsignarIn, usuario: dict = Depends(usuario_actual)):
    with conexion(usuario) as con:
        ejecutar(con, "UPDATE comanda SET id_trabajador_asignado = %s WHERE id_comanda = %s",
                 (datos.id_trabajador, id_comanda))
        return uno(con, "SELECT * FROM v_kanban_comandas WHERE id_comanda = %s", (id_comanda,))


@router.get("/comandas/{id_comanda}/mermas-sugeridas")
def mermas_sugeridas(id_comanda: int, usuario: dict = Depends(usuario_actual)):
    """Retazos disponibles compatibles con la receta (priorización de sobrantes)."""
    with conexion(usuario) as con:
        sugeridas, _ = llamar(con, "sp_sugerir_mermas", (id_comanda,))
        reservadas = consultar(con, "SELECT * FROM v_mermas WHERE id_comanda_uso = %s", (id_comanda,))
    return {"sugeridas": sugeridas, "reservadas": reservadas}
