"""Inventario: materiales, kardex, productos/recetas, compras, mermas y alertas."""
from datetime import date
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from ..db import conexion, consultar, ejecutar, llamar, uno
from ..security import solo_admin, usuario_actual

router = APIRouter(prefix="/api", tags=["Inventario"])

TipoMaterial = Literal["Madera", "Ferreteria", "Equipamiento", "Accesorio"]
Unidad = Literal["un", "m", "m2", "m3", "kg", "L", "caja", "paquete", "bolsa", "tira", "tablon", "placa"]


# ---------------------------------------------------------------------
# Catálogos simples
# ---------------------------------------------------------------------
@router.get("/bodegas")
def bodegas(usuario: dict = Depends(usuario_actual)):
    with conexion(usuario) as con:
        return consultar(con, "SELECT * FROM bodega ORDER BY id_bodega")


@router.get("/proveedores")
def proveedores(usuario: dict = Depends(usuario_actual)):
    with conexion(usuario) as con:
        return consultar(con, "SELECT * FROM proveedor ORDER BY razon_social")


class ProveedorIn(BaseModel):
    rut: str = Field(..., max_length=12)
    razon_social: str
    telefono: str | None = None
    correo: str | None = None
    direccion: str | None = None


@router.post("/proveedores", status_code=201)
def crear_proveedor(datos: ProveedorIn, usuario: dict = Depends(solo_admin)):
    with conexion(usuario) as con:
        _, nuevo = ejecutar(con, "INSERT INTO proveedor (rut, razon_social, telefono, correo, direccion) "
                                 "VALUES (%(rut)s, %(razon_social)s, %(telefono)s, %(correo)s, %(direccion)s)",
                            datos.model_dump())
        return uno(con, "SELECT * FROM proveedor WHERE id_proveedor = %s", (nuevo,))


# ---------------------------------------------------------------------
# Materiales e insumos
# ---------------------------------------------------------------------
@router.get("/materiales")
def listar_materiales(id_bodega: int | None = None, tipo: str | None = None, buscar: str | None = None,
                      estado: str | None = None, usuario: dict = Depends(usuario_actual)):
    condiciones, args = [], []
    if id_bodega:
        condiciones.append("id_bodega = %s"); args.append(id_bodega)
    if tipo:
        condiciones.append("tipo = %s"); args.append(tipo)
    if estado:
        condiciones.append("estado_stock = %s"); args.append(estado)
    if buscar:
        condiciones.append("(nombre LIKE %s OR codigo_interno LIKE %s)")
        args += [f"%{buscar}%", f"%{buscar}%"]
    sql = "SELECT * FROM v_inventario_estado"
    if condiciones:
        sql += " WHERE " + " AND ".join(condiciones)
    sql += " ORDER BY FIELD(estado_stock,'Sin stock','Critico','Bajo','OK'), codigo_interno"
    with conexion(usuario) as con:
        return consultar(con, sql, tuple(args))


@router.get("/materiales/{id_material}")
def obtener_material(id_material: int, usuario: dict = Depends(usuario_actual)):
    with conexion(usuario) as con:
        m = uno(con, "SELECT v.*, m.id_proveedor_principal FROM v_inventario_estado v "
                     "JOIN material m USING (id_material) WHERE v.id_material = %s", (id_material,))
        if not m:
            raise HTTPException(404, "Material no encontrado")
        m["usado_en"] = consultar(con, "SELECT p.codigo_sku, p.nombre, r.cantidad_requerida "
                                       "FROM receta_producto r JOIN producto p USING (id_producto) "
                                       "WHERE r.id_material = %s", (id_material,))
    return m


class MaterialIn(BaseModel):
    codigo_interno: str = Field(..., max_length=20)
    nombre: str = Field(..., max_length=100)
    tipo: TipoMaterial
    unidad_medida: Unidad
    stock_minimo: float = Field(0, ge=0)
    costo_unitario: float = Field(0, ge=0)
    id_bodega: int
    id_proveedor_principal: int | None = None


class MaterialNuevoIn(MaterialIn):
    stock_inicial: float = Field(0, ge=0)


