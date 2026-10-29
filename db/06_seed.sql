-- =====================================================================
-- 06_seed.sql  ·  Datos iniciales
--
-- Recetas: tomadas de "Fichas_Produccion_Saunas.xlsx" y normalizadas
-- (fracciones a decimales, nombres repetidos unificados en un solo
-- material). Stocks, costos, precios, RUT y proveedores son DE PRUEBA.
--
-- Usuarios de prueba de la aplicación (contraseñas con hash bcrypt):
--   admin        / Admin2026!   (Administrador)
--   ricardo.trab / Taller2026!  (Trabajador)
--   victor.trab  / Taller2026!  (Trabajador)
-- =====================================================================
USE inventario_irribarra;
SET @app_usuario = 'instalacion';

INSERT INTO parametro (clave, valor, descripcion) VALUES
('merma_largo_minimo_cm', 30, 'Largo mínimo para que un retazo de madera sea reutilizable'),
('merma_ancho_minimo_cm',  8, 'Ancho mínimo para que un retazo de madera sea reutilizable');

INSERT INTO usuario (rut, nombres, apellidos, correo, nombre_usuario, password_hash, rol) VALUES
('11111111-1', 'Administrador', 'Sistema',  'admin@tallerirribarra.cl',   'admin',
 '$2b$12$ZMPNakVk97QhRIabz9L4IuWGUghDDHztJioFMhEMEFuMlsiDrF13m', 'Administrador'),
('12222222-2', 'Ricardo',       'Caamaño',  'ricardo@tallerirribarra.cl', 'ricardo.trab',
 '$2b$12$9rOLAT5EB1I9U40iipK3wOTkcY9tru8EFwECSwgQB/w038WJUvFoa', 'Trabajador'),
('13333333-3', 'Víctor',        'Anrique',  'victor@tallerirribarra.cl',  'victor.trab',
 '$2b$12$9rOLAT5EB1I9U40iipK3wOTkcY9tru8EFwECSwgQB/w038WJUvFoa', 'Trabajador');

INSERT INTO bodega (nombre, tipo, ubicacion) VALUES
('Patio de Madera',     'Madera',        'Galpón norte'),
('Bodega Ferretería',   'Ferreteria',    'Taller, estantería A'),
('Bodega Accesorios',   'Accesorios',    'Taller, estantería B'),
('Producto Terminado',  'ProdTerminado', 'Galpón sur');

INSERT INTO proveedor (rut, razon_social, telefono, correo, direccion) VALUES
('76111111-1', 'Maderas del Sur SpA',        '+56 42 220 0001', 'ventas@maderasdelsur.cl', 'Chillán'),
('76222222-2', 'Ferretería Bulnes Ltda.',    '+56 42 220 0002', 'contacto@ferrebulnes.cl', 'Bulnes'),
('76333333-3', 'Equipos Sauna Chile SpA',    '+56 2 2900 0003', 'ventas@equipossauna.cl',  'Santiago');

