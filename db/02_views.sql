-- =====================================================================
-- 02_views.sql  ·  Vistas que alimentan las pantallas
-- =====================================================================
USE inventario_irribarra;

-- Material comprometido por comandas aprobadas que aún no entran a fabricación
CREATE OR REPLACE VIEW v_stock_comprometido AS
SELECT r.id_material,
       SUM(r.cantidad_requerida * d.cantidad) AS comprometido
FROM comanda c
JOIN detalle_nota_venta d ON d.id_detalle  = c.id_detalle
JOIN receta_producto r    ON r.id_producto = d.id_producto
WHERE c.estado = 'EnEspera'
GROUP BY r.id_material;

-- Pantalla "Materiales e Insumos"
CREATE OR REPLACE VIEW v_inventario_estado AS
SELECT m.id_material, m.codigo_interno, m.nombre, m.tipo, m.unidad_medida,
       m.stock_actual, m.stock_minimo, m.costo_unitario,
       COALESCE(sc.comprometido, 0)                  AS comprometido,
       m.stock_actual - COALESCE(sc.comprometido, 0) AS disponible,
       m.stock_actual * m.costo_unitario             AS valor_stock,
       b.id_bodega, b.nombre AS bodega,
       CASE
         WHEN m.stock_actual = 0                       THEN 'Sin stock'
         WHEN m.stock_actual < m.stock_minimo * 0.5    THEN 'Critico'
         WHEN m.stock_actual < m.stock_minimo          THEN 'Bajo'
         ELSE 'OK'
       END AS estado_stock,
       CASE WHEN m.stock_minimo = 0 THEN 100
            ELSE LEAST(100, ROUND(m.stock_actual / (m.stock_minimo * 2) * 100))
       END AS nivel_pct,
       m.fecha_actualizacion
FROM material m
JOIN bodega b ON b.id_bodega = m.id_bodega
LEFT JOIN v_stock_comprometido sc ON sc.id_material = m.id_material
WHERE m.activo = 1;

-- Pantalla "Notas de Venta" (lista)
CREATE OR REPLACE VIEW v_notas_venta AS
SELECT n.id_nota_venta, n.folio, n.fecha_venta, n.fecha_despacho, n.origen, n.estado, n.monto_total,
       c.id_cliente, c.rut AS cliente_rut,
       CONCAT(c.nombres, ' ', c.apellidos) AS cliente,
       (SELECT GROUP_CONCAT(p.nombre ORDER BY d.id_detalle SEPARATOR ', ')
          FROM detalle_nota_venta d JOIN producto p ON p.id_producto = d.id_producto
         WHERE d.id_nota_venta = n.id_nota_venta) AS productos,
       (SELECT COUNT(*) FROM alerta_stock a
         WHERE a.id_nota_venta = n.id_nota_venta AND a.estado = 'Pendiente') AS alertas_pendientes
FROM nota_venta n
JOIN cliente c ON c.id_cliente = n.id_cliente;

-- Pantalla "Comandas (taller)" — tablero Kanban
CREATE OR REPLACE VIEW v_kanban_comandas AS
SELECT c.id_comanda, c.estado, c.fecha_creacion, c.fecha_inicio, c.fecha_termino,
       n.id_nota_venta, n.folio, n.fecha_despacho,
       p.nombre AS producto, d.cantidad, d.diseno_personalizado,
       c.id_trabajador_asignado,
       CONCAT(u.nombres, ' ', u.apellidos) AS trabajador
FROM comanda c
JOIN detalle_nota_venta d ON d.id_detalle    = c.id_detalle
JOIN nota_venta n         ON n.id_nota_venta = d.id_nota_venta
JOIN producto p           ON p.id_producto   = d.id_producto
LEFT JOIN usuario u       ON u.id_usuario    = c.id_trabajador_asignado;

