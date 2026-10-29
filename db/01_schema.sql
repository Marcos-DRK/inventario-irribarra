-- =====================================================================
-- Sistema de Gestión de Inventario Taller Irribarra
-- 01_schema.sql  ·  Tablas, claves e índices (MySQL 8.4 · InnoDB)
-- =====================================================================
DROP DATABASE IF EXISTS inventario_irribarra;
CREATE DATABASE inventario_irribarra
  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE inventario_irribarra;

-- ---------------------------------------------------------------------
-- Usuarios y parámetros
-- ---------------------------------------------------------------------
CREATE TABLE usuario (
  id_usuario      INT AUTO_INCREMENT PRIMARY KEY,
  rut             VARCHAR(12)  NOT NULL UNIQUE,
  nombres         VARCHAR(80)  NOT NULL,
  apellidos       VARCHAR(80)  NOT NULL,
  correo          VARCHAR(120) NOT NULL UNIQUE,
  nombre_usuario  VARCHAR(40)  NOT NULL UNIQUE,
  password_hash   CHAR(60)     NOT NULL,                     -- bcrypt
  rol             ENUM('Administrador','Trabajador') NOT NULL,
  estado          ENUM('Activo','Inactivo') NOT NULL DEFAULT 'Activo',
  fecha_creacion  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  ultimo_acceso   DATETIME NULL
) ENGINE=InnoDB;

