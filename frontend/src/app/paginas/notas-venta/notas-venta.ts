import { CurrencyPipe, DatePipe, JsonPipe } from '@angular/common';
import { Component, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';

import { Api, mensajeError } from '../../core/api';
import { Auth } from '../../core/auth';
import { Estado, Modal, Notificador } from '../../core/ui';

interface NotaFila {
  id_nota_venta: number; folio: string; fecha_venta: string; fecha_despacho: string | null; cliente: string;
  cliente_rut: string; productos: string; estado: string; monto_total: number; alertas_pendientes: number; origen: string;
}
interface Producto { id_producto: number; codigo_sku: string; nombre: string; precio_venta: number; }

@Component({
  selector: 'app-notas-venta',
  imports: [FormsModule, Estado, Modal, CurrencyPipe, DatePipe, JsonPipe],
  templateUrl: './notas-venta.html',
})
export class NotasVenta {
  private api = inject(Api);
  private avisos = inject(Notificador);
  protected router = inject(Router);
  protected auth = inject(Auth);

  protected notas = signal<NotaFila[]>([]);
  protected filtro = signal('');
  protected filtros = [
    { valor: '', texto: 'Todas' }, { valor: 'RechazadaStock', texto: 'Falta stock' },
    { valor: 'Aprobada', texto: 'Aprobadas' }, { valor: 'EnVerificacion', texto: 'En verificación' },
  ];
  protected visibles = computed(() =>
    this.filtro() ? this.notas().filter(n => n.estado === this.filtro()) : this.notas());

  // Simulador de la plataforma web de ventas
  protected simulando = signal(false);
  protected enviando = signal(false);
  protected productos = signal<Producto[]>([]);
  protected verJson = signal(false);
  protected form = this.formVacio();

  constructor() { this.cargar(); }

  async cargar() {
    try {
      this.notas.set(await this.api.get<NotaFila[]>('/notas-venta'));
    } catch (e) {
      this.avisos.error(mensajeError(e));
    }
  }

  private formVacio() {
    return {
      folio: '', fecha_despacho: '', rut: '', nombres: '', apellidos: '', comuna: 'Bulnes', telefono: '', correo: '',
      codigo_sku: '', cantidad: 1, precio_unitario: null as number | null, diseno_personalizado: '',
    };
  }

  async abrirSimulador() {
    this.form = this.formVacio();
    this.verJson.set(false);
    try {
      const [folio, productos] = await Promise.all([
        this.api.get<{ folio: string }>('/notas-venta/siguiente-folio'),
        this.api.get<Producto[]>('/productos'),
      ]);
      this.form.folio = folio.folio;
      this.productos.set(productos);
      this.simulando.set(true);
    } catch (e) {
      this.avisos.error(mensajeError(e));
    }
  }

  elegirProducto() {
    const p = this.productos().find(x => x.codigo_sku === this.form.codigo_sku);
    this.form.precio_unitario = p ? Number(p.precio_venta) : null;
  }

  /** Mismo formato JSON que enviaría la plataforma web de ventas. */
  json() {
    const f = this.form;
    const opcional = (v: string) => v.trim() || undefined;
    return {
      folio: f.folio,
      fecha_despacho: opcional(f.fecha_despacho),
      origen: 'Plataforma',
      cliente: { rut: f.rut, nombres: f.nombres, apellidos: f.apellidos, comuna: opcional(f.comuna),
                 telefono: opcional(f.telefono), correo: opcional(f.correo) },
      detalles: [{ codigo_sku: f.codigo_sku, cantidad: f.cantidad, precio_unitario: f.precio_unitario ?? undefined,
                   diseno_personalizado: opcional(f.diseno_personalizado) }],
    };
  }

  async enviar() {
    this.enviando.set(true);
    try {
      const r = await this.api.post<{ id_nota_venta: number; estado: string }>('/integracion/notas-venta', this.json());
      this.simulando.set(false);
      if (r.estado === 'Aprobada') this.avisos.ok(`Nota ${this.form.folio} aprobada: hay stock y se creó la comanda`);
      else this.avisos.error(`Nota ${this.form.folio} rechazada: faltan insumos (se generaron alertas)`);
      this.router.navigate(['/notas-venta', r.id_nota_venta]);
    } catch (e) {
      this.avisos.error(mensajeError(e));
    } finally {
      this.enviando.set(false);
    }
  }
}