-- Kardex (historial de entradas y salidas)
CREATE OR REPLACE VIEW v_kardex AS
SELECT mv.id_movimiento, mv.fecha, mv.tipo, mv.cantidad, mv.stock_resultante,
       mv.costo_unitario, mv.referencia,
       m.id_material, m.codigo_interno, m.nombre AS material, m.unidad_medida,
       u.nombre_usuario AS usuario
FROM movimiento_inventario mv
JOIN material m      ON m.id_material = mv.id_material
LEFT JOIN usuario u  ON u.id_usuario  = mv.id_usuario;

-- Pantalla "Alertas de Stock"
CREATE OR REPLACE VIEW v_alertas AS
SELECT a.id_alerta, a.tipo, a.estado, a.fecha_alerta, a.fecha_resolucion,
       a.stock_disponible, a.stock_requerido,
       a.stock_requerido - a.stock_disponible AS faltante,
       m.id_material, m.codigo_interno, m.nombre AS material, m.unidad_medida, m.stock_actual,
       a.id_nota_venta, n.folio
FROM alerta_stock a
JOIN material m        ON m.id_material   = a.id_material
LEFT JOIN nota_venta n ON n.id_nota_venta = a.id_nota_venta;

-- Pantalla "Mermas y Sobrantes"
CREATE OR REPLACE VIEW v_mermas AS
SELECT me.id_merma, me.largo_cm, me.ancho_cm, me.espesor_cm, me.supera_minimo, me.valor_estimado,
       me.estado, me.fecha_registro, me.fecha_uso, me.id_comanda_uso,
       m.id_material, m.nombre AS material,
       b.id_bodega, b.nombre AS bodega,
       u.nombre_usuario AS registrado_por
FROM merma me
JOIN material m ON m.id_material = me.id_material
JOIN bodega b   ON b.id_bodega   = me.id_bodega
JOIN usuario u  ON u.id_usuario  = me.id_usuario_registro;

-- Dashboard (una sola fila)
CREATE OR REPLACE VIEW v_dashboard_kpis AS
SELECT
  (SELECT COUNT(*) FROM nota_venta WHERE estado IN ('Recibida','EnVerificacion','RechazadaStock')) AS notas_pendientes,
  (SELECT COUNT(*) FROM nota_venta WHERE estado = 'RechazadaStock')                              AS notas_sin_stock,
  (SELECT COUNT(*) FROM comanda WHERE estado = 'EnEspera')                                       AS comandas_en_espera,
  (SELECT COUNT(*) FROM comanda WHERE estado = 'Fabricacion')                                    AS comandas_fabricacion,
  (SELECT COUNT(*) FROM comanda WHERE estado = 'Pintura')                                        AS comandas_pintura,
  (SELECT COUNT(*) FROM comanda WHERE estado = 'QA')                                             AS comandas_qa,
  (SELECT COUNT(*) FROM comanda WHERE estado = 'Finalizado'
      AND fecha_termino >= DATE_FORMAT(CURDATE(), '%Y-%m-01'))                                   AS comandas_finalizadas_mes,
  (SELECT COUNT(*) FROM alerta_stock WHERE estado = 'Pendiente')                                 AS alertas_activas,
  (SELECT COUNT(*) FROM merma WHERE estado = 'Disponible' AND supera_minimo = 1)                 AS mermas_reutilizables,
  (SELECT COALESCE(SUM(stock_actual * costo_unitario), 0) FROM material WHERE activo = 1)        AS valor_inventario;

-- Consumo valorizado por mes y categoría de material (reporte mensual)
CREATE OR REPLACE VIEW v_consumo_mensual_categoria AS
SELECT DATE_FORMAT(mv.fecha, '%Y-%m') AS periodo,
       m.tipo AS categoria,
       SUM(-mv.cantidad * mv.costo_unitario) AS consumo
FROM movimiento_inventario mv
JOIN material m ON m.id_material = mv.id_material
WHERE mv.tipo = 'SALIDA_FABRICACION'
GROUP BY DATE_FORMAT(mv.fecha, '%Y-%m'), m.tipo;
