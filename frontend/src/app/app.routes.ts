import { Routes } from '@angular/router';

import { adminGuard, authGuard } from './core/auth';
import { Shell } from './layout/shell';

const p = (titulo: string, subtitulo: string) => ({ titulo, subtitulo });

export const routes: Routes = [
  { path: 'login', loadComponent: () => import('./paginas/login/login').then(m => m.Login) },
  {
    path: '',
    component: Shell,
    canActivate: [authGuard],
    children: [
      { path: '', pathMatch: 'full', redirectTo: 'dashboard' },
      { path: 'dashboard', data: p('Dashboard', 'Resumen general del taller'),
        loadComponent: () => import('./paginas/dashboard/dashboard').then(m => m.Dashboard) },
      { path: 'notas-venta', data: p('Notas de Venta', 'Detalle y verificación automática de stock'),
        loadComponent: () => import('./paginas/notas-venta/notas-venta').then(m => m.NotasVenta) },
      { path: 'notas-venta/:id', data: p('Notas de Venta', 'Detalle y verificación automática de stock'),
        loadComponent: () => import('./paginas/notas-venta/nota-detalle').then(m => m.NotaDetalle) },
      { path: 'comandas', data: p('Comandas de Taller', 'Flujo Kanban de producción'),
        loadComponent: () => import('./paginas/comandas/comandas').then(m => m.Comandas) },
      { path: 'materiales', data: p('Materiales e Insumos', 'Control de stock por bodega'),
        loadComponent: () => import('./paginas/materiales/materiales').then(m => m.Materiales) },
      { path: 'materiales/:id', data: p('Materiales e Insumos', 'Kardex: historial de entradas y salidas'),
        loadComponent: () => import('./paginas/materiales/material-detalle').then(m => m.MaterialDetalle) },
      { path: 'productos', data: p('Productos y Recetas', 'Despiece de materiales por producto'),
        loadComponent: () => import('./paginas/productos/productos').then(m => m.Productos) },
      { path: 'productos/:id', data: p('Productos y Recetas', 'Despiece de materiales por producto'),
        loadComponent: () => import('./paginas/productos/producto-detalle').then(m => m.ProductoDetalle) },
      { path: 'compras', data: p('Compras', 'Facturas de proveedor e ingreso de stock'),
        loadComponent: () => import('./paginas/compras/compras').then(m => m.Compras) },
      { path: 'mermas', data: p('Mermas y Sobrantes', 'Clasificación y reutilización de retazos de madera'),
        loadComponent: () => import('./paginas/mermas/mermas').then(m => m.Mermas) },
      { path: 'alertas', data: p('Alertas de Stock', 'Insumos faltantes y bajo el mínimo'),
        loadComponent: () => import('./paginas/alertas/alertas').then(m => m.Alertas) },
      { path: 'reportes', canActivate: [adminGuard], data: p('Reportes Mensuales', 'Consumo, alertas y ahorro por reciclaje'),
        loadComponent: () => import('./paginas/reportes/reportes').then(m => m.Reportes) },
      { path: 'usuarios', canActivate: [adminGuard], data: p('Usuarios', 'Cuentas de acceso al sistema'),
        loadComponent: () => import('./paginas/usuarios/usuarios').then(m => m.Usuarios) },
      { path: 'bitacora', canActivate: [adminGuard], data: p('Bitácora', 'Registro de accesos y cambios'),
        loadComponent: () => import('./paginas/bitacora/bitacora').then(m => m.Bitacora) },
    ],
  },
  { path: '**', redirectTo: '' },
];
