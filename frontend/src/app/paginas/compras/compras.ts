import { CurrencyPipe, DatePipe, DecimalPipe } from '@angular/common';
import { Component, inject, input, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';

import { Api, mensajeError } from '../../core/api';
import { BorradorCompra } from '../../core/borrador-compra';
import { Modal, Notificador } from '../../core/ui';
import { Material } from '../materiales/materiales';

interface Factura {
  id_factura: number; numero_factura: string; razon_social: string; fecha_emision: string; fecha_ingreso: string;
  monto_total: number; registrado_por: string; lineas: number;
}
interface FacturaDetalle extends Factura {
  rut_proveedor: string;
  detalles: { id_detalle_factura: number; codigo_interno: string; material: string; unidad_medida: string;
              cantidad: number; costo_unitario: number; subtotal: number }[];
}
interface Linea { id_material: number | null; cantidad: number; costo_unitario: number; }

@Component({
  selector: 'app-compras',
  imports: [FormsModule, Modal, CurrencyPipe, DatePipe, DecimalPipe],
  templateUrl: './compras.html',
})
export class Compras {
  /** ?nueva=1 abre el formulario (viene desde una nota de venta o alertas) */
  nueva = input<string>();

  private api = inject(Api);
  private avisos = inject(Notificador);
  private borrador = inject(BorradorCompra);

  protected facturas = signal<Factura[]>([]);
  protected materiales = signal<Material[]>([]);
  protected proveedores = signal<{ id_proveedor: number; razon_social: string; rut: string }[]>([]);
  protected viendo = signal<FacturaDetalle | null>(null);

  protected registrando = signal(false);
  protected guardando = signal(false);
  protected form = { numero_factura: '', id_proveedor: null as number | null, fecha_emision: new Date().toISOString().slice(0, 10) };
  protected lineas: Linea[] = [];

  async ngOnInit() {
    await Promise.all([this.cargar(), this.cargarCatalogos()]);
    if (this.nueva()) this.abrir();
  }

  async cargar() {
    try {
      this.facturas.set(await this.api.get<Factura[]>('/compras'));
    } catch (e) {
      this.avisos.error(mensajeError(e));
    }
  }

  private async cargarCatalogos() {
    try {
      const [m, p] = await Promise.all([
        this.api.get<Material[]>('/materiales'),
        this.api.get<{ id_proveedor: number; razon_social: string; rut: string }[]>('/proveedores'),
      ]);
      this.materiales.set([...m].sort((a, b) => a.nombre.localeCompare(b.nombre)));
      this.proveedores.set(p);
    } catch (e) {
      this.avisos.error(mensajeError(e));
    }
  }

  abrir() {
    const borrador = this.borrador.tomar();
    this.form = { numero_factura: '', id_proveedor: null, fecha_emision: new Date().toISOString().slice(0, 10) };
    this.lineas = borrador.length
      ? borrador.map(b => ({ id_material: b.id_material, cantidad: b.cantidad, costo_unitario: this.costo(b.id_material) }))
      : [{ id_material: null, cantidad: 1, costo_unitario: 0 }];
    if (borrador.length) this.avisos.info('Se cargaron los materiales faltantes en la factura');
    this.registrando.set(true);
  }

  private costo(id: number | null): number {
    return Number(this.materiales().find(m => m.id_material === id)?.costo_unitario ?? 0);
  }

  unidad(id: number | null): string {
    return this.materiales().find(m => m.id_material === id)?.unidad_medida ?? '';
  }

  elegirMaterial(l: Linea) { l.costo_unitario = this.costo(l.id_material); }
  agregarLinea() { this.lineas.push({ id_material: null, cantidad: 1, costo_unitario: 0 }); }
  quitarLinea(i: number) { this.lineas.splice(i, 1); }
  total(): number { return this.lineas.reduce((s, l) => s + (l.cantidad || 0) * (l.costo_unitario || 0), 0); }
  valido(): boolean {
    return !!this.form.numero_factura && !!this.form.id_proveedor && this.lineas.length > 0
      && this.lineas.every(l => l.id_material && l.cantidad > 0 && l.costo_unitario >= 0);
  }

  async guardar() {
    this.guardando.set(true);
    try {
      const f = await this.api.post<FacturaDetalle>('/compras', { ...this.form, detalles: this.lineas });
      this.registrando.set(false);
      this.avisos.ok(`Factura ${f.numero_factura} registrada: stock actualizado y alertas cubiertas resueltas`);
      await Promise.all([this.cargar(), this.cargarCatalogos()]);
      this.viendo.set(f);
    } catch (e) {
      this.avisos.error(mensajeError(e));
    } finally {
      this.guardando.set(false);
    }
  }

  async ver(f: Factura) {
    try {
      this.viendo.set(await this.api.get<FacturaDetalle>(`/compras/${f.id_factura}`));
    } catch (e) {
      this.avisos.error(mensajeError(e));
    }
  }
}
