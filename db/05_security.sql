-- =====================================================================
-- 05_security.sql  ·  Roles del motor y usuarios de conexión
--
-- Las contraseñas llegan como variables de sesión desde instalar.ps1:
--   @pw_app_admin, @pw_app_trabajador
-- (nunca se escriben en este archivo).
-- =====================================================================
USE inventario_irribarra;

DROP USER IF EXISTS 'app_admin'@'localhost', 'app_trabajador'@'localhost';
DROP ROLE IF EXISTS rol_administrador_bd, rol_trabajador_bd;

CREATE ROLE rol_administrador_bd, rol_trabajador_bd;

-- Administrador: privilegios completos sobre el esquema
GRANT ALL PRIVILEGES ON inventario_irribarra.* TO rol_administrador_bd;

-- Trabajador de taller: mínimo privilegio
--   lectura del catálogo y de las ventas
GRANT SELECT ON inventario_irribarra.bodega                 TO rol_trabajador_bd;
GRANT SELECT ON inventario_irribarra.proveedor              TO rol_trabajador_bd;
GRANT SELECT ON inventario_irribarra.producto               TO rol_trabajador_bd;
GRANT SELECT ON inventario_irribarra.receta_producto        TO rol_trabajador_bd;
GRANT SELECT ON inventario_irribarra.cliente                TO rol_trabajador_bd;
GRANT SELECT ON inventario_irribarra.nota_venta             TO rol_trabajador_bd;
GRANT SELECT ON inventario_irribarra.detalle_nota_venta     TO rol_trabajador_bd;
GRANT SELECT ON inventario_irribarra.alerta_stock           TO rol_trabajador_bd;
GRANT SELECT ON inventario_irribarra.movimiento_inventario  TO rol_trabajador_bd;
GRANT SELECT ON inventario_irribarra.factura_compra         TO rol_trabajador_bd;
GRANT SELECT ON inventario_irribarra.detalle_factura_compra TO rol_trabajador_bd;
GRANT SELECT ON inventario_irribarra.parametro              TO rol_trabajador_bd;
--   tablas operativas del taller
GRANT SELECT, INSERT, UPDATE ON inventario_irribarra.material TO rol_trabajador_bd;
GRANT SELECT, INSERT, UPDATE ON inventario_irribarra.merma    TO rol_trabajador_bd;
GRANT SELECT, UPDATE         ON inventario_irribarra.comanda  TO rol_trabajador_bd;
--   inicio de sesión: leer usuarios, marcar último acceso y dejar bitácora
GRANT SELECT ON inventario_irribarra.usuario                  TO rol_trabajador_bd;
GRANT UPDATE (ultimo_acceso) ON inventario_irribarra.usuario  TO rol_trabajador_bd;
GRANT INSERT ON inventario_irribarra.bitacora_acceso          TO rol_trabajador_bd;
--   vistas de las pantallas del taller
GRANT SELECT ON inventario_irribarra.v_inventario_estado  TO rol_trabajador_bd;
GRANT SELECT ON inventario_irribarra.v_stock_comprometido TO rol_trabajador_bd;
GRANT SELECT ON inventario_irribarra.v_notas_venta        TO rol_trabajador_bd;
GRANT SELECT ON inventario_irribarra.v_kanban_comandas    TO rol_trabajador_bd;
GRANT SELECT ON inventario_irribarra.v_kardex             TO rol_trabajador_bd;
GRANT SELECT ON inventario_irribarra.v_alertas            TO rol_trabajador_bd;
GRANT SELECT ON inventario_irribarra.v_mermas             TO rol_trabajador_bd;
GRANT SELECT ON inventario_irribarra.v_dashboard_kpis     TO rol_trabajador_bd;
--   procedimientos de su caso de uso (registrar compra, carga inicial, mermas)
GRANT EXECUTE ON PROCEDURE inventario_irribarra.sp_registrar_factura_json TO rol_trabajador_bd;
GRANT EXECUTE ON PROCEDURE inventario_irribarra.sp_ajustar_stock          TO rol_trabajador_bd;
GRANT EXECUTE ON PROCEDURE inventario_irribarra.sp_sugerir_mermas         TO rol_trabajador_bd;

-- Usuarios de conexión de la API (separados de los usuarios finales)
SET @sql = CONCAT('CREATE USER ''app_admin''@''localhost'' IDENTIFIED BY ', QUOTE(@pw_app_admin));
PREPARE st FROM @sql; EXECUTE st; DEALLOCATE PREPARE st;
SET @sql = CONCAT('CREATE USER ''app_trabajador''@''localhost'' IDENTIFIED BY ', QUOTE(@pw_app_trabajador));
PREPARE st FROM @sql; EXECUTE st; DEALLOCATE PREPARE st;
SET @sql = NULL;

GRANT rol_administrador_bd TO 'app_admin'@'localhost';
GRANT rol_trabajador_bd    TO 'app_trabajador'@'localhost';
SET DEFAULT ROLE ALL TO 'app_admin'@'localhost', 'app_trabajador'@'localhost';
