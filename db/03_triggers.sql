-- =====================================================================
-- 03_triggers.sql  ·  Lógica de inventario dentro del SGBD
--
-- La API fija dos variables de sesión antes de cada operación:
--   @app_usuario     nombre_usuario de quien opera (para la auditoría)
--   @app_id_usuario  id_usuario de quien opera  (para el kardex)
-- =====================================================================
USE inventario_irribarra;

DELIMITER $$

-- ---------------------------------------------------------------------
-- 1. Comprobación automática de stock al recibir una nota de venta
--    Por cada material de la receta cuyo disponible (stock - comprometido)
--    no alcance, se crea una alerta "Faltante" ligada a la nota.
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_verificar_stock_venta $$
CREATE TRIGGER trg_verificar_stock_venta
AFTER INSERT ON detalle_nota_venta
FOR EACH ROW
BEGIN
  INSERT INTO alerta_stock (id_material, id_nota_venta, tipo, stock_disponible, stock_requerido)
  SELECT r.id_material,
         NEW.id_nota_venta,
         'Faltante',
         m.stock_actual - COALESCE(sc.comprometido, 0),
         r.cantidad_requerida * NEW.cantidad
  FROM receta_producto r
  JOIN material m ON m.id_material = r.id_material
  LEFT JOIN v_stock_comprometido sc ON sc.id_material = r.id_material
  WHERE r.id_producto = NEW.id_producto
    AND m.stock_actual - COALESCE(sc.comprometido, 0) < r.cantidad_requerida * NEW.cantidad;

  UPDATE nota_venta
     SET monto_total = monto_total + NEW.cantidad * NEW.precio_unitario
   WHERE id_nota_venta = NEW.id_nota_venta;
END $$

-- ---------------------------------------------------------------------
-- 2. Ingreso automático de stock por factura de compra
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_ingreso_por_factura $$
CREATE TRIGGER trg_ingreso_por_factura
AFTER INSERT ON detalle_factura_compra
FOR EACH ROW
BEGIN
  DECLARE v_numero  VARCHAR(30);
  DECLARE v_usuario INT;
  DECLARE v_stock   DECIMAL(12,2);

  SELECT numero_factura, id_usuario_registro INTO v_numero, v_usuario
    FROM factura_compra WHERE id_factura = NEW.id_factura;

  UPDATE material
     SET stock_actual   = stock_actual + NEW.cantidad,
         costo_unitario = NEW.costo_unitario
   WHERE id_material = NEW.id_material;

  SELECT stock_actual INTO v_stock FROM material WHERE id_material = NEW.id_material;

  INSERT INTO movimiento_inventario
         (id_material, tipo, cantidad, stock_resultante, costo_unitario, referencia, id_usuario)
  VALUES (NEW.id_material, 'ENTRADA_FACTURA', NEW.cantidad, v_stock, NEW.costo_unitario,
          CONCAT('Factura ', v_numero), v_usuario);

  UPDATE factura_compra
     SET monto_total = monto_total + NEW.cantidad * NEW.costo_unitario
   WHERE id_factura = NEW.id_factura;

  -- Las alertas "Faltante" que ahora quedan cubiertas se resuelven solas
  UPDATE alerta_stock a
     SET a.estado = 'Resuelta', a.fecha_resolucion = NOW()
   WHERE a.id_material = NEW.id_material
     AND a.estado = 'Pendiente'
     AND a.tipo = 'Faltante'
     AND a.stock_requerido <= v_stock - COALESCE(
           (SELECT sc.comprometido FROM v_stock_comprometido sc
             WHERE sc.id_material = NEW.id_material), 0);
END $$

