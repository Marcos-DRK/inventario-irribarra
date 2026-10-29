import { CurrencyPipe, DatePipe, DecimalPipe } from '@angular/common';
import { Component, inject, input, signal } from '@angular/core';
import { RouterLink } from '@angular/router';

import { Api, mensajeError } from '../../core/api';
import { Estado, NombrePipe, Notificador } from '../../core/ui';
import { Material } from './materiales';

interface Movimiento {
  id_movimiento: number; fecha: string; tipo: string; cantidad: number; stock_resultante: number;
  costo_unitario: number; referencia: string | null; usuario: string | null;
}

@Component({
  selector: 'app-material-detalle',
  imports: [RouterLink, Estado, NombrePipe, DatePipe, DecimalPipe, CurrencyPipe],
  template: `
    <div class="row" style="margin-bottom: 14px">
      <a class="btn chico" routerLink="/materiales">← Volver</a>
      <span class="spacer"></span>
      @if (m()) { <button class="btn" type="button" (click)="exportar()">⇩ Exportar kardex (Excel)</button> }
    </div>

    @if (m(); as m) {
      <div class="stack">
        <div class="grid grid-4">
          <div class="card kpi">
            <div class="etiqueta">{{ m.codigo_interno }} · {{ m.tipo | nombre }}</div>
            <div class="valor" style="font-size: 18px">{{ m.nombre }}</div>
            <div class="pie">{{ m.bodega }} · <app-estado [valor]="m.estado_stock" /></div>
          </div>
          <div class="card kpi">
            <div class="etiqueta">Stock actual</div>
            <div class="valor">{{ m.stock_actual | number:'1.0-2' }} <small>{{ m.unidad_medida }}</small></div>
            <div class="pie">Mínimo: {{ m.stock_minimo | number:'1.0-2' }} {{ m.unidad_medida }}</div>
          </div>
          <div class="card kpi">
            <div class="etiqueta">Disponible</div>
            <div class="valor">{{ m.disponible | number:'1.0-2' }}</div>
            <div class="pie">{{ m.comprometido | number:'1.0-2' }} comprometido por comandas en espera</div>
          </div>
          <div class="card kpi">
            <div class="etiqueta">Valor en bodega</div>
            <div class="valor">{{ m.valor_stock | currency:'CLP':'symbol-narrow':'1.0-0' }}</div>
            <div class="pie">Costo unitario {{ m.costo_unitario | currency:'CLP':'symbol-narrow':'1.0-0' }}</div>
          </div>
        </div>

        @if (usadoEn().length) {
          <div class="card card-body small">
            <strong>Se usa en:</strong>
            @for (u of usadoEn(); track u.codigo_sku) { <span class="badge" style="margin-left: 6px">{{ u.nombre }} · {{ u.cantidad_requerida | number:'1.0-2' }} {{ m.unidad_medida }}</span> }
          </div>
        }

        <div class="card">
          <div class="card-header"><h2>Kardex · entradas y salidas</h2></div>
          <div class="tabla-wrap">
            <table class="tabla">
              <thead><tr><th>Fecha</th><th>Movimiento</th><th>Referencia</th><th class="num">Entrada</th>
                         <th class="num">Salida</th><th class="num">Saldo</th><th class="num">Costo unit.</th><th>Usuario</th></tr></thead>
              <tbody>
                @for (mv of movimientos(); track mv.id_movimiento) {
                  <tr>
                    <td class="nowrap">{{ mv.fecha | date:'dd-MM-yyyy HH:mm' }}</td>
                    <td>{{ mv.tipo | nombre }}</td>
                    <td>{{ mv.referencia || '—' }}</td>
                    <td class="num" style="color: var(--ok)">{{ mv.cantidad > 0 ? (mv.cantidad | number:'1.0-2') : '' }}</td>
                    <td class="num" style="color: var(--rojo)">{{ mv.cantidad < 0 ? (-mv.cantidad | number:'1.0-2') : '' }}</td>
                    <td class="num"><strong>{{ mv.stock_resultante | number:'1.0-2' }}</strong></td>
                    <td class="num">{{ mv.costo_unitario | currency:'CLP':'symbol-narrow':'1.0-0' }}</td>
                    <td>{{ mv.usuario || 'sistema' }}</td>
                  </tr>
                } @empty {
                  <tr><td colspan="8" class="vacio">Sin movimientos</td></tr>
                }
              </tbody>
            </table>
          </div>
        </div>
      </div>
    } @else {
      <p class="muted">Cargando…</p>
    }`,
})
export class MaterialDetalle {
  id = input.required<string>();

  private api = inject(Api);
  private avisos = inject(Notificador);
  protected m = signal<Material | null>(null);
  protected usadoEn = signal<{ codigo_sku: string; nombre: string; cantidad_requerida: number }[]>([]);
  protected movimientos = signal<Movimiento[]>([]);

  async ngOnInit() {
    try {
      const [m, k] = await Promise.all([
        this.api.get<Material & { usado_en: [] }>(`/materiales/${this.id()}`),
        this.api.get<Movimiento[]>(`/materiales/${this.id()}/kardex`),
      ]);
      this.m.set(m);
      this.usadoEn.set(m.usado_en);
      this.movimientos.set(k);
    } catch (e) {
      this.avisos.error(mensajeError(e));
    }
  }

  exportar() {
    this.api.descargar(`/reportes/kardex/${this.id()}/excel`).catch(e => this.avisos.error(mensajeError(e)));
  }
}
