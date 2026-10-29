-- =====================================================================
-- 04_procedures.sql  ·  Procedimientos almacenados (transacciones ACID)
-- =====================================================================
USE inventario_irribarra;

DELIMITER $$

-- ---------------------------------------------------------------------
-- Evalúa una nota de venta (sin abrir transacción: la abre quien llama).
-- Re-verifica las alertas pendientes de la nota; si todas quedaron
-- cubiertas la aprueba y crea una comanda por cada línea de detalle.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_evaluar_nota $$
CREATE PROCEDURE sp_evaluar_nota(IN p_id_nota INT, OUT p_estado VARCHAR(20))
BEGIN
  DECLARE v_estado VARCHAR(20);
  DECLARE v_pendientes INT;

  SELECT estado INTO v_estado FROM nota_venta WHERE id_nota_venta = p_id_nota FOR UPDATE;
  IF v_estado IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La nota de venta no existe';
  END IF;
  IF v_estado IN ('Aprobada', 'Facturada') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La nota de venta ya fue aprobada';
  END IF;

  -- Alertas que hoy ya están cubiertas (p. ej. tras un ajuste de stock)
  UPDATE alerta_stock a
    JOIN material m ON m.id_material = a.id_material
    LEFT JOIN v_stock_comprometido sc ON sc.id_material = a.id_material
     SET a.estado = 'Resuelta', a.fecha_resolucion = NOW()
   WHERE a.id_nota_venta = p_id_nota
     AND a.estado = 'Pendiente'
     AND a.stock_requerido <= m.stock_actual - COALESCE(sc.comprometido, 0);

  SELECT COUNT(*) INTO v_pendientes
    FROM alerta_stock WHERE id_nota_venta = p_id_nota AND estado = 'Pendiente';

  IF v_pendientes > 0 THEN
    UPDATE nota_venta SET estado = 'RechazadaStock' WHERE id_nota_venta = p_id_nota;
    SET p_estado = 'RechazadaStock';
  ELSE
    UPDATE nota_venta SET estado = 'Aprobada' WHERE id_nota_venta = p_id_nota;
    INSERT INTO comanda (id_detalle)
    SELECT d.id_detalle FROM detalle_nota_venta d
     WHERE d.id_nota_venta = p_id_nota
       AND NOT EXISTS (SELECT 1 FROM comanda c WHERE c.id_detalle = d.id_detalle);
    SET p_estado = 'Aprobada';
  END IF;
END $$

-- ---------------------------------------------------------------------
-- sp_procesar_nota_venta: aprobación o rechazo como operación atómica
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_procesar_nota_venta $$
CREATE PROCEDURE sp_procesar_nota_venta(IN p_id_nota INT, OUT p_estado VARCHAR(20))
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;
    CALL sp_evaluar_nota(p_id_nota, p_estado);
  COMMIT;
END $$

-- ---------------------------------------------------------------------
-- Recepción de una nota de venta desde la plataforma web (JSON)
-- {
--   "folio": "1943", "fecha_venta": "2026-10-28", "fecha_despacho": "2026-11-20",
--   "origen": "Plataforma",
--   "cliente":  {"rut": "...", "nombres": "...", "apellidos": "...", "direccion": "...",
--                "comuna": "...", "telefono": "...", "correo": "..."},
--   "detalles": [{"codigo_sku": "SAU-BAR-220", "cantidad": 1, "precio_unitario": 3200000,
--                 "diseno_personalizado": "..."}]
-- }
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_registrar_nota_venta_json $$
CREATE PROCEDURE sp_registrar_nota_venta_json(
  IN p_json JSON, IN p_id_usuario INT,
  OUT p_id_nota INT, OUT p_estado VARCHAR(20))