@router.post("/materiales", status_code=201)
def crear_material(datos: MaterialNuevoIn, usuario: dict = Depends(solo_admin)):
    """Dar de alta un material. El stock inicial queda en el kardex como CARGA_INICIAL."""
    with conexion(usuario) as con:
        valores = datos.model_dump(exclude={"stock_inicial"})
        _, nuevo = ejecutar(con, "INSERT INTO material (codigo_interno, nombre, tipo, unidad_medida, stock_minimo, "
                                 "costo_unitario, id_bodega, id_proveedor_principal) VALUES "
                                 "(%(codigo_interno)s, %(nombre)s, %(tipo)s, %(unidad_medida)s, %(stock_minimo)s, "
                                 "%(costo_unitario)s, %(id_bodega)s, %(id_proveedor_principal)s)", valores)
        if datos.stock_inicial > 0:
            llamar(con, "sp_ajustar_stock", (nuevo, datos.stock_inicial, "CARGA_INICIAL", "Alta de material",
                                             usuario["id"]))
        return uno(con, "SELECT * FROM v_inventario_estado WHERE id_material = %s", (nuevo,))


@router.put("/materiales/{id_material}")
def editar_material(id_material: int, datos: MaterialIn, usuario: dict = Depends(solo_admin)):
    """Edita los datos del material. El stock NO se cambia aquí (use ajuste o factura)."""
    with conexion(usuario) as con:
        filas, _ = ejecutar(con, "UPDATE material SET codigo_interno=%(codigo_interno)s, nombre=%(nombre)s, "
                                 "tipo=%(tipo)s, unidad_medida=%(unidad_medida)s, stock_minimo=%(stock_minimo)s, "
                                 "costo_unitario=%(costo_unitario)s, id_bodega=%(id_bodega)s, "
                                 "id_proveedor_principal=%(id_proveedor_principal)s WHERE id_material=%(id)s",
                            {**datos.model_dump(), "id": id_material})
        m = uno(con, "SELECT * FROM v_inventario_estado WHERE id_material = %s", (id_material,))
    if not m:
        raise HTTPException(404, "Material no encontrado")
    return m


@router.delete("/materiales/{id_material}")
def desactivar_material(id_material: int, usuario: dict = Depends(solo_admin)):
    """Baja lógica: el material deja de aparecer en el inventario (se conserva su historial)."""
    with conexion(usuario) as con:
        en_receta = uno(con, "SELECT COUNT(*) AS n FROM receta_producto r JOIN producto p USING (id_producto) "
                             "WHERE r.id_material = %s AND p.estado = 'Activo'", (id_material,))
        if en_receta["n"]:
            raise HTTPException(409, "No se puede dar de baja: el material está en una receta activa")
        ejecutar(con, "UPDATE material SET activo = 0 WHERE id_material = %s", (id_material,))
    return {"ok": True}


class AjusteIn(BaseModel):
    nuevo_stock: float = Field(..., ge=0)
    tipo: Literal["AJUSTE", "CARGA_INICIAL"] = "AJUSTE"
    motivo: str = Field("Conteo físico", max_length=60)


@router.post("/materiales/{id_material}/ajuste")
def ajustar_stock(id_material: int, datos: AjusteIn, usuario: dict = Depends(usuario_actual)):
    """Conteo físico / carga inicial. Queda registrado en el kardex con la diferencia."""
    with conexion(usuario) as con:
        llamar(con, "sp_ajustar_stock", (id_material, datos.nuevo_stock, datos.tipo, datos.motivo, usuario["id"]))
        return uno(con, "SELECT * FROM v_inventario_estado WHERE id_material = %s", (id_material,))


@router.get("/materiales/{id_material}/kardex")
def kardex(id_material: int, desde: date | None = None, hasta: date | None = None,
           usuario: dict = Depends(usuario_actual)):
    sql = "SELECT * FROM v_kardex WHERE id_material = %s"
    args: list = [id_material]
    if desde:
        sql += " AND fecha >= %s"; args.append(desde)
    if hasta:
        sql += " AND fecha < DATE_ADD(%s, INTERVAL 1 DAY)"; args.append(hasta)
    with conexion(usuario) as con:
        return consultar(con, sql + " ORDER BY fecha, id_movimiento", tuple(args))