-- ---------------------------------------------------------------------
-- Materiales (bodega: 1 Madera, 2 Ferretería, 3 Accesorios)
-- ---------------------------------------------------------------------
INSERT INTO material (codigo_interno, nombre, tipo, unidad_medida, stock_actual, stock_minimo, costo_unitario, id_bodega, id_proveedor_principal) VALUES
('MAD-MACH-01', 'Madera machihembrada (tabla)',   'Madera',       'un',      250,  100,   6500, 1, 1),
('MAD-CEPI-01', 'Madera cepillada (paquete)',     'Madera',       'paquete',   8,    3,  45000, 1, 1),
('MAD-CE14-01', 'Tabla cepillada 1x4',            'Madera',       'un',       60,   25,   3200, 1, 1),
('MAD-PINB-01', 'Pino bruto (tablón para patas)', 'Madera',       'tablon',   10,    4,   9800, 1, 1),
('MAD-CEDR-01', 'Tablón de cedro (puertas)',      'Madera',       'tablon',    4,    2,  38000, 1, 1),
('MAD-TING-01', 'Tabla tinglada',                 'Madera',       'un',      120,   50,   5200, 1, 1),
('MAD-CALI-01', 'Madera california',              'Madera',       'un',       70,   31,   4100, 1, 1),
('MAD-TERC-15', 'Terciado 15 mm',                 'Madera',       'placa',     3,    1,  32000, 1, 1),
('FER-T158-01', 'Tornillos 1 5/8" (caja)',        'Ferreteria',   'caja',     10,    4,   4500, 2, 2),
('FER-T114-01', 'Tornillos 1 1/4" (caja)',        'Ferreteria',   'caja',     12,    6,   4200, 2, 2),
('FER-T6X2-01', 'Tornillos 6 x 2" (caja)',        'Ferreteria',   'caja',      4,    1,   5200, 2, 2),
('FER-T34-01',  'Tornillos 3/4" (caja)',          'Ferreteria',   'caja',      7,    3,   3900, 2, 2),
('FER-T2-01',   'Tornillo 2"',                    'Ferreteria',   'un',      400,  100,     25, 2, 2),
('FER-T214-01', 'Tornillo 2 1/4"',                'Ferreteria',   'un',      150,   30,     30, 2, 2),
('FER-CL25-01', 'Clavo de pistola 25 mm (tira)',  'Ferreteria',   'tira',     20,    4,   1800, 2, 2),
('FER-CL35-01', 'Clavo de pistola 35 mm (tira)',  'Ferreteria',   'tira',     12,    4,   2100, 2, 2),
('FER-GOLI-01', 'Golilla',                        'Ferreteria',   'un',       50,    8,    120, 2, 2),
('FER-TUER-01', 'Tuerca',                         'Ferreteria',   'un',       50,    8,    150, 2, 2),
('FER-ZUNC-01', 'Zuncho',                         'Ferreteria',   'un',       12,    4,   3500, 2, 2),
('FER-HILO-01', 'Hilo',                           'Ferreteria',   'un',        5,    1,   2900, 2, 2),
('FER-BISA-01', 'Bisagra',                        'Ferreteria',   'un',       20,    4,   2800, 2, 2),
('FER-RETE-01', 'Retén',                          'Ferreteria',   'un',       16,    4,   1500, 2, 2),
('FER-TEJA-01', 'Teja asfáltica (bolsa)',         'Ferreteria',   'bolsa',     6,    3,  28000, 2, 2),
('FER-FIEL-01', 'Fieltro',                        'Ferreteria',   'm',        40,   10,    900, 2, 2),
('FER-ZINC-01', 'Plancha de zinc',                'Ferreteria',   'placa',     3,    1,  15000, 2, 2),
('FER-LIJE-01', 'Lija esponja',                   'Ferreteria',   'un',       15,    3,   1900, 2, 2),
('FER-L100-01', 'Lija orbital 100',               'Ferreteria',   'un',       40,   12,    450, 2, 2),
('FER-L120-01', 'Lija orbital 120',               'Ferreteria',   'un',       40,   13,    450, 2, 2),
('FER-L180-01', 'Lija orbital 150/180',           'Ferreteria',   'un',       50,   18,    450, 2, 2),
('FER-LGAL-01', 'Lija velcro galletera 180',      'Ferreteria',   'un',       30,   11,    600, 2, 2),
('FER-PNEG-01', 'Pintura negra',                  'Ferreteria',   'L',        12,    6,   7800, 2, 2),
('FER-PROB-01', 'Pintura roble',                  'Ferreteria',   'L',         4,    1,   8200, 2, 2),
('FER-AGUT-01', 'Agua Tech (protector)',          'Ferreteria',   'L',        10,  4.5,   9500, 2, 2),
('FER-DILU-01', 'Diluyente',                      'Ferreteria',   'L',         5,    1,   4500, 2, 2),
('FER-SILI-01', 'Silicona transparente',          'Ferreteria',   'un',        6,    1,   3900, 2, 2),
('FER-COLA-01', 'Cola fría',                      'Ferreteria',   'kg',        2,  0.5,   5200, 2, 2),
('FER-CUNQ-01', 'Cunquillo',                      'Ferreteria',   'un',       20,    5,    600, 2, 2),
('EQU-CABL-01', 'Cable eléctrico',                'Equipamiento', 'm',        50,    9,    650, 3, 3),
('EQU-LUZT-01', 'Luz tortuga',                    'Equipamiento', 'un',        4,    2,   6900, 3, 3),
('EQU-PANT-01', 'Pantalla de luz',                'Equipamiento', 'un',        4,    2,   3500, 3, 3),
('EQU-INTE-01', 'Interruptor',                    'Equipamiento', 'un',        6,    2,   2500, 3, 3),
('EQU-CDER-01', 'Caja de derivación',             'Equipamiento', 'un',        6,    3,   1800, 3, 3),
('EQU-REGL-01', 'Regleta',                        'Equipamiento', 'un',        4,    2,   5900, 3, 3),
('EQU-CALE-01', 'Calefactor eléctrico sauna',     'Equipamiento', 'un',        0,    1, 489000, 3, 3),
('ACC-HIGR-01', 'Higrómetro',                     'Accesorio',    'un',        3,    2,  14900, 3, 3),
('ACC-RELO-01', 'Reloj de arena',                 'Accesorio',    'un',        3,    2,   9900, 3, 3),
('ACC-BALD-01', 'Balde de sauna',                 'Accesorio',    'un',        3,    2,  18900, 3, 3),
('ACC-CUCH-01', 'Cucharón',                       'Accesorio',    'un',        3,    2,   9900, 3, 3),
('ACC-PIED-01', 'Piedra volcánica',               'Accesorio',    'un',       14,   24,   1200, 3, 3),
('ACC-VIDR-01', 'Vidrio',                         'Accesorio',    'un',        6,    5,  22000, 3, 3),
('ACC-MANI-01', 'Manilla',                        'Accesorio',    'un',        6,    4,   6500, 3, 3),
('ACC-ESCO-01', 'Escotilla chica',                'Accesorio',    'un',        3,    2,  12000, 3, 3),
('ACC-CELO-01', 'Celosía',                        'Accesorio',    'un',        4,    2,   7500, 3, 3);

