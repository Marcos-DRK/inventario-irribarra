# Sistema de Gestión de Inventario · Taller Irribarra

Saunas · Tinas · Wellness (Bulnes) — Administración de Bases de Datos.
Integrantes: Claudio Palma y Marcos Salazar · Profesor: Luis Gómez Soto.

Inventario web local que recibe las notas de venta, **descuenta automáticamente los materiales según la receta
de cada producto**, alerta faltantes, registra compras, reutiliza retazos de madera y entrega reportes.

```
Navegador ─► http://localhost:8000 ─► API Python FastAPI ─► MySQL 8.4 (:3306)
             (web Angular 22 construida  + /api JSON + JWT)   triggers · procedimientos · vistas
```

| Carpeta | Contenido |
|---|---|
| `db/` | Scripts SQL, instalador, respaldo/restauración, restablecer root |
| `backend/` | API FastAPI (login, conexión por rol, endpoints, reportes PDF/Excel) |
| `frontend/` | Interfaz Angular 22 (13 pantallas basadas en los mockups del informe) |
| `docs/` | [Base de datos](docs/BASE_DE_DATOS.md) · [Manual de instalación](docs/MANUAL_INSTALACION.md) |

**Inicio rápido:** `db\instalar.ps1` (una vez) → `iniciar.ps1` → http://localhost:8000 → `admin` / `Admin2026!`

---

## Cumplimiento de la rúbrica

| Exigencia | Dónde se cumple |
|---|---|
| 1. Crear o fortalecer una BD | MySQL 8.4 / InnoDB: 19 tablas (15 del informe + kardex, 2 bitácoras, parámetros), 9 vistas, 15 triggers, 7 procedimientos con transacciones, roles del motor. Ver [BASE_DE_DATOS.md](docs/BASE_DE_DATOS.md). |
| 2. Ingresar como administrador y otros usuarios con sus atributos | Login con contraseña bcrypt. Roles **Administrador** (`admin`) y **Trabajador** (`ricardo.trab`, `victor.trab`). Cada usuario tiene RUT, nombres, correo, rol, estado, fecha de creación y último acceso. CRUD en *Usuarios*. |
| 3. Pantallas interactivas para los distintos usuarios | El menú y las rutas cambian según el rol. El trabajador opera el taller (Kanban, mermas, compras, conteos); el administrador además simula y aprueba ventas, da de alta materiales, ve reportes, usuarios y bitácora. La base también lo impide: cada rol se conecta con su propio usuario de MySQL. |
| 4. Al menos dos reportes en Excel o PDF | **Reporte mensual PDF** (consumo por categoría, materiales más consumidos, alertas, ahorro por retazos). **Inventario Excel** (3 hojas: stock con estados, alertas pendientes, resumen por bodega). **Kardex Excel** por material. |
| Esquema de la BD con los usuarios que acceden | Diagrama ER y matriz de privilegios por rol en [BASE_DE_DATOS.md](docs/BASE_DE_DATOS.md). |
| Documentación de acciones y datos de registro para acceder | Credenciales y pasos en el [manual](docs/MANUAL_INSTALACION.md). La pantalla **Bitácora** muestra cada acceso (OK, FALLIDO, LOGOUT, IP) y cada cambio (valor anterior → nuevo, quién y cuándo). |
| Recuperación ante fallas | `db\respaldo.ps1` / `db\restaurar.ps1` (probado: recupera datos, triggers y procedimientos) + transacciones con ROLLBACK. |

---

## Guion para la presentación (≈ 6 minutos)

1. **Login como `admin`**: dashboard con 1 nota rechazada, 1 comanda en espera y alertas activas.
2. **Notas de Venta → N° 1942**: la verificación automática muestra que faltan *calefactor* y *piedras volcánicas*.
   Explicar el trigger `trg_verificar_stock_venta`.
3. **+ Simular nota de venta** → *Ver JSON*: es lo que enviaría la plataforma web. Enviar una *Sauna Mediterráneo*:
   queda **rechazada por stock** en una sola transacción.
4. En la nota 1942 → **Generar orden de compra**: la factura se llena con los faltantes. Registrarla y mostrar que
   las alertas se **resuelven solas** (trigger `trg_ingreso_por_factura`).
5. Volver a la nota 1942 → **Volver a verificar y aprobar**: se crea la comanda.
6. **Cerrar sesión → `ricardo.trab`**: el menú ya no muestra Reportes, Usuarios ni Bitácora.
7. **Comandas**: abrir la comanda de la nota 1941 → **Reservar** el retazo de machihembrado → arrastrarla a
   **Fabricación**. Mostrar en Materiales → *Kardex* que salieron 99 tablas (y no 100: el retazo reemplazó una).
8. Intentar mover otra comanda saltándose etapas: el SGBD lo rechaza con su propio mensaje.
9. **Mermas → + Registrar retazo** de 20 × 5 cm: queda como descarte automáticamente.
10. **Login `admin` → Reportes**: exportar el **PDF** mensual y el **Excel** de inventario.
11. **Bitácora**: accesos (incluido algún intento fallido) y cambios de stock con usuario y hora.

> Para dejar la base como al inicio antes de presentar: `db\instalar.ps1`.