-- ---------------------------------------------------------------------
-- 3. Flujo Kanban + descuento de stock por fabricación
--    · Solo se avanza o retrocede una etapa a la vez.
--    · No se puede volver de Fabricación a En Espera (el stock ya salió).
--    · Al pasar a Fabricación: los retazos reservados para la comanda
--      reemplazan 1 unidad cada uno (priorización de sobrantes), el resto
--      se descuenta del stock. Si algo no alcanza, se bloquea el cambio.
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_descuento_stock_fabricacion $$
CREATE TRIGGER trg_descuento_stock_fabricacion
BEFORE UPDATE ON comanda
FOR EACH ROW
BEGIN
  DECLARE v_old INT;
  DECLARE v_new INT;
  DECLARE v_faltan TEXT;
  DECLARE v_msg VARCHAR(255);

  IF NEW.estado <> OLD.estado THEN
    SET v_old = FIELD(OLD.estado, 'EnEspera','Fabricacion','Pintura','QA','Finalizado');
    SET v_new = FIELD(NEW.estado, 'EnEspera','Fabricacion','Pintura','QA','Finalizado');

    IF OLD.estado = 'Finalizado' THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La comanda ya está finalizada';
    END IF;
    IF ABS(v_new - v_old) <> 1 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solo se puede mover la comanda una etapa a la vez';
    END IF;
    IF OLD.estado = 'Fabricacion' AND NEW.estado = 'EnEspera' THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se puede volver a En Espera: el material ya fue descontado';
    END IF;

    IF OLD.estado = 'EnEspera' AND NEW.estado = 'Fabricacion' THEN
      -- ¿Alcanza el stock?
      SELECT GROUP_CONCAT(CONCAT(m.nombre, ' (faltan ', x.req - m.stock_actual, ' ', m.unidad_medida, ')')
                          SEPARATOR ', ')
        INTO v_faltan
        FROM (SELECT r.id_material,
                     GREATEST(0, r.cantidad_requerida * d.cantidad - COALESCE(mr.n, 0)) AS req
                FROM detalle_nota_venta d
                JOIN receta_producto r ON r.id_producto = d.id_producto
                LEFT JOIN (SELECT id_material, COUNT(*) AS n FROM merma
                            WHERE id_comanda_uso = NEW.id_comanda AND estado = 'Reservado'
                            GROUP BY id_material) mr ON mr.id_material = r.id_material
               WHERE d.id_detalle = NEW.id_detalle) x
        JOIN material m ON m.id_material = x.id_material
       WHERE m.stock_actual < x.req;

      IF v_faltan IS NOT NULL THEN
        SET v_msg = LEFT(CONCAT('Stock insuficiente: ', v_faltan), 255);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
      END IF;

      -- Descuento
      UPDATE material m
        JOIN (SELECT r.id_material,
                     GREATEST(0, r.cantidad_requerida * d.cantidad - COALESCE(mr.n, 0)) AS req
                FROM detalle_nota_venta d
                JOIN receta_producto r ON r.id_producto = d.id_producto
                LEFT JOIN (SELECT id_material, COUNT(*) AS n FROM merma
                            WHERE id_comanda_uso = NEW.id_comanda AND estado = 'Reservado'
                            GROUP BY id_material) mr ON mr.id_material = r.id_material
               WHERE d.id_detalle = NEW.id_detalle) x ON x.id_material = m.id_material
         SET m.stock_actual = m.stock_actual - x.req
       WHERE x.req > 0;

      -- Kardex
      INSERT INTO movimiento_inventario
             (id_material, tipo, cantidad, stock_resultante, costo_unitario, referencia, id_usuario)
      SELECT x.id_material, 'SALIDA_FABRICACION', -x.req, m.stock_actual, m.costo_unitario,
             CONCAT('Comanda ', NEW.id_comanda), @app_id_usuario
        FROM (SELECT r.id_material,
                     GREATEST(0, r.cantidad_requerida * d.cantidad - COALESCE(mr.n, 0)) AS req
                FROM detalle_nota_venta d
                JOIN receta_producto r ON r.id_producto = d.id_producto
                LEFT JOIN (SELECT id_material, COUNT(*) AS n FROM merma
                            WHERE id_comanda_uso = NEW.id_comanda AND estado = 'Reservado'
                            GROUP BY id_material) mr ON mr.id_material = r.id_material
               WHERE d.id_detalle = NEW.id_detalle) x
        JOIN material m ON m.id_material = x.id_material
       WHERE x.req > 0;

      -- Los retazos reservados pasan a utilizados (cuentan como ahorro)
      UPDATE merma
         SET estado = 'Utilizado', fecha_uso = NOW()
       WHERE id_comanda_uso = NEW.id_comanda AND estado = 'Reservado';

      SET NEW.fecha_inicio = NOW();
    END IF;

    IF NEW.estado = 'Finalizado' THEN
      SET NEW.fecha_termino = NOW();
    END IF;
  END IF;
