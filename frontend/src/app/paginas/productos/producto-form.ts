import { Component, effect, inject, input, output } from '@angular/core';
import { FormsModule } from '@angular/forms';

import { Api, mensajeError } from '../../core/api';
import { Modal, Notificador } from '../../core/ui';

export interface DatosProductoForm {
  id_producto?: number; codigo_sku: string; nombre: string; categoria: string; descripcion: string | null;
  medidas: string | null; precio_venta: number; tiempo_fabricacion_dias: number; estado: string;
}

export const CATEGORIAS = [
  { valor: 'Sauna_Ext', texto: 'Sauna exterior' }, { valor: 'Sauna_Int', texto: 'Sauna interior' },
  { valor: 'Tina', texto: 'Tina' }, { valor: 'Mueble', texto: 'Mueble' }, { valor: 'Accesorio', texto: 'Accesorio' },
];

/** Formulario de alta / edición de producto (solo Administrador). `producto` null = producto nuevo. */
@Component({
  selector: 'app-producto-form',
  imports: [FormsModule, Modal],
  template: `
    <app-modal [abierto]="abierto()" [titulo]="producto() ? 'Editar producto' : 'Nuevo producto'" [ancho]="640"
               (cerrar)="cerrar.emit()">
      <form #f="ngForm" (ngSubmit)="guardar()">
        <div class="form-grid">
          <div class="campo"><label>Código SKU</label>
            <input class="input" name="sku" [(ngModel)]="form.codigo_sku" maxlength="30" required />
            <span class="ayuda">Es el código que envía la plataforma de ventas</span></div>
          <div class="campo"><label>Nombre</label>
            <input class="input" name="nombre" [(ngModel)]="form.nombre" maxlength="120" required /></div>
          <div class="campo"><label>Categoría</label>
            <select class="input" name="cat" [(ngModel)]="form.categoria">
              @for (c of categorias; track c.valor) { <option [value]="c.valor">{{ c.texto }}</option> }
            </select></div>
          <div class="campo"><label>Medidas</label>
            <input class="input" name="med" [(ngModel)]="form.medidas" maxlength="80" /></div>
          <div class="campo"><label>Precio de venta (CLP)</label>
            <input class="input" type="number" name="precio" [(ngModel)]="form.precio_venta" min="0" required /></div>
          <div class="campo"><label>Días de fabricación</label>
            <input class="input" type="number" name="dias" [(ngModel)]="form.tiempo_fabricacion_dias" min="1" required /></div>
          <div class="campo"><label>Estado</label>
            <select class="input" name="estado" [(ngModel)]="form.estado">
              <option value="Activo">Activo</option>
              <option value="Inactivo">Inactivo (no se puede vender)</option>
            </select></div>
          <div class="campo" style="grid-column: 1 / -1"><label>Descripción</label>
            <input class="input" name="desc" [(ngModel)]="form.descripcion" maxlength="300" /></div>
        </div>
        <div class="row end mt">
          <button class="btn" type="button" (click)="cerrar.emit()">Cancelar</button>
          <button class="btn primario" type="submit" [disabled]="f.invalid">Guardar</button>
        </div>
      </form>
    </app-modal>`,
})
export class ProductoForm {
  abierto = input(false);
  producto = input<DatosProductoForm | null>(null);
  cerrar = output<void>();
  guardado = output<number>();

  private api = inject(Api);
  private avisos = inject(Notificador);
  protected categorias = CATEGORIAS;
  protected form = this.vacio();

  constructor() {
    // Cada vez que se abre, parte desde el producto elegido (o vacío si es nuevo)
    effect(() => {
      if (this.abierto()) this.form = this.producto() ? { ...this.producto()! } : this.vacio();
    });
  }

  private vacio(): DatosProductoForm {
    return { codigo_sku: '', nombre: '', categoria: 'Sauna_Ext', descripcion: null, medidas: null,
             precio_venta: 0, tiempo_fabricacion_dias: 1, estado: 'Activo' };
  }

  async guardar() {
    const { id_producto, ...datos } = this.form;
    try {
      const actual = this.producto();
      const r = actual
        ? await this.api.put<{ id_producto: number }>(`/productos/${actual.id_producto}`, datos)
        : await this.api.post<{ id_producto: number }>('/productos', datos);
      this.avisos.ok(actual ? 'Producto actualizado' : 'Producto creado: ahora agrega su receta');
      this.guardado.emit(r.id_producto);
    } catch (e) {
      this.avisos.error(mensajeError(e));
    }
  }
}
