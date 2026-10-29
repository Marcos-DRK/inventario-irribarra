import { DecimalPipe } from '@angular/common';
import { Component, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';

import { Api, mensajeError } from '../../core/api';
import { Auth } from '../../core/auth';
import { Estado, Modal, NombrePipe, Notificador } from '../../core/ui';

export interface Material {
  id_material: number; codigo_interno: string; nombre: string; tipo: string; unidad_medida: string;
  stock_actual: number; stock_minimo: number; costo_unitario: number; comprometido: number; disponible: number;
  valor_stock: number; id_bodega: number; bodega: string; estado_stock: string; nivel_pct: number;
  id_proveedor_principal?: number | null;
}

export const TIPOS = ['Madera', 'Ferreteria', 'Equipamiento', 'Accesorio'];
export const UNIDADES = ['un', 'm', 'm2', 'm3', 'kg', 'L', 'caja', 'paquete', 'bolsa', 'tira', 'tablon', 'placa'];

@Component({
  selector: 'app-materiales',
  imports: [FormsModule, Estado, Modal, NombrePipe, DecimalPipe],
  templateUrl: './materiales.html',
})
export class Materiales {
  private api = inject(Api);
  private avisos = inject(Notificador);
  protected router = inject(Router);
  protected auth = inject(Auth);

  protected materiales = signal<Material[]>([]);
  protected bodegas = signal<{ id_bodega: number; nombre: string }[]>([]);
  protected proveedores = signal<{ id_proveedor: number; razon_social: string }[]>([]);
  protected filtros = { id_bodega: '', tipo: '', estado: '', buscar: '' };
  protected tipos = TIPOS;
  protected unidades = UNIDADES;

  // Formulario de alta / edición (solo administrador)
  protected editando = signal<'nuevo' | number | null>(null);
  protected form = this.formVacio();

  // Ajuste de stock (conteo físico)
  protected ajustando = signal<Material | null>(null);
  protected ajuste = { nuevo_stock: 0, tipo: 'AJUSTE', motivo: 'Conteo físico' };

  constructor() {
    this.cargar();
    this.api.get<{ id_bodega: number; nombre: string }[]>('/bodegas').then(b => this.bodegas.set(b)).catch(() => {});
    this.api.get<{ id_proveedor: number; razon_social: string }[]>('/proveedores')
      .then(p => this.proveedores.set(p)).catch(() => {});
  }

  async cargar() {
    try {
      this.materiales.set(await this.api.get<Material[]>('/materiales', this.filtros));
    } catch (e) {
      this.avisos.error(mensajeError(e));
    }
  }

  private formVacio() {
    return { codigo_interno: '', nombre: '', tipo: 'Ferreteria', unidad_medida: 'un', stock_minimo: 0,
             costo_unitario: 0, id_bodega: 2, id_proveedor_principal: null as number | null, stock_inicial: 0 };
  }

  nuevo() {
    this.form = this.formVacio();
    this.editando.set('nuevo');
  }

  editar(m: Material) {
    this.form = { codigo_interno: m.codigo_interno, nombre: m.nombre, tipo: m.tipo, unidad_medida: m.unidad_medida,
                  stock_minimo: Number(m.stock_minimo), costo_unitario: Number(m.costo_unitario), id_bodega: m.id_bodega,
                  id_proveedor_principal: m.id_proveedor_principal ?? null, stock_inicial: 0 };
    this.api.get<Material>(`/materiales/${m.id_material}`)
      .then(d => this.form.id_proveedor_principal = d.id_proveedor_principal ?? null).catch(() => {});
    this.editando.set(m.id_material);
  }

  async guardar() {
    const id = this.editando();
    try {
      if (id === 'nuevo') {
        await this.api.post('/materiales', this.form);
        this.avisos.ok('Material dado de alta');
      } else {
        const { stock_inicial, ...datos } = this.form;
        await this.api.put(`/materiales/${id}`, datos);
        this.avisos.ok('Material actualizado');
      }
      this.editando.set(null);
      await this.cargar();
    } catch (e) {
      this.avisos.error(mensajeError(e));
    }
  }

  async darDeBaja() {
    const id = this.editando();
    if (typeof id !== 'number' || !confirm('¿Dar de baja este material? Su historial se conserva.')) return;
    try {
      await this.api.delete(`/materiales/${id}`);
      this.avisos.ok('Material dado de baja');
      this.editando.set(null);
      await this.cargar();
    } catch (e) {
      this.avisos.error(mensajeError(e));
    }
  }

  abrirAjuste(m: Material) {
    this.ajuste = { nuevo_stock: Number(m.stock_actual), tipo: 'AJUSTE', motivo: 'Conteo físico' };
    this.ajustando.set(m);
  }

  async guardarAjuste() {
    const m = this.ajustando()!;
    try {
      await this.api.post(`/materiales/${m.id_material}/ajuste`, this.ajuste);
      this.avisos.ok(`Stock de ${m.nombre} ajustado (queda en el kardex)`);
      this.ajustando.set(null);
      await this.cargar();
    } catch (e) {
      this.avisos.error(mensajeError(e));
    }
  }

  exportar() {
    this.api.descargar('/reportes/inventario/excel').catch(e => this.avisos.error(mensajeError(e)));
  }

  claseNivel(m: Material): string {
    return m.estado_stock === 'OK' ? '' : m.estado_stock === 'Bajo' ? 'warn' : 'bad';
  }
}