CREATE TABLE parametro (
  clave        VARCHAR(40) PRIMARY KEY,
  valor        DECIMAL(12,2) NOT NULL,
  descripcion  VARCHAR(200) NOT NULL
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Ventas
-- ---------------------------------------------------------------------
CREATE TABLE cliente (
  id_cliente  INT AUTO_INCREMENT PRIMARY KEY,
  rut         VARCHAR(12)  NOT NULL UNIQUE,
  nombres     VARCHAR(80)  NOT NULL,
  apellidos   VARCHAR(80)  NOT NULL,
  direccion   VARCHAR(150) NULL,
  comuna      VARCHAR(60)  NULL,
  telefono    VARCHAR(20)  NULL,
  correo      VARCHAR(120) NULL
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Compras
-- ---------------------------------------------------------------------
CREATE TABLE proveedor (
  id_proveedor  INT AUTO_INCREMENT PRIMARY KEY,
  rut           VARCHAR(12)  NOT NULL UNIQUE,
  razon_social  VARCHAR(120) NOT NULL,
  telefono      VARCHAR(20)  NULL,
  correo        VARCHAR(120) NULL,
  direccion     VARCHAR(150) NULL
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Catálogo e inventario
-- ---------------------------------------------------------------------
CREATE TABLE bodega (
  id_bodega  INT AUTO_INCREMENT PRIMARY KEY,
  nombre     VARCHAR(60) NOT NULL UNIQUE,
  tipo       ENUM('Madera','Ferreteria','Accesorios','ProdTerminado') NOT NULL,
  ubicacion  VARCHAR(120) NULL
) ENGINE=InnoDB;

CREATE TABLE material (
  id_material             INT AUTO_INCREMENT PRIMARY KEY,
  codigo_interno          VARCHAR(20)  NOT NULL UNIQUE,
  nombre                  VARCHAR(100) NOT NULL,
  tipo                    ENUM('Madera','Ferreteria','Equipamiento','Accesorio') NOT NULL,
  unidad_medida           VARCHAR(10)  NOT NULL,   -- un, m, m2, m3, kg, L, caja, paquete, bolsa, tira, tablon, placa
  stock_actual            DECIMAL(12,2) NOT NULL DEFAULT 0,
  stock_minimo            DECIMAL(12,2) NOT NULL DEFAULT 0,
  costo_unitario          DECIMAL(12,2) NOT NULL DEFAULT 0,
  id_bodega               INT NOT NULL,
  id_proveedor_principal  INT NULL,
  activo                  TINYINT(1) NOT NULL DEFAULT 1,
  fecha_actualizacion     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT chk_material_stock  CHECK (stock_actual >= 0),
  CONSTRAINT chk_material_minimo CHECK (stock_minimo >= 0),
  CONSTRAINT chk_material_unidad CHECK (unidad_medida IN
    ('un','m','m2','m3','kg','L','caja','paquete','bolsa','tira','tablon','placa')),
  CONSTRAINT fk_material_bodega    FOREIGN KEY (id_bodega) REFERENCES bodega(id_bodega),
  CONSTRAINT fk_material_proveedor FOREIGN KEY (id_proveedor_principal) REFERENCES proveedor(id_proveedor),
  INDEX idx_material_tipo (tipo)
) ENGINE=InnoDB;

CREATE TABLE producto (
  id_producto              INT AUTO_INCREMENT PRIMARY KEY,
  codigo_sku               VARCHAR(30)  NOT NULL UNIQUE,
  nombre                   VARCHAR(120) NOT NULL,
  categoria                ENUM('Sauna_Ext','Sauna_Int','Tina','Mueble','Accesorio') NOT NULL,
  descripcion              VARCHAR(300) NULL,
  medidas                  VARCHAR(80)  NULL,
  precio_venta             DECIMAL(12,2) NOT NULL,
  tiempo_fabricacion_dias  INT NOT NULL DEFAULT 1,
  estado                   ENUM('Activo','Inactivo') NOT NULL DEFAULT 'Activo'
) ENGINE=InnoDB;

-- Receta / despiece (BOM): cantidad de material por 1 unidad de producto
CREATE TABLE receta_producto (
  id_receta           INT AUTO_INCREMENT PRIMARY KEY,
  id_producto         INT NOT NULL,
  id_material         INT NOT NULL,
  cantidad_requerida  DECIMAL(12,2) NOT NULL,
  observacion         VARCHAR(120) NULL,
  CONSTRAINT chk_receta_cantidad CHECK (cantidad_requerida > 0),
  CONSTRAINT uq_receta UNIQUE (id_producto, id_material),
  CONSTRAINT fk_receta_producto FOREIGN KEY (id_producto) REFERENCES producto(id_producto) ON DELETE CASCADE,
  CONSTRAINT fk_receta_material FOREIGN KEY (id_material) REFERENCES material(id_material)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Notas de venta y comandas
-- ---------------------------------------------------------------------
CREATE TABLE nota_venta (
  id_nota_venta   INT AUTO_INCREMENT PRIMARY KEY,
  folio           VARCHAR(20) NOT NULL UNIQUE,
  fecha_venta     DATE NOT NULL,
  fecha_despacho  DATE NULL,
  id_cliente      INT NOT NULL,
  id_vendedor     INT NULL,                         -- usuario que registró / recibió
  origen          ENUM('Plataforma','Manual') NOT NULL DEFAULT 'Plataforma',
  estado          ENUM('Recibida','EnVerificacion','Aprobada','RechazadaStock','Facturada')
                  NOT NULL DEFAULT 'Recibida',
  monto_total     DECIMAL(14,2) NOT NULL DEFAULT 0,
  fecha_registro  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_nota_cliente  FOREIGN KEY (id_cliente)  REFERENCES cliente(id_cliente),
  CONSTRAINT fk_nota_vendedor FOREIGN KEY (id_vendedor) REFERENCES usuario(id_usuario),
  INDEX idx_nota_estado (estado),
  INDEX idx_nota_fecha (fecha_venta)
) ENGINE=InnoDB;

CREATE TABLE detalle_nota_venta (
  id_detalle            INT AUTO_INCREMENT PRIMARY KEY,
  id_nota_venta         INT NOT NULL,
  id_producto           INT NOT NULL,
  cantidad              INT NOT NULL,
  precio_unitario       DECIMAL(12,2) NOT NULL,
  subtotal              DECIMAL(14,2) AS (cantidad * precio_unitario) STORED,
  diseno_personalizado  TEXT NULL,
  CONSTRAINT chk_detalle_cantidad CHECK (cantidad > 0),
  CONSTRAINT fk_detalle_nota     FOREIGN KEY (id_nota_venta) REFERENCES nota_venta(id_nota_venta) ON DELETE CASCADE,
  CONSTRAINT fk_detalle_producto FOREIGN KEY (id_producto)   REFERENCES producto(id_producto)
) ENGINE=InnoDB;

CREATE TABLE comanda (
  id_comanda              INT AUTO_INCREMENT PRIMARY KEY,
  id_detalle              INT NOT NULL UNIQUE,      -- 1 detalle de venta = 1 comanda
  id_trabajador_asignado  INT NULL,
  estado                  ENUM('EnEspera','Fabricacion','Pintura','QA','Finalizado')
                          NOT NULL DEFAULT 'EnEspera',
  fecha_creacion          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fecha_inicio            DATETIME NULL,
  fecha_termino           DATETIME NULL,
  CONSTRAINT fk_comanda_detalle    FOREIGN KEY (id_detalle) REFERENCES detalle_nota_venta(id_detalle),
  CONSTRAINT fk_comanda_trabajador FOREIGN KEY (id_trabajador_asignado) REFERENCES usuario(id_usuario),
  INDEX idx_comanda_estado (estado)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Facturas de compra
-- ---------------------------------------------------------------------
CREATE TABLE factura_compra (
  id_factura           INT AUTO_INCREMENT PRIMARY KEY,
  numero_factura       VARCHAR(30) NOT NULL,
  id_proveedor         INT NOT NULL,
  fecha_emision        DATE NOT NULL,
  fecha_ingreso        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  monto_total          DECIMAL(14,2) NOT NULL DEFAULT 0,
  id_usuario_registro  INT NOT NULL,
  CONSTRAINT uq_factura UNIQUE (id_proveedor, numero_factura),
  CONSTRAINT fk_factura_proveedor FOREIGN KEY (id_proveedor) REFERENCES proveedor(id_proveedor),
  CONSTRAINT fk_factura_usuario   FOREIGN KEY (id_usuario_registro) REFERENCES usuario(id_usuario)
) ENGINE=InnoDB;

CREATE TABLE detalle_factura_compra (
  id_detalle_factura  INT AUTO_INCREMENT PRIMARY KEY,
  id_factura          INT NOT NULL,
  id_material         INT NOT NULL,
  cantidad            DECIMAL(12,2) NOT NULL,
  costo_unitario      DECIMAL(12,2) NOT NULL,
  subtotal            DECIMAL(14,2) AS (cantidad * costo_unitario) STORED,
  CONSTRAINT chk_detfac_cantidad CHECK (cantidad > 0),
  CONSTRAINT fk_detfac_factura  FOREIGN KEY (id_factura)  REFERENCES factura_compra(id_factura) ON DELETE CASCADE,
  CONSTRAINT fk_detfac_material FOREIGN KEY (id_material) REFERENCES material(id_material)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Mermas / sobrantes de madera
-- ---------------------------------------------------------------------
CREATE TABLE merma (
  id_merma             INT AUTO_INCREMENT PRIMARY KEY,
  id_material          INT NOT NULL,
  largo_cm             DECIMAL(7,1) NOT NULL,
  ancho_cm             DECIMAL(7,1) NOT NULL,
  espesor_cm           DECIMAL(7,1) NOT NULL,
  supera_minimo        TINYINT(1) NOT NULL DEFAULT 0,      -- calculado por trigger
  valor_estimado       DECIMAL(12,2) NOT NULL DEFAULT 0,   -- calculado por trigger
  estado               ENUM('Disponible','Reservado','Utilizado','Descartado') NOT NULL DEFAULT 'Disponible',
  id_bodega            INT NOT NULL,
  id_comanda_uso       INT NULL,                           -- comanda que lo reservó / utilizó
  fecha_registro       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fecha_uso            DATETIME NULL,
  id_usuario_registro  INT NOT NULL,
  CONSTRAINT chk_merma_medidas CHECK (largo_cm > 0 AND ancho_cm > 0 AND espesor_cm > 0),
  CONSTRAINT fk_merma_material FOREIGN KEY (id_material) REFERENCES material(id_material),
  CONSTRAINT fk_merma_bodega   FOREIGN KEY (id_bodega)   REFERENCES bodega(id_bodega),
  CONSTRAINT fk_merma_comanda  FOREIGN KEY (id_comanda_uso) REFERENCES comanda(id_comanda),
  CONSTRAINT fk_merma_usuario  FOREIGN KEY (id_usuario_registro) REFERENCES usuario(id_usuario),
  INDEX idx_merma_estado (estado)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Alertas y reportes
-- ---------------------------------------------------------------------
CREATE TABLE alerta_stock (
  id_alerta         INT AUTO_INCREMENT PRIMARY KEY,
  id_material       INT NOT NULL,
  id_nota_venta     INT NULL,                 -- NULL = alerta por bajo mínimo
  tipo              ENUM('Faltante','BajoMinimo') NOT NULL DEFAULT 'Faltante',
  stock_disponible  DECIMAL(12,2) NOT NULL,
  stock_requerido   DECIMAL(12,2) NOT NULL,
  fecha_alerta      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  estado            ENUM('Pendiente','Resuelta') NOT NULL DEFAULT 'Pendiente',
  fecha_resolucion  DATETIME NULL,
  CONSTRAINT fk_alerta_material FOREIGN KEY (id_material)   REFERENCES material(id_material),
  CONSTRAINT fk_alerta_nota     FOREIGN KEY (id_nota_venta) REFERENCES nota_venta(id_nota_venta) ON DELETE CASCADE,
  INDEX idx_alerta_estado (estado)
) ENGINE=InnoDB;

CREATE TABLE reporte_mensual (
  id_reporte                INT AUTO_INCREMENT PRIMARY KEY,
  periodo                   CHAR(7) NOT NULL UNIQUE,        -- 'YYYY-MM'
  consumo_total_materiales  DECIMAL(14,2) NOT NULL DEFAULT 0,
  total_alertas             INT NOT NULL DEFAULT 0,
  ahorro_por_reciclaje      DECIMAL(14,2) NOT NULL DEFAULT 0,
  comandas_finalizadas      INT NOT NULL DEFAULT 0,
  fecha_generacion          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  generado_por              INT NOT NULL,
  CONSTRAINT fk_reporte_usuario FOREIGN KEY (generado_por) REFERENCES usuario(id_usuario)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Kardex y bitácoras (agregadas al modelo del informe)
-- ---------------------------------------------------------------------
CREATE TABLE movimiento_inventario (
  id_movimiento     INT AUTO_INCREMENT PRIMARY KEY,
  id_material       INT NOT NULL,
  tipo              ENUM('CARGA_INICIAL','ENTRADA_FACTURA','SALIDA_FABRICACION','AJUSTE') NOT NULL,
  cantidad          DECIMAL(12,2) NOT NULL,          -- positiva = entrada, negativa = salida
  stock_resultante  DECIMAL(12,2) NOT NULL,
  costo_unitario    DECIMAL(12,2) NOT NULL DEFAULT 0,
  referencia        VARCHAR(60) NULL,                -- 'Factura 123', 'Comanda 45', motivo
  id_usuario        INT NULL,
  fecha             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_mov_material FOREIGN KEY (id_material) REFERENCES material(id_material),
  CONSTRAINT fk_mov_usuario  FOREIGN KEY (id_usuario)  REFERENCES usuario(id_usuario),
  INDEX idx_mov_material_fecha (id_material, fecha),
  INDEX idx_mov_tipo_fecha (tipo, fecha)
) ENGINE=InnoDB;

CREATE TABLE bitacora_acceso (
  id_acceso       INT AUTO_INCREMENT PRIMARY KEY,
  id_usuario      INT NULL,
  nombre_usuario  VARCHAR(40) NOT NULL,
  resultado       ENUM('OK','FALLIDO','LOGOUT') NOT NULL,
  ip              VARCHAR(45) NULL,
  detalle         VARCHAR(120) NULL,
  fecha           DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_acceso_usuario FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario),
  INDEX idx_acceso_fecha (fecha)
) ENGINE=InnoDB;

CREATE TABLE bitacora_auditoria (
  id_auditoria    INT AUTO_INCREMENT PRIMARY KEY,
  tabla           VARCHAR(40) NOT NULL,
  accion          ENUM('INSERT','UPDATE','DELETE') NOT NULL,
  id_registro     INT NOT NULL,
  valor_anterior  JSON NULL,
  valor_nuevo     JSON NULL,
  usuario         VARCHAR(80) NOT NULL,     -- usuario de la aplicación (@app_usuario) o del motor
  fecha           DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_auditoria_fecha (fecha)
) ENGINE=InnoDB;
