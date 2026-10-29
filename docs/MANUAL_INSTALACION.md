# Manual de instalación y uso

Sistema local (sin dominio ni hosting): todo corre en el mismo computador.

| Componente | Versión probada | Puerto |
|---|---|---|
| MySQL Server | 8.4.9 LTS (servicio `MySQL84`) | 3306 |
| Python | 3.14 (FastAPI, PyMySQL, bcrypt, PyJWT, openpyxl, reportlab) | 8000 |
| Node.js / Angular | Node 24 · Angular 22.2 · TypeScript 6 | 4200 |

## 1. Requisitos (una sola vez)

1. **MySQL 8.4**
   ```
   winget install --id Oracle.MySQL --version 8.4.9
   ```
   Luego abrir *MySQL Configurator* → *Development Computer*, puerto 3306, definir la contraseña de `root`,
   servicio `MySQL84` con inicio automático.
   > Si XAMPP está instalado, **no iniciar su MySQL** (usa el mismo puerto 3306).
2. **Python 3.12 o superior** (con la opción *Add to PATH*).
3. **Node.js 22 o superior** y Angular CLI: `npm install -g @angular/cli`.

## 2. Instalar la base de datos

Desde la carpeta `inventario-irribarra`, en una ventana de PowerShell:

```
powershell -ExecutionPolicy Bypass -File db\instalar.ps1
```

- Pide la contraseña de `root` (no se muestra al escribir).
- Crea la base `inventario_irribarra` con todas sus tablas, vistas, triggers, procedimientos y datos iniciales.
- Crea los usuarios de conexión `app_admin` y `app_trabajador` con contraseñas aleatorias y las guarda en `backend\.env`.
- **Reinstalar borra los datos** y vuelve a los datos de prueba.

## 3. Iniciar el sistema

```
powershell -ExecutionPolicy Bypass -File iniciar.ps1
```

- Abre el navegador en **http://localhost:8000** cuando el sistema está listo. La API sirve la interfaz web
  ya construida, así que hay **un solo programa y una sola ventana**.
- La primera vez tarda unos minutos: instala las dependencias de Python y de Angular y **construye** la interfaz
  (`construir.ps1`).
- Para detenerlo: cerrar la ventana o presionar `Ctrl+C`.

| Necesito… | Comando |
|---|---|
| Volver a construir la web tras cambiar el código de `frontend/` | `powershell -ExecutionPolicy Bypass -File construir.ps1` |
| Solo la API | `powershell -ExecutionPolicy Bypass -File backend\iniciar_api.ps1` → http://localhost:8000/docs |
| Desarrollo con recarga automática | API iniciada + `cd frontend` y `npm start` → http://localhost:4200 |

## 4. Ingresar

| Usuario | Contraseña | Rol |
|---|---|---|
| `admin` | `Admin2026!` | Administrador |
| `ricardo.trab` | `Taller2026!` | Trabajador de taller |
| `victor.trab` | `Taller2026!` | Trabajador de taller |

Cada ingreso (correcto o fallido) queda en **Bitácora → Accesos al sistema**.
Se recomienda cambiar estas contraseñas desde **Usuarios** antes de usar el sistema con datos reales.

## 5. Probar la API sin la interfaz

1. Abrir http://localhost:8000/docs
2. `POST /api/auth/login` → *Try it out* → `{"usuario": "admin", "password": "Admin2026!"}` → copiar el `token`.
3. Botón **Authorize** → pegar el token.
4. Probar cualquier endpoint. Ejemplo de nota de venta desde la plataforma web
   (`POST /api/integracion/notas-venta`):
   ```json
   {
     "folio": "1943",
     "fecha_despacho": "2026-11-30",
     "cliente": {"rut": "17888999-0", "nombres": "Juan Pablo", "apellidos": "Baldrón", "comuna": "Bulnes"},
     "detalles": [{"codigo_sku": "SAU-MED-2P", "cantidad": 1, "diseno_personalizado": "Ventanas 60x25"}]
   }
   ```

## 6. Respaldos

| Acción | Comando |
|---|---|
| Crear respaldo | `powershell -ExecutionPolicy Bypass -File db\respaldo.ps1` |
| Restaurar el último | `powershell -ExecutionPolicy Bypass -File db\restaurar.ps1` |

Para respaldo diario automático: *Programador de tareas* → *Crear tarea básica* → diaria →
programa `powershell.exe`, argumentos `-ExecutionPolicy Bypass -File "<ruta>\db\respaldo.ps1"`.
(Como pide la contraseña de root, para automatizarlo se puede crear un usuario de MySQL solo para respaldos.)

## 7. Problemas frecuentes

| Síntoma | Solución |
|---|---|
| "No hay conexión con la API" en el login | La API no está iniciada: ejecutar `iniciar.ps1`. |
| `Falta backend\.env` al iniciar | Ese archivo guarda las claves de conexión y no se copia al mover el proyecto: copiarlo desde la carpeta anterior o ejecutar `db\instalar.ps1` (reinstala la base con datos de prueba). |
| La API responde "No hay conexión con la base de datos" | El servicio `MySQL84` está detenido (`services.msc` → iniciar) o falta `db\instalar.ps1`. |
| `ERROR 1045 Access denied for user 'root'` | Contraseña de root incorrecta. Si se olvidó: `db\restablecer_root.ps1` como administrador. |
| `ng build` / `npm start` se cierra con un error nativo | Ya está desactivada la caché de Angular (`ng cache disable`); si reaparece, borrar `frontend\.angular`. |
| Errores de rutas largas al instalar dependencias de Python | El entorno virtual ya se crea en `%USERPROFILE%\.inventario-irribarra\venv` (ruta corta). |
| Puerto 3306 ocupado | Detener el MySQL de XAMPP. |