-- Kardex: el stock de arriba es la carga inicial (conteo físico)
INSERT INTO movimiento_inventario (id_material, tipo, cantidad, stock_resultante, costo_unitario, referencia, id_usuario)
SELECT id_material, 'CARGA_INICIAL', stock_actual, stock_actual, costo_unitario, 'Conteo inicial', 2
  FROM material;

-- Alertas por bajo mínimo del conteo inicial
INSERT INTO alerta_stock (id_material, id_nota_venta, tipo, stock_disponible, stock_requerido)
SELECT id_material, NULL, 'BajoMinimo', stock_actual, stock_minimo
  FROM material WHERE stock_actual < stock_minimo;

-- ---------------------------------------------------------------------
-- Productos y recetas (fichas de producción)
-- ---------------------------------------------------------------------
INSERT INTO producto (codigo_sku, nombre, categoria, descripcion, medidas, precio_venta, tiempo_fabricacion_dias) VALUES
('SAU-BAR-220', 'Sauna Barril con antesala 220 cm', 'Sauna_Ext',
 'Sauna exterior tipo barril con antesala, 4 personas. Responsable ficha: Ricardo Caamaño', '220 cm de largo', 3200000, 15),
('SAU-MED-2P',  'Sauna Exterior 2 personas Mediterráneo', 'Sauna_Ext',
 'Sauna exterior modelo Mediterráneo, 2 personas. Responsable ficha: Víctor Anrique', NULL, 2400000, 10);

