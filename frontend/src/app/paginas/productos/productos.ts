import { CurrencyPipe } from '@angular/common';
import { Component, inject, signal } from '@angular/core';
import { Router, RouterLink } from '@angular/router';

import { Api, mensajeError } from '../../core/api';
import { Auth } from '../../core/auth';
import { Estado, NombrePipe, Notificador } from '../../core/ui';
import { ProductoForm } from './producto-form';

interface Producto {
  id_producto: number; codigo_sku: string; nombre: string; categoria: string; descripcion: string | null;
  medidas: string | null; precio_venta: number; tiempo_fabricacion_dias: number; estado: string;
  items_receta: number; costo_materiales: number;
}

@Component({
  selector: 'app-productos',
  imports: [RouterLink, Estado, NombrePipe, CurrencyPipe, ProductoForm],
  template: `
    @if (auth.esAdmin()) {
      <div class="row end" style="margin-bottom: 14px">
        <button class="btn primario" type="button" (click)="creando.set(true)">+ Nuevo producto</button>
      </div>
    }
    <app-producto-form [abierto]="creando()" (cerrar)="creando.set(false)" (guardado)="creado($event)" />
    <div class="grid grid-2">
      @for (p of productos(); track p.id_producto) {
        <a class="card producto" [routerLink]="['/productos', p.id_producto]">
          <div class="card-header">
            <div>
              <h2>{{ p.nombre }}</h2>
              <span class="muted small mono">{{ p.codigo_sku }}</span>
            </div>
            <app-estado [valor]="p.estado" />
          </div>
          <div class="card-body">
            <p class="muted small" style="margin-top: 0">{{ p.descripcion }}</p>
            <dl class="datos">
              <dt>Categoría</dt><dd>{{ p.categoria | nombre }}</dd>
              <dt>Precio de venta</dt><dd>{{ p.precio_venta | currency:'CLP':'symbol-narrow':'1.0-0' }}</dd>
              <dt>Ítems de la receta</dt><dd>{{ p.items_receta }}</dd>
              <dt>Costo de materiales</dt><dd>{{ p.costo_materiales | currency:'CLP':'symbol-narrow':'1.0-0' }}</dd>
              <dt>Fabricación</dt><dd>{{ p.tiempo_fabricacion_dias }} días</dd>
            </dl>
          </div>
        </a>
      } @empty {
        <p class="muted">Cargando…</p>
      }
    </div>`,
  styles: `.producto { text-decoration: none; color: inherit; display: block; }
           .producto:hover { border-color: var(--verde); }`,
})
export class Productos {
  private api = inject(Api);
  private avisos = inject(Notificador);
  private router = inject(Router);
  protected auth = inject(Auth);
  protected productos = signal<Producto[]>([]);
  protected creando = signal(false);

  constructor() {
    this.api.get<Producto[]>('/productos').then(p => this.productos.set(p))
      .catch(e => this.avisos.error(mensajeError(e)));
  }

  /** Producto recién creado: se abre su detalle para cargar la receta. */
  creado(id: number) {
    this.creando.set(false);
    this.router.navigate(['/productos', id]);
  }
}
