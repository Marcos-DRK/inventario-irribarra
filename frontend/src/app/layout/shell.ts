import { Component, inject, signal } from '@angular/core';
import { ActivatedRoute, NavigationEnd, Router, RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { filter } from 'rxjs';

import { Auth } from '../core/auth';

interface Enlace { ruta: string; texto: string; icono: string; soloAdmin?: boolean; }

/** Estructura general: barra lateral (como en los mockups) + encabezado + contenido. */
@Component({
  selector: 'app-shell',
  imports: [RouterOutlet, RouterLink, RouterLinkActive],
  templateUrl: './shell.html',
  styleUrl: './shell.css',
})
export class Shell {
  protected auth = inject(Auth);
  private router = inject(Router);
  private ruta = inject(ActivatedRoute);

  protected titulo = signal('');
  protected subtitulo = signal('');
  protected menuAbierto = signal(false);

  protected grupos: { nombre: string; enlaces: Enlace[] }[] = [
    { nombre: 'Operación', enlaces: [
      { ruta: '/dashboard', texto: 'Dashboard', icono: '◆' },
      { ruta: '/notas-venta', texto: 'Notas de Venta', icono: '▤' },
      { ruta: '/comandas', texto: 'Comandas (taller)', icono: '⚒' },
    ] },
    { nombre: 'Inventario', enlaces: [
      { ruta: '/materiales', texto: 'Materiales e Insumos', icono: '▦' },
      { ruta: '/productos', texto: 'Productos y Recetas', icono: '▣' },
      { ruta: '/compras', texto: 'Compras', icono: '⇩' },
      { ruta: '/mermas', texto: 'Mermas y Sobrantes', icono: '♻' },
      { ruta: '/alertas', texto: 'Alertas de Stock', icono: '⚠' },
    ] },
    { nombre: 'Gestión', enlaces: [
      { ruta: '/reportes', texto: 'Reportes Mensuales', icono: '▥', soloAdmin: true },
      { ruta: '/usuarios', texto: 'Usuarios', icono: '☺', soloAdmin: true },
      { ruta: '/bitacora', texto: 'Bitácora', icono: '☰', soloAdmin: true },
    ] },
  ];

  constructor() {
    this.actualizarTitulo();
    this.router.events.pipe(filter(e => e instanceof NavigationEnd)).subscribe(() => {
      this.actualizarTitulo();
      this.menuAbierto.set(false);
    });
  }

  private actualizarTitulo() {
    let r = this.ruta;
    while (r.firstChild) r = r.firstChild;
    // Durante la primera navegación la ruta aún no tiene snapshot
    this.titulo.set(r.snapshot?.data['titulo'] ?? '');
    this.subtitulo.set(r.snapshot?.data['subtitulo'] ?? '');
  }
}