# ---------------------------------------------------------------------
# Productos y recetas (el Administrador los crea y edita)
# ---------------------------------------------------------------------
@router.get("/productos")
def productos(usuario: dict = Depends(usuario_actual)):
    with conexion(usuario) as con:
        return consultar(con, "SELECT p.*, COUNT(r.id_receta) AS items_receta, "
                              "COALESCE(SUM(r.cantidad_requerida * m.costo_unitario), 0) AS costo_materiales "
                              "FROM producto p LEFT JOIN receta_producto r USING (id_producto) "
                              "LEFT JOIN material m ON m.id_material = r.id_material "
                              "GROUP BY p.id_producto ORDER BY p.nombre")


@router.get("/productos/{id_producto}")
def producto(id_producto: int, usuario: dict = Depends(usuario_actual)):
    with conexion(usuario) as con:
        p = uno(con, "SELECT * FROM producto WHERE id_producto = %s", (id_producto,))
        if not p:
            raise HTTPException(404, "Producto no encontrado")
        p["receta"] = consultar(con, """
            SELECT r.id_receta, r.cantidad_requerida, r.observacion,
                   v.id_material, v.codigo_interno, v.nombre AS material, v.tipo, v.unidad_medida,
                   v.stock_actual, v.disponible, v.costo_unitario,
                   r.cantidad_requerida * v.costo_unitario AS costo_linea,
                   FLOOR(GREATEST(v.disponible, 0) / r.cantidad_requerida) AS alcanza_para
              FROM receta_producto r JOIN v_inventario_estado v USING (id_material)
             WHERE r.id_producto = %s ORDER BY v.tipo, v.nombre""", (id_producto,))
    p["unidades_fabricables"] = min((int(l["alcanza_para"]) for l in p["receta"]), default=0)
    p["costo_materiales"] = sum(float(l["costo_linea"]) for l in p["receta"])
    return p


Categoria = Literal["Sauna_Ext", "Sauna_Int", "Tina", "Mueble", "Accesorio"]


class ProductoIn(BaseModel):
    codigo_sku: str = Field(..., min_length=1, max_length=30)
    nombre: str = Field(..., min_length=1, max_length=120)
    categoria: Categoria
    descripcion: str | None = Field(None, max_length=300)
    medidas: str | None = Field(None, max_length=80)
    precio_venta: float = Field(..., ge=0)
    tiempo_fabricacion_dias: int = Field(1, ge=1)
    estado: Literal["Activo", "Inactivo"] = "Activo"


@router.post("/productos", status_code=201)
def crear_producto(datos: ProductoIn, usuario: dict = Depends(solo_admin)):
    """Crea un producto (sin receta: se agregan los materiales después)."""
    with conexion(usuario) as con:
        _, nuevo = ejecutar(con, "INSERT INTO producto (codigo_sku, nombre, categoria, descripcion, medidas, "
                                 "precio_venta, tiempo_fabricacion_dias, estado) VALUES (%(codigo_sku)s, %(nombre)s, "
                                 "%(categoria)s, %(descripcion)s, %(medidas)s, %(precio_venta)s, "
                                 "%(tiempo_fabricacion_dias)s, %(estado)s)", datos.model_dump())
        return uno(con, "SELECT * FROM producto WHERE id_producto = %s", (nuevo,))


@router.put("/productos/{id_producto}")
def editar_producto(id_producto: int, datos: ProductoIn, usuario: dict = Depends(solo_admin)):
    """Edita el producto. Para retirarlo del catálogo se cambia el estado a Inactivo (no se borra)."""
    with conexion(usuario) as con:
        if not uno(con, "SELECT 1 AS x FROM producto WHERE id_producto = %s", (id_producto,)):
            raise HTTPException(404, "Producto no encontrado")
        ejecutar(con, "UPDATE producto SET codigo_sku=%(codigo_sku)s, nombre=%(nombre)s, categoria=%(categoria)s, "
                      "descripcion=%(descripcion)s, medidas=%(medidas)s, precio_venta=%(precio_venta)s, "
                      "tiempo_fabricacion_dias=%(tiempo_fabricacion_dias)s, estado=%(estado)s "
                      "WHERE id_producto=%(id)s", {**datos.model_dump(), "id": id_producto})
        return uno(con, "SELECT * FROM producto WHERE id_producto = %s", (id_producto,))


class RecetaIn(BaseModel):
    id_material: int
    cantidad_requerida: float = Field(..., gt=0)
    observacion: str | None = Field(None, max_length=120)


class RecetaCantidadIn(BaseModel):
    cantidad_requerida: float = Field(..., gt=0)
    observacion: str | None = Field(None, max_length=120)


