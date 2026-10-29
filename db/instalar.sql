-- Ejecuta todos los scripts en orden (lo llama instalar.ps1 desde la carpeta db)
SOURCE 01_schema.sql
SOURCE 02_views.sql
SOURCE 03_triggers.sql
SOURCE 04_procedures.sql
SOURCE 05_security.sql
SOURCE 06_seed.sql
SELECT 'Base de datos inventario_irribarra instalada' AS resultado;