-- Sauna Barril con antesala 220 cm (38 ítems)
INSERT INTO receta_producto (id_producto, id_material, cantidad_requerida, observacion)
SELECT p.id_producto, m.id_material, x.cant, x.obs
FROM (VALUES
  ROW('MAD-MACH-01', 100,  NULL),
  ROW('MAD-CEPI-01',   3,  NULL),
  ROW('FER-T158-01',   3,  NULL),
  ROW('FER-T114-01',   4,  NULL),
  ROW('FER-T6X2-01',   1,  NULL),
  ROW('FER-TEJA-01', 2.5,  'Cantidad fija para este modelo (2 bolsas + 1/2)'),
  ROW('FER-FIEL-01', 8.8,  'Cantidad fija para este modelo'),
  ROW('FER-ZUNC-01',   4,  'Cantidad fija para este modelo'),
  ROW('FER-HILO-01',   1,  'Cantidad fija para este modelo'),
  ROW('FER-GOLI-01',   4,  'Cantidad fija para este modelo'),
  ROW('FER-TUER-01',   4,  'Cantidad fija para este modelo'),
  ROW('MAD-PINB-01',   2,  'Patas'),
  ROW('FER-CL25-01',   2,  NULL),
  ROW('EQU-CABL-01',   6,  'Aproximado'),
  ROW('MAD-CEDR-01',   1,  'Puerta'),
  ROW('FER-T34-01',    3,  NULL),
  ROW('FER-LIJE-01',   2,  NULL),
  ROW('FER-L180-01',   6,  NULL),
  ROW('FER-L100-01',   5,  NULL),
  ROW('FER-LGAL-01',  10,  NULL),
  ROW('FER-PNEG-01',   6,  NULL),
  ROW('FER-AGUT-01',   2,  NULL),
  ROW('FER-L120-01',   8,  NULL),
  ROW('FER-SILI-01',   1,  NULL),
  ROW('ACC-HIGR-01',   1,  NULL),
  ROW('ACC-RELO-01',   1,  NULL),
  ROW('ACC-BALD-01',   1,  NULL),
  ROW('ACC-CUCH-01',   1,  NULL),
  ROW('ACC-PIED-01',  12,  NULL),
  ROW('ACC-VIDR-01',   3,  NULL),
  ROW('ACC-MANI-01',   2,  NULL),
  ROW('FER-BISA-01',   2,  NULL),
  ROW('FER-RETE-01',   2,  NULL),
  ROW('EQU-LUZT-01',   1,  NULL),
  ROW('EQU-PANT-01',   1,  NULL),
  ROW('EQU-INTE-01',   1,  NULL),
  ROW('EQU-CDER-01',   1,  NULL),
  ROW('EQU-REGL-01',   1,  'Cantidad no indicada en la ficha: se asume 1')
) AS x(codigo, cant, obs)
JOIN material m ON m.codigo_interno = x.codigo
JOIN producto p ON p.codigo_sku = 'SAU-BAR-220';