@router.post("/productos/{id_producto}/receta", status_code=201)
def agregar_a_receta(id_producto: int, datos: RecetaIn, usuario: dict = Depends(solo_admin)):
    """Agrega un material a la receta. Aplica a las notas nuevas y a las comandas aún en espera."""
    with conexion(usuario) as con:
        if not uno(con, "SELECT 1 AS x FROM producto WHERE id_producto = %s", (id_producto,)):
            raise HTTPException(404, "Producto no encontrado")
        if not uno(con, "SELECT 1 AS x FROM material WHERE id_material = %s AND activo = 1", (datos.id_material,)):
            raise HTTPException(400, "El material no existe o está dado de baja")
        _, nuevo = ejecutar(con, "INSERT INTO receta_producto (id_producto, id_material, cantidad_requerida, observacion) "
                                 "VALUES (%s, %s, %s, %s)",
                            (id_producto, datos.id_material, datos.cantidad_requerida, datos.observacion))
    return {"id_receta": nuevo}


@router.put("/productos/{id_producto}/receta/{id_receta}")
def editar_linea_receta(id_producto: int, id_receta: int, datos: RecetaCantidadIn,
                        usuario: dict = Depends(solo_admin)):
    with conexion(usuario) as con:
        filas, _ = ejecutar(con, "UPDATE receta_producto SET cantidad_requerida = %s, observacion = %s "
                                 "WHERE id_receta = %s AND id_producto = %s",
                            (datos.cantidad_requerida, datos.observacion, id_receta, id_producto))
        if not filas and not uno(con, "SELECT 1 AS x FROM receta_producto WHERE id_receta = %s AND id_producto = %s",
                                 (id_receta, id_producto)):
            raise HTTPException(404, "Línea de receta no encontrada")
    return {"ok": True}


@router.delete("/productos/{id_producto}/receta/{id_receta}")
def quitar_de_receta(id_producto: int, id_receta: int, usuario: dict = Depends(solo_admin)):
    with conexion(usuario) as con:
        filas, _ = ejecutar(con, "DELETE FROM receta_producto WHERE id_receta = %s AND id_producto = %s",
                            (id_receta, id_producto))
        if not filas:
            raise HTTPException(404, "Línea de receta no encontrada")
    return {"ok": True}


# ---------------------------------------------------------------------
# Compras (facturas de proveedor)
# ---------------------------------------------------------------------
@router.get("/compras")
def listar_facturas(usuario: dict = Depends(usuario_actual)):
    with conexion(usuario) as con:
        return consultar(con, "SELECT f.*, p.razon_social, u.nombre_usuario AS registrado_por, "
                              "(SELECT COUNT(*) FROM detalle_factura_compra d WHERE d.id_factura = f.id_factura) AS lineas "
                              "FROM factura_compra f JOIN proveedor p USING (id_proveedor) "
                              "JOIN usuario u ON u.id_usuario = f.id_usuario_registro "
                              "ORDER BY f.fecha_ingreso DESC")


@router.get("/compras/{id_factura}")
def detalle_factura(id_factura: int, usuario: dict = Depends(usuario_actual)):
    with conexion(usuario) as con:
        f = uno(con, "SELECT f.*, p.razon_social, p.rut AS rut_proveedor FROM factura_compra f "
                     "JOIN proveedor p USING (id_proveedor) WHERE f.id_factura = %s", (id_factura,))
        if not f:
            raise HTTPException(404, "Factura no encontrada")
        f["detalles"] = consultar(con, "SELECT d.*, m.codigo_interno, m.nombre AS material, m.unidad_medida "
                                       "FROM detalle_factura_compra d JOIN material m USING (id_material) "
                                       "WHERE d.id_factura = %s", (id_factura,))
    return f


class LineaFacturaIn(BaseModel):
    id_material: int
    cantidad: float = Field(..., gt=0)
    costo_unitario: float = Field(..., ge=0)


class FacturaIn(BaseModel):
    numero_factura: str = Field(..., max_length=30)
    id_proveedor: int
    fecha_emision: date | None = None
    detalles: list[LineaFacturaIn] = Field(..., min_length=1)


