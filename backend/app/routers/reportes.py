"""Reportes: mensual (JSON + PDF), inventario (Excel) y kardex (Excel)."""
import re
from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import Response

from .. import archivos
from ..db import conexion, consultar, llamar, uno
from ..security import solo_admin, usuario_actual

router = APIRouter(prefix="/api/reportes", tags=["Reportes"])

_XLSX = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"


def _validar_periodo(periodo: str) -> str:
    if not re.fullmatch(r"\d{4}-(0[1-9]|1[0-2])", periodo):
        raise HTTPException(400, "Periodo inválido, use AAAA-MM")
    return periodo


def _descarga(contenido: bytes, tipo: str, nombre: str) -> Response:
    return Response(contenido, media_type=tipo,
                    headers={"Content-Disposition": f'attachment; filename="{nombre}"'})


def _datos_mensuales(con, periodo: str, usuario: dict) -> dict:
    """Consolida (y guarda en reporte_mensual) los datos del período."""
    resumen, _ = llamar(con, "sp_generar_reporte_mensual", (periodo, usuario["id"]))
    desde = f"{periodo}-01"
    return {
        "periodo": periodo,
        "generado_por": usuario["nombre"],
        "resumen": resumen[0],
        "por_categoria": consultar(con, "SELECT categoria, consumo FROM v_consumo_mensual_categoria "
                                        "WHERE periodo = %s ORDER BY consumo DESC", (periodo,)),
        "top_materiales": consultar(con, f"""
            SELECT m.codigo_interno, m.nombre AS material, m.unidad_medida,
                   SUM(-mv.cantidad) AS cantidad, SUM(-mv.cantidad * mv.costo_unitario) AS costo
              FROM movimiento_inventario mv JOIN material m USING (id_material)
             WHERE mv.tipo = 'SALIDA_FABRICACION' AND mv.fecha >= %s AND mv.fecha < DATE_ADD(%s, INTERVAL 1 MONTH)
             GROUP BY m.id_material ORDER BY costo DESC LIMIT 10""", (desde, desde)),
        "alertas": consultar(con, "SELECT * FROM v_alertas WHERE fecha_alerta >= %s "
                                  "AND fecha_alerta < DATE_ADD(%s, INTERVAL 1 MONTH) ORDER BY fecha_alerta",
                             (desde, desde)),
        "mermas": consultar(con, "SELECT * FROM v_mermas WHERE estado = 'Utilizado' AND fecha_uso >= %s "
                                 "AND fecha_uso < DATE_ADD(%s, INTERVAL 1 MONTH) ORDER BY fecha_uso",
                            (desde, desde)),
    }


@router.get("/periodos")
def periodos(usuario: dict = Depends(solo_admin)):
    """Meses con movimientos o reportes, del más reciente al más antiguo."""
    with conexion(usuario) as con:
        filas = consultar(con, "SELECT DISTINCT DATE_FORMAT(fecha, '%Y-%m') AS periodo FROM movimiento_inventario "
                               "UNION SELECT periodo FROM reporte_mensual "
                               "UNION SELECT DATE_FORMAT(CURDATE(), '%Y-%m') ORDER BY periodo DESC")
    return [f["periodo"] for f in filas]


@router.get("/mensual/{periodo}")
def reporte_mensual(periodo: str, usuario: dict = Depends(solo_admin)):
    with conexion(usuario) as con:
        return _datos_mensuales(con, _validar_periodo(periodo), usuario)


@router.get("/mensual/{periodo}/pdf")
def reporte_mensual_pdf(periodo: str, usuario: dict = Depends(solo_admin)):
    with conexion(usuario) as con:
        datos = _datos_mensuales(con, _validar_periodo(periodo), usuario)
    return _descarga(archivos.pdf_reporte_mensual(datos), "application/pdf",
                     f"reporte_mensual_{periodo}.pdf")


@router.get("/inventario/excel")
def inventario_excel(usuario: dict = Depends(usuario_actual)):
    with conexion(usuario) as con:
        materiales = consultar(con, "SELECT * FROM v_inventario_estado ORDER BY bodega, tipo, codigo_interno")
        alertas = consultar(con, "SELECT * FROM v_alertas WHERE estado = 'Pendiente' ORDER BY fecha_alerta DESC")
    return _descarga(archivos.excel_inventario(materiales, alertas, usuario["nombre"]), _XLSX,
                     f"inventario_{date.today():%Y-%m-%d}.xlsx")


@router.get("/kardex/{id_material}/excel")
def kardex_excel(id_material: int, usuario: dict = Depends(usuario_actual)):
    with conexion(usuario) as con:
        material = uno(con, "SELECT * FROM v_inventario_estado WHERE id_material = %s", (id_material,))
        if not material:
            raise HTTPException(404, "Material no encontrado")
        movimientos = consultar(con, "SELECT * FROM v_kardex WHERE id_material = %s ORDER BY fecha, id_movimiento",
                                (id_material,))
    return _descarga(archivos.excel_kardex(material, movimientos, usuario["nombre"]), _XLSX,
                     f"kardex_{material['codigo_interno']}.xlsx")
