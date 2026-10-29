import { CurrencyPipe, DecimalPipe } from '@angular/common';
import { Component, computed, inject, input, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';

import { Api, mensajeError } from '../../core/api';
import { Auth } from '../../core/auth';
import { Estado, Modal, NombrePipe, Notificador } from '../../core/ui';
import { DatosProductoForm, ProductoForm } from './producto-form';

interface LineaReceta {
  id_receta: number; id_material: number; codigo_interno: string; material: string; tipo: string;
  unidad_medida: string; cantidad_requerida: number; disponible: number; costo_linea: number;
  alcanza_para: number; observacion: string | null;
}
interface DatosProducto extends DatosProductoForm {
  id_producto: number; receta: LineaReceta[]; unidades_fabricables: number; costo_materiales: number;
}
interface MaterialLista { id_material: number; codigo_interno: string; nombre: string; unidad_medida: string; }

@Component({
  selector: 'app-producto-detalle',
  imports: [RouterLink, NombrePipe, DecimalPipe, CurrencyPipe, FormsModule, Modal, Estado, ProductoForm],
  template: `
    <div class="row" style="margin-bottom: 14px">
      <a class="btn chico" routerLink="/productos">← Volver</a>
      @if (auth.esAdmin() && p()) {
        <button class="btn chico" type="button" (click)="editandoProducto.set(true)">Editar producto</button>
      }
    </div>
    @if (p(); as p) {
      <div class="stack">
        <div class="grid grid-4">
          <div class="card kpi"><div class="etiqueta">{{ p.codigo_sku }} <app-estado [valor]="p.estado" /></div>
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
          <div class="card-header">
            <h2>Receta / despiece ({{ p.receta.length }} ítems)</h2>
            @if (auth.esAdmin()) {
              <button class="btn primario chico" type="button" (click)="agregar()">+ Agregar material</button>
            }
          </div>
          <div class="tabla-wrap">
            <table class="tabla">
              <thead><tr><th>Código</th><th>Material</th><th>Tipo</th><th class="num">Cantidad</th>
                         <th class="num">Disponible</th><th class="num">Alcanza para</th><th class="num">Costo</th><th>Observación</th>
                         @if (auth.esAdmin()) { <th></th> }</tr></thead>
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
                    @if (auth.esAdmin()) {
                      <td class="right nowrap">
                        <button class="btn chico" type="button" (click)="editar(l)">Editar</button>
                        <button class="btn chico" type="button" (click)="quitar(l)">Quitar</button>
                      </td>
                    }
                  </tr>
                } @empty {
                  <tr><td colspan="9" class="muted">Este producto aún no tiene receta: no consume materiales al venderse.</td></tr>
                }
              </tbody>
            </table>
          </div>
        </div>
        @if (auth.esAdmin()) {
          <p class="muted small">Los cambios en la receta valen para las notas nuevas y para las comandas que aún están
            En espera; las que ya pasaron a Fabricación conservan lo que se descontó.</p>
        }
      </div>
    } @else {
      <p class="muted">Cargando…</p>
    }

    <app-producto-form [abierto]="editandoProducto()" [producto]="p()" (cerrar)="editandoProducto.set(false)"
                       (guardado)="productoGuardado()" />

    <app-modal [abierto]="linea() !== null" [titulo]="lineaId() ? 'Editar cantidad' : 'Agregar material a la receta'"
               [ancho]="520" (cerrar)="linea.set(null)">
      <form #f="ngForm" (ngSubmit)="guardarLinea()">
        <div class="stack">
          @if (!lineaId()) {
            <div class="campo"><label>Material</label>
              <select class="input" name="mat" [(ngModel)]="form.id_material" required>
                <option [ngValue]="0" disabled>Elige un material…</option>
                @for (m of disponibles(); track m.id_material) {
                  <option [ngValue]="m.id_material">{{ m.codigo_interno }} · {{ m.nombre }} ({{ m.unidad_medida }})</option>
                }
              </select></div>
          } @else {
            <p class="muted" style="margin: 0">{{ linea()?.material }}</p>
          }
          <div class="campo"><label>Cantidad por unidad de producto</label>
            <input class="input" type="number" name="cant" [(ngModel)]="form.cantidad_requerida" min="0.01" step="any" required /></div>
          <div class="campo"><label>Observación</label>
            <input class="input" name="obs" [(ngModel)]="form.observacion" maxlength="120" /></div>
        </div>
        <div class="row end mt">
          <button class="btn" type="button" (click)="linea.set(null)">Cancelar</button>
          <button class="btn primario" type="submit" [disabled]="f.invalid || !form.id_material">Guardar</button>
        </div>
      </form>
    </app-modal>`,
})
export class ProductoDetalle {
  id = input.required<string>();
  private api = inject(Api);
  private avisos = inject(Notificador);
  protected auth = inject(Auth);

  protected p = signal<DatosProducto | null>(null);
  protected editandoProducto = signal(false);

  // Línea de receta en edición: LineaReceta (editar), 'nueva' (agregar) o null (cerrado)
  protected linea = signal<LineaReceta | null>(null);
  protected lineaId = signal(0);
  protected form = { id_material: 0, cantidad_requerida: 1, observacion: '' as string | null };
  private materiales = signal<MaterialLista[]>([]);
  protected disponibles = computed(() => {
    const usados = new Set(this.p()?.receta.map(l => l.id_material));
    return this.materiales().filter(m => !usados.has(m.id_material));
  });

  ngOnInit() {
    this.cargar();
  }

  async cargar() {
    try {
      this.p.set(await this.api.get<DatosProducto>(`/productos/${this.id()}`));
    } catch (e) {
      this.avisos.error(mensajeError(e));
    }
  }

  productoGuardado() {
    this.editandoProducto.set(false);
    this.cargar();
  }

  async agregar() {
    if (!this.materiales().length) {
      try {
        this.materiales.set(await this.api.get<MaterialLista[]>('/materiales'));
      } catch (e) {
        this.avisos.error(mensajeError(e));
        return;
      }
    }
    this.form = { id_material: 0, cantidad_requerida: 1, observacion: '' };
    this.lineaId.set(0);
    this.linea.set({} as LineaReceta);
  }

  editar(l: LineaReceta) {
    this.form = { id_material: l.id_material, cantidad_requerida: Number(l.cantidad_requerida),
                  observacion: l.observacion ?? '' };
    this.lineaId.set(l.id_receta);
    this.linea.set(l);
  }

  async guardarLinea() {
    const base = `/productos/${this.id()}/receta`;
    const observacion = this.form.observacion?.trim() || null;
    try {
      if (this.lineaId()) {
        await this.api.put(`${base}/${this.lineaId()}`, { cantidad_requerida: this.form.cantidad_requerida, observacion });
        this.avisos.ok('Cantidad actualizada');
      } else {
        await this.api.post(base, { ...this.form, observacion });
        this.avisos.ok('Material agregado a la receta');
      }
      this.linea.set(null);
      await this.cargar();
    } catch (e) {
      this.avisos.error(mensajeError(e));
    }
  }

  async quitar(l: LineaReceta) {
    if (!confirm(`¿Quitar "${l.material}" de la receta?`)) return;
    try {
      await this.api.delete(`/productos/${this.id()}/receta/${l.id_receta}`);
      this.avisos.ok('Material quitado de la receta');
      await this.cargar();
    } catch (e) {
      this.avisos.error(mensajeError(e));
    }
  }
}