@router.post("/compras", status_code=201)
def registrar_factura(datos: FacturaIn, usuario: dict = Depends(usuario_actual)):
    """Registra una factura de compra. El trigger suma el stock y resuelve las alertas cubiertas."""
    with conexion(usuario) as con:
        _, out = llamar(con, "sp_registrar_factura_json",
                        (datos.model_dump_json(exclude_none=True), usuario["id"]), salidas=1)
    return detalle_factura(out["o0"], usuario)


# ---------------------------------------------------------------------
# Mermas y sobrantes
# ---------------------------------------------------------------------
@router.get("/mermas")
def listar_mermas(estado: str | None = None, usuario: dict = Depends(usuario_actual)):
    sql, args = "SELECT * FROM v_mermas", ()
    if estado:
        sql, args = sql + " WHERE estado = %s", (estado,)
    with conexion(usuario) as con:
        return consultar(con, sql + " ORDER BY id_merma DESC", args)


@router.get("/mermas/parametros")
def parametros_merma(usuario: dict = Depends(usuario_actual)):
    with conexion(usuario) as con:
        return consultar(con, "SELECT * FROM parametro WHERE clave LIKE 'merma%'")


class MermaIn(BaseModel):
    id_material: int
    largo_cm: float = Field(..., gt=0)
    ancho_cm: float = Field(..., gt=0)
    espesor_cm: float = Field(..., gt=0)
    id_bodega: int = 1


@router.post("/mermas", status_code=201)
def registrar_merma(datos: MermaIn, usuario: dict = Depends(usuario_actual)):
    """Registra un retazo. El trigger decide si supera la medida mínima (si no, queda Descartado)."""
    with conexion(usuario) as con:
        _, nuevo = ejecutar(con, "INSERT INTO merma (id_material, largo_cm, ancho_cm, espesor_cm, id_bodega, "
                                 "id_usuario_registro) VALUES (%s, %s, %s, %s, %s, %s)",
                            (datos.id_material, datos.largo_cm, datos.ancho_cm, datos.espesor_cm,
                             datos.id_bodega, usuario["id"]))
        return uno(con, "SELECT * FROM v_mermas WHERE id_merma = %s", (nuevo,))


class AccionMermaIn(BaseModel):
    accion: Literal["reservar", "liberar", "descartar"]
    id_comanda: int | None = None


@router.patch("/mermas/{id_merma}")
def cambiar_merma(id_merma: int, datos: AccionMermaIn, usuario: dict = Depends(usuario_actual)):
    with conexion(usuario) as con:
        if datos.accion == "reservar":
            if not datos.id_comanda:
                raise HTTPException(400, "Indique la comanda para reservar el retazo")
            ejecutar(con, "UPDATE merma SET estado = 'Reservado', id_comanda_uso = %s WHERE id_merma = %s",
                     (datos.id_comanda, id_merma))
        elif datos.accion == "liberar":
            ejecutar(con, "UPDATE merma SET estado = 'Disponible' WHERE id_merma = %s AND estado = 'Reservado'",
                     (id_merma,))
        else:
            ejecutar(con, "UPDATE merma SET estado = 'Descartado', id_comanda_uso = NULL WHERE id_merma = %s",
                     (id_merma,))
        m = uno(con, "SELECT * FROM v_mermas WHERE id_merma = %s", (id_merma,))
    if not m:
        raise HTTPException(404, "Retazo no encontrado")
    return m


# ---------------------------------------------------------------------
# Alertas de stock
# ---------------------------------------------------------------------
@router.get("/alertas")
def listar_alertas(estado: str | None = "Pendiente", usuario: dict = Depends(usuario_actual)):
    sql, args = "SELECT * FROM v_alertas", ()
    if estado:
        sql, args = sql + " WHERE estado = %s", (estado,)
    with conexion(usuario) as con:
        return consultar(con, sql + " ORDER BY estado = 'Resuelta', fecha_alerta DESC", args)


@router.patch("/alertas/{id_alerta}/resolver")
def resolver_alerta(id_alerta: int, usuario: dict = Depends(solo_admin)):
    with conexion(usuario) as con:
        ejecutar(con, "UPDATE alerta_stock SET estado = 'Resuelta', fecha_resolucion = NOW() "
                      "WHERE id_alerta = %s AND estado = 'Pendiente'", (id_alerta,))
        a = uno(con, "SELECT * FROM v_alertas WHERE id_alerta = %s", (id_alerta,))
    if not a:
        raise HTTPException(404, "Alerta no encontrada")
    return a