BEGIN
  DECLARE v_id_cliente INT;
  DECLARE v_rut VARCHAR(12);
  DECLARE v_esperados INT;
  DECLARE v_insertados INT;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  SET v_rut = JSON_UNQUOTE(JSON_EXTRACT(p_json, '$.cliente.rut'));
  SET v_esperados = JSON_LENGTH(p_json, '$.detalles');
  IF v_rut IS NULL OR v_esperados IS NULL OR v_esperados = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'JSON inválido: faltan cliente.rut o detalles';
  END IF;

  START TRANSACTION;

  -- Cliente: se crea o se actualiza por RUT
  INSERT INTO cliente (rut, nombres, apellidos, direccion, comuna, telefono, correo)
  VALUES (v_rut,
          JSON_UNQUOTE(JSON_EXTRACT(p_json, '$.cliente.nombres')),
          JSON_UNQUOTE(JSON_EXTRACT(p_json, '$.cliente.apellidos')),
          JSON_UNQUOTE(JSON_EXTRACT(p_json, '$.cliente.direccion')),
          JSON_UNQUOTE(JSON_EXTRACT(p_json, '$.cliente.comuna')),
          JSON_UNQUOTE(JSON_EXTRACT(p_json, '$.cliente.telefono')),
          JSON_UNQUOTE(JSON_EXTRACT(p_json, '$.cliente.correo')))
  ON DUPLICATE KEY UPDATE
     nombres   = VALUES(nombres),   apellidos = VALUES(apellidos),
     direccion = COALESCE(VALUES(direccion), direccion),
     comuna    = COALESCE(VALUES(comuna), comuna),
     telefono  = COALESCE(VALUES(telefono), telefono),
     correo    = COALESCE(VALUES(correo), correo);
  SELECT id_cliente INTO v_id_cliente FROM cliente WHERE rut = v_rut;

  INSERT INTO nota_venta (folio, fecha_venta, fecha_despacho, id_cliente, id_vendedor, origen, estado)
  VALUES (JSON_UNQUOTE(JSON_EXTRACT(p_json, '$.folio')),
          COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p_json, '$.fecha_venta')), CURDATE()),
          NULLIF(JSON_UNQUOTE(JSON_EXTRACT(p_json, '$.fecha_despacho')), 'null'),
          v_id_cliente, p_id_usuario,
          COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p_json, '$.origen')), 'Plataforma'),
          'EnVerificacion');
  SET p_id_nota = LAST_INSERT_ID();

  -- Detalles (cada INSERT dispara trg_verificar_stock_venta)
  INSERT INTO detalle_nota_venta (id_nota_venta, id_producto, cantidad, precio_unitario, diseno_personalizado)
  SELECT p_id_nota, p.id_producto, j.cantidad, COALESCE(j.precio_unitario, p.precio_venta), j.diseno
    FROM JSON_TABLE(p_json, '$.detalles[*]' COLUMNS (
           codigo_sku      VARCHAR(30)   PATH '$.codigo_sku',
           cantidad        INT           PATH '$.cantidad',
           precio_unitario DECIMAL(12,2) PATH '$.precio_unitario',
           diseno          TEXT          PATH '$.diseno_personalizado')) j
    JOIN producto p ON p.codigo_sku = j.codigo_sku AND p.estado = 'Activo';
  SET v_insertados = ROW_COUNT();

  IF v_insertados <> v_esperados THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La nota contiene un código SKU inexistente o inactivo';
  END IF;

  CALL sp_evaluar_nota(p_id_nota, p_estado);

  COMMIT;
END $$

-- ---------------------------------------------------------------------
-- Registro de factura de compra (JSON) — el trigger suma el stock
-- {"numero_factura": "F-1001", "id_proveedor": 1, "fecha_emision": "2026-10-28",
--  "detalles": [{"id_material": 5, "cantidad": 10, "costo_unitario": 4500}]}
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_registrar_factura_json $$
CREATE PROCEDURE sp_registrar_factura_json(
  IN p_json JSON, IN p_id_usuario INT, OUT p_id_factura INT)
BEGIN
  DECLARE v_esperados INT;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  SET v_esperados = JSON_LENGTH(p_json, '$.detalles');
  IF v_esperados IS NULL OR v_esperados = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La factura debe tener al menos un detalle';
  END IF;

  START TRANSACTION;

  INSERT INTO factura_compra (numero_factura, id_proveedor, fecha_emision, id_usuario_registro)
  VALUES (JSON_UNQUOTE(JSON_EXTRACT(p_json, '$.numero_factura')),
          JSON_EXTRACT(p_json, '$.id_proveedor'),
          COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p_json, '$.fecha_emision')), CURDATE()),
          p_id_usuario);
  SET p_id_factura = LAST_INSERT_ID();

  INSERT INTO detalle_factura_compra (id_factura, id_material, cantidad, costo_unitario)
  SELECT p_id_factura, j.id_material, j.cantidad, j.costo_unitario
    FROM JSON_TABLE(p_json, '$.detalles[*]' COLUMNS (
           id_material    INT           PATH '$.id_material',
           cantidad       DECIMAL(12,2) PATH '$.cantidad',
           costo_unitario DECIMAL(12,2) PATH '$.costo_unitario')) j;

  COMMIT;
END $$