END $$

-- ---------------------------------------------------------------------
-- 4. Clasificación automática de mermas
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_merma_clasificar $$
CREATE TRIGGER trg_merma_clasificar
BEFORE INSERT ON merma
FOR EACH ROW
BEGIN
  DECLARE v_tipo  VARCHAR(20);
  DECLARE v_costo DECIMAL(12,2);

  SELECT tipo, costo_unitario INTO v_tipo, v_costo
    FROM material WHERE id_material = NEW.id_material;

  IF v_tipo <> 'Madera' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solo se registran mermas de materiales tipo Madera';
  END IF;

  SET NEW.supera_minimo =
        NEW.largo_cm >= (SELECT valor FROM parametro WHERE clave = 'merma_largo_minimo_cm')
    AND NEW.ancho_cm >= (SELECT valor FROM parametro WHERE clave = 'merma_ancho_minimo_cm');

  -- Un retazo reutilizable reemplaza 1 unidad del material de origen
  SET NEW.valor_estimado = IF(NEW.supera_minimo, v_costo, 0);

  IF NOT NEW.supera_minimo THEN
    SET NEW.estado = 'Descartado';
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_merma_validar_estado $$
CREATE TRIGGER trg_merma_validar_estado
BEFORE UPDATE ON merma
FOR EACH ROW
BEGIN
  IF NEW.estado = 'Reservado' AND NOT OLD.supera_minimo THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Un retazo bajo la medida mínima no se puede reservar';
  END IF;
  IF NEW.estado = 'Reservado' AND NEW.id_comanda_uso IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Para reservar un retazo se debe indicar la comanda';
  END IF;
  IF OLD.estado = 'Utilizado' AND NEW.estado <> 'Utilizado' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Un retazo utilizado no puede cambiar de estado';
  END IF;
  IF NEW.estado = 'Disponible' THEN
    SET NEW.id_comanda_uso = NULL;
  END IF;
END $$

-- ---------------------------------------------------------------------
-- 5. Material: alerta por bajo mínimo + auditoría
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_material_after_update $$
CREATE TRIGGER trg_material_after_update
AFTER UPDATE ON material
FOR EACH ROW
BEGIN
  IF NEW.stock_actual < NEW.stock_minimo THEN
    IF NOT EXISTS (SELECT 1 FROM alerta_stock
                    WHERE id_material = NEW.id_material AND tipo = 'BajoMinimo' AND estado = 'Pendiente') THEN
      INSERT INTO alerta_stock (id_material, id_nota_venta, tipo, stock_disponible, stock_requerido)
      VALUES (NEW.id_material, NULL, 'BajoMinimo', NEW.stock_actual, NEW.stock_minimo);
    END IF;
  ELSE
    UPDATE alerta_stock
       SET estado = 'Resuelta', fecha_resolucion = NOW()
     WHERE id_material = NEW.id_material AND tipo = 'BajoMinimo' AND estado = 'Pendiente';
  END IF;

  INSERT INTO bitacora_auditoria (tabla, accion, id_registro, valor_anterior, valor_nuevo, usuario)
  VALUES ('material', 'UPDATE', NEW.id_material,
          JSON_OBJECT('nombre', OLD.nombre, 'stock_actual', OLD.stock_actual,
                      'stock_minimo', OLD.stock_minimo, 'costo_unitario', OLD.costo_unitario,
                      'id_bodega', OLD.id_bodega, 'activo', OLD.activo),
          JSON_OBJECT('nombre', NEW.nombre, 'stock_actual', NEW.stock_actual,
                      'stock_minimo', NEW.stock_minimo, 'costo_unitario', NEW.costo_unitario,
                      'id_bodega', NEW.id_bodega, 'activo', NEW.activo),
          COALESCE(@app_usuario, CURRENT_USER()));