-- Sauna Exterior 2 personas Mediterráneo (38 ítems)
INSERT INTO receta_producto (id_producto, id_material, cantidad_requerida, observacion)
SELECT p.id_producto, m.id_material, x.cant, x.obs
FROM (VALUES
  ROW('MAD-TING-01',  49,  NULL),
  ROW('FER-T114-01',   6,  NULL),
  ROW('FER-T2-01',   100,  NULL),
  ROW('FER-T214-01',  30,  NULL),
  ROW('MAD-CE14-01',  21,  NULL),
  ROW('FER-COLA-01', 0.2,  '200 gramos'),
  ROW('MAD-TERC-15', 0.5,  '1/2 placa'),
  ROW('FER-CL35-01',   4,  NULL),
  ROW('FER-L180-01',  12,  NULL),
  ROW('FER-LGAL-01',   1,  NULL),
  ROW('MAD-CALI-01',  31,  NULL),
  ROW('FER-DILU-01',   1,  NULL),
  ROW('EQU-CABL-01',   3,  NULL),
  ROW('FER-PROB-01',   1,  NULL),
  ROW('FER-AGUT-01', 2.5,  NULL),
  ROW('FER-CUNQ-01',   5,  NULL),
  ROW('FER-ZINC-01',   1,  NULL),
  ROW('MAD-CEDR-01',   1,  NULL),
  ROW('ACC-ESCO-01',   2,  NULL),
  ROW('FER-L100-01',   7,  NULL),
  ROW('FER-L120-01',   5,  NULL),
  ROW('FER-RETE-01',   2,  NULL),
  ROW('FER-BISA-01',   2,  NULL),
  ROW('EQU-LUZT-01',   1,  'Cantidad fija para este modelo'),
  ROW('EQU-PANT-01',   1,  NULL),
  ROW('EQU-INTE-01',   1,  NULL),
  ROW('EQU-CDER-01',   2,  NULL),
  ROW('EQU-CALE-01',   1,  'Cantidad fija para este modelo'),
  ROW('ACC-HIGR-01',   1,  'Cantidad fija para este modelo'),
  ROW('ACC-RELO-01',   1,  'Cantidad fija para este modelo'),
  ROW('ACC-PIED-01',  12,  'Cantidad fija para este modelo'),
  ROW('ACC-VIDR-01',   2,  NULL),
  ROW('ACC-MANI-01',   2,  'Cantidad fija para este modelo'),
  ROW('ACC-CUCH-01',   1,  'Cantidad fija para este modelo'),
  ROW('ACC-BALD-01',   1,  'Cantidad fija para este modelo'),
  ROW('FER-LIJE-01',   1,  NULL),
  ROW('ACC-CELO-01',   2,  NULL),
  ROW('EQU-REGL-01',   1,  NULL)
) AS x(codigo, cant, obs)
JOIN material m ON m.codigo_interno = x.codigo
JOIN producto p ON p.codigo_sku = 'SAU-MED-2P';

-- ---------------------------------------------------------------------
-- Notas de venta de ejemplo (entran por el mismo procedimiento que la API)
--   1941: Sauna Barril → hay stock → Aprobada, genera comanda
--   1942: Sauna Mediterráneo → falta calefactor y piedras → RechazadaStock
-- ---------------------------------------------------------------------
CALL sp_registrar_nota_venta_json('{
  "folio": "1941", "fecha_venta": "2026-10-20", "fecha_despacho": "2026-11-10",
  "cliente": {"rut": "9222333-4", "nombres": "Ronaldo", "apellidos": "Franco",
              "direccion": "Camino a Quinchamalí km 3", "comuna": "Chillán",
              "telefono": "+56 9 1111 2222", "correo": "rfranco@correo.cl"},
  "detalles": [{"codigo_sku": "SAU-BAR-220", "cantidad": 1, "precio_unitario": 3200000,
                "diseno_personalizado": "Antesala con banca, vidrio frontal"}]
}', 1, @nota1, @estado1);

CALL sp_registrar_nota_venta_json('{
  "folio": "1942", "fecha_venta": "2026-10-24", "fecha_despacho": "2026-11-20",
  "cliente": {"rut": "15444555-6", "nombres": "Isabel", "apellidos": "Rojas",
              "direccion": "Los Aromos 345", "comuna": "Bulnes",
              "telefono": "+56 9 3333 4444", "correo": "irojas@correo.cl"},
  "detalles": [{"codigo_sku": "SAU-MED-2P", "cantidad": 1, "precio_unitario": 2400000,
                "diseno_personalizado": "Pintura roble, 2 celosías"}]
}', 1, @nota2, @estado2);

-- Retazos de ejemplo (el trigger clasifica supera_minimo y estado)
INSERT INTO merma (id_material, largo_cm, ancho_cm, espesor_cm, id_bodega, id_usuario_registro) VALUES
((SELECT id_material FROM material WHERE codigo_interno = 'MAD-MACH-01'), 85, 12, 2.5, 1, 2),
((SELECT id_material FROM material WHERE codigo_interno = 'MAD-TING-01'), 40,  8, 1.8, 1, 3),
((SELECT id_material FROM material WHERE codigo_interno = 'MAD-MACH-01'), 12,  5, 1.5, 1, 2);

SET @app_usuario = NULL;