-- ---------------------------------------------------------------------
-- Ajuste manual / carga inicial (conteo físico) con registro en kardex
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_ajustar_stock $$
CREATE PROCEDURE sp_ajustar_stock(
  IN p_id_material INT, IN p_nuevo_stock DECIMAL(12,2),
  IN p_tipo VARCHAR(20), IN p_motivo VARCHAR(60), IN p_id_usuario INT)
BEGIN
  DECLARE v_actual DECIMAL(12,2);
  DECLARE v_costo  DECIMAL(12,2);

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  IF p_tipo NOT IN ('AJUSTE', 'CARGA_INICIAL') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tipo de ajuste inválido';
  END IF;

  START TRANSACTION;
  SELECT stock_actual, costo_unitario INTO v_actual, v_costo
    FROM material WHERE id_material = p_id_material FOR UPDATE;
  IF v_actual IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El material no existe';
  END IF;

  UPDATE material SET stock_actual = p_nuevo_stock WHERE id_material = p_id_material;

  INSERT INTO movimiento_inventario
         (id_material, tipo, cantidad, stock_resultante, costo_unitario, referencia, id_usuario)
  VALUES (p_id_material, p_tipo, p_nuevo_stock - v_actual, p_nuevo_stock, v_costo, p_motivo, p_id_usuario);
  COMMIT;
END $$

-- ---------------------------------------------------------------------
-- Retazos disponibles compatibles con la receta de una comanda
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_sugerir_mermas $$
CREATE PROCEDURE sp_sugerir_mermas(IN p_id_comanda INT)
BEGIN
  SELECT me.id_merma, me.id_material, m.nombre AS material,
         me.largo_cm, me.ancho_cm, me.espesor_cm, me.valor_estimado, b.nombre AS bodega
    FROM comanda c
    JOIN detalle_nota_venta d ON d.id_detalle  = c.id_detalle
    JOIN receta_producto r    ON r.id_producto = d.id_producto
    JOIN merma me             ON me.id_material = r.id_material
    JOIN material m           ON m.id_material  = me.id_material
    JOIN bodega b             ON b.id_bodega    = me.id_bodega
   WHERE c.id_comanda = p_id_comanda
     AND me.estado = 'Disponible'
     AND me.supera_minimo = 1
   ORDER BY me.largo_cm * me.ancho_cm * me.espesor_cm DESC;
END $$

-- ---------------------------------------------------------------------
-- Reporte mensual consolidado (se recalcula si ya existe)
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_generar_reporte_mensual $$
CREATE PROCEDURE sp_generar_reporte_mensual(IN p_periodo CHAR(7), IN p_id_usuario INT)
BEGIN
  DECLARE v_desde DATE;
  DECLARE v_hasta DATE;

  IF p_periodo NOT REGEXP '^[0-9]{4}-(0[1-9]|1[0-2])$' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Periodo inválido, use AAAA-MM';
  END IF;
  SET v_desde = STR_TO_DATE(CONCAT(p_periodo, '-01'), '%Y-%m-%d');
  SET v_hasta = DATE_ADD(v_desde, INTERVAL 1 MONTH);

  INSERT INTO reporte_mensual
         (periodo, consumo_total_materiales, total_alertas, ahorro_por_reciclaje,
          comandas_finalizadas, generado_por)
  SELECT p_periodo,
         (SELECT COALESCE(SUM(-cantidad * costo_unitario), 0) FROM movimiento_inventario
           WHERE tipo = 'SALIDA_FABRICACION' AND fecha >= v_desde AND fecha < v_hasta),
         (SELECT COUNT(*) FROM alerta_stock WHERE fecha_alerta >= v_desde AND fecha_alerta < v_hasta),
         (SELECT COALESCE(SUM(valor_estimado), 0) FROM merma
           WHERE estado = 'Utilizado' AND fecha_uso >= v_desde AND fecha_uso < v_hasta),
         (SELECT COUNT(*) FROM comanda WHERE fecha_termino >= v_desde AND fecha_termino < v_hasta),
         p_id_usuario
  ON DUPLICATE KEY UPDATE
     consumo_total_materiales = VALUES(consumo_total_materiales),
     total_alertas            = VALUES(total_alertas),
     ahorro_por_reciclaje     = VALUES(ahorro_por_reciclaje),
     comandas_finalizadas     = VALUES(comandas_finalizadas),
     generado_por             = VALUES(generado_por),
     fecha_generacion         = NOW();

  SELECT * FROM reporte_mensual WHERE periodo = p_periodo;
END $$

DELIMITER ;