END $$

DROP TRIGGER IF EXISTS trg_material_after_insert $$
CREATE TRIGGER trg_material_after_insert
AFTER INSERT ON material
FOR EACH ROW
BEGIN
  INSERT INTO bitacora_auditoria (tabla, accion, id_registro, valor_nuevo, usuario)
  VALUES ('material', 'INSERT', NEW.id_material,
          JSON_OBJECT('codigo', NEW.codigo_interno, 'nombre', NEW.nombre,
                      'stock_actual', NEW.stock_actual, 'stock_minimo', NEW.stock_minimo),
          COALESCE(@app_usuario, CURRENT_USER()));
END $$

-- ---------------------------------------------------------------------
-- 6. Auditoría de usuarios (nunca se guarda el hash, solo si cambió)
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_usuario_after_insert $$
CREATE TRIGGER trg_usuario_after_insert
AFTER INSERT ON usuario
FOR EACH ROW
BEGIN
  INSERT INTO bitacora_auditoria (tabla, accion, id_registro, valor_nuevo, usuario)
  VALUES ('usuario', 'INSERT', NEW.id_usuario,
          JSON_OBJECT('nombre_usuario', NEW.nombre_usuario, 'rol', NEW.rol, 'estado', NEW.estado),
          COALESCE(@app_usuario, CURRENT_USER()));
END $$

DROP TRIGGER IF EXISTS trg_usuario_after_update $$
CREATE TRIGGER trg_usuario_after_update
AFTER UPDATE ON usuario
FOR EACH ROW
BEGIN
  -- El registro de último acceso no se audita (ya queda en bitacora_acceso)
  IF NOT (OLD.nombres = NEW.nombres AND OLD.apellidos = NEW.apellidos
          AND OLD.correo = NEW.correo AND OLD.rol = NEW.rol AND OLD.estado = NEW.estado
          AND OLD.password_hash = NEW.password_hash) THEN
    INSERT INTO bitacora_auditoria (tabla, accion, id_registro, valor_anterior, valor_nuevo, usuario)
    VALUES ('usuario', 'UPDATE', NEW.id_usuario,
            JSON_OBJECT('nombres', OLD.nombres, 'apellidos', OLD.apellidos, 'correo', OLD.correo,
                        'rol', OLD.rol, 'estado', OLD.estado),
            JSON_OBJECT('nombres', NEW.nombres, 'apellidos', NEW.apellidos, 'correo', NEW.correo,
                        'rol', NEW.rol, 'estado', NEW.estado,
                        'password_cambiada', OLD.password_hash <> NEW.password_hash),
            COALESCE(@app_usuario, CURRENT_USER()));
  END IF;
END $$

-- ---------------------------------------------------------------------
-- 7. Auditoría de cambios de estado en notas de venta
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_nota_venta_after_update $$
CREATE TRIGGER trg_nota_venta_after_update
AFTER UPDATE ON nota_venta
FOR EACH ROW
BEGIN
  IF OLD.estado <> NEW.estado THEN
    INSERT INTO bitacora_auditoria (tabla, accion, id_registro, valor_anterior, valor_nuevo, usuario)
    VALUES ('nota_venta', 'UPDATE', NEW.id_nota_venta,
            JSON_OBJECT('folio', OLD.folio, 'estado', OLD.estado),
            JSON_OBJECT('folio', NEW.folio, 'estado', NEW.estado),
            COALESCE(@app_usuario, CURRENT_USER()));
  END IF;
END $$

DELIMITER ;
