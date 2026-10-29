import { CurrencyPipe, DecimalPipe } from '@angular/common';
import { Component, inject, input, signal } from '@angular/core';
import { RouterLink } from '@angular/router';

import { Api, mensajeError } from '../../core/api';
import { NombrePipe, Notificador } from '../../core/ui';

interface LineaReceta {
  id_receta: number; id_material: number; codigo_interno: string; material: string; tipo: string;
  unidad_medida: string; cantidad_requerida: number; disponible: number; costo_linea: number;
  alcanza_para: number; observacion: string | null;
}
interface DatosProducto {
  nombre: string; codigo_sku: string; medidas: string | null; precio_venta: number;
  receta: LineaReceta[]; unidades_fabricables: number; costo_materiales: number;
}

@Component({
  selector: 'app-producto-detalle',
  imports: [RouterLink, NombrePipe, DecimalPipe, CurrencyPipe],
  template: `
    <div class="row" style="margin-bottom: 14px"><a class="btn chico" routerLink="/productos">← Volver</a></div>
    @if (p(); as p) {
      <div class="stack">
        <div class="grid grid-4">
          <div class="card kpi"><div class="etiqueta">{{ p.codigo_sku }}</div>
            <div class="valor" style="font-size: 17px">{{ p.nombre }}</div><div class="pie">{{ p.medidas || '' }}</div></div>
          <div class="card kpi"><div class="etiqueta">Precio de venta</div>
            <div class="valor">{{ p.precio_venta | currency:'CLP':'symbol-narrow':'1.0-0' }}</div></div>
          <div class="card kpi"><div class="etiqueta">Costo de materiales</div>
            <div class="valor">{{ p.costo_materiales | currency:'CLP':'symbol-narrow':'1.0-0' }}</div>
            <div class="pie">Margen bruto {{ (p.precio_venta - p.costo_materiales) | currency:'CLP':'symbol-narrow':'1.0-0' }}</div></div>
          <div class="card kpi"><div class="etiqueta">Se pueden fabricar hoy</div>
            <div class="valor" [style.color]="p.unidades_fabricables ? 'var(--ok)' : 'var(--rojo)'">{{ p.unidades_fabricables }}</div>
            <div class="pie">unidades con el stock disponible</div></div>
        </div>
        <div class="card">
          <div class="card-header"><h2>Receta / despiece ({{ p.receta.length }} ítems)</h2></div>
          <div class="tabla-wrap">
            <table class="tabla">
              <thead><tr><th>Código</th><th>Material</th><th>Tipo</th><th class="num">Cantidad</th>
                         <th class="num">Disponible</th><th class="num">Alcanza para</th><th class="num">Costo</th><th>Observación</th></tr></thead>
              <tbody>
                @for (l of p.receta; track l.id_receta) {
                  <tr>
                    <td class="mono"><a [routerLink]="['/materiales', l.id_material]">{{ l.codigo_interno }}</a></td>
                    <td>{{ l.material }}</td>
                    <td>{{ l.tipo | nombre }}</td>
                    <td class="num">{{ l.cantidad_requerida | number:'1.0-2' }} {{ l.unidad_medida }}</td>
                    <td class="num">{{ l.disponible | number:'1.0-2' }}</td>
                    <td class="num" [style.color]="l.alcanza_para < 1 ? 'var(--rojo)' : ''">{{ l.alcanza_para }}</td>
                    <td class="num">{{ l.costo_linea | currency:'CLP':'symbol-narrow':'1.0-0' }}</td>
                    <td class="small muted">{{ l.observacion || '' }}</td>
                  </tr>
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
export class ProductoDetalle {
  id = input.required<string>();
  private api = inject(Api);
  private avisos = inject(Notificador);
  protected p = signal<DatosProducto | null>(null);

  ngOnInit() {
    this.api.get<DatosProducto>(`/productos/${this.id()}`).then(p => this.p.set(p))
      .catch(e => this.avisos.error(mensajeError(e)));
  }
}
