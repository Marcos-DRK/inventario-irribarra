import { CurrencyPipe, DatePipe, DecimalPipe } from '@angular/common';
import { Component, computed, inject, input, signal } from '@angular/core';
import { Router, RouterLink } from '@angular/router';

import { Api, mensajeError } from '../../core/api';
import { Auth } from '../../core/auth';
import { BorradorCompra } from '../../core/borrador-compra';
import { Estado, Notificador } from '../../core/ui';

interface Verificacion {
  id_material: number; codigo_interno: string; material: string; unidad_medida: string;
  requerido: number; disponible: number; stock_actual: number; estado: string;
}
interface DetalleNota {
  nota: Record<string, any>;
  detalles: { id_detalle: number; producto: string; codigo_sku: string; cantidad: number; precio_unitario: number;
              subtotal: number; diseno_personalizado: string | null; id_comanda: number | null;
              estado_comanda: string | null }[];
  verificacion: Verificacion[];
  insumos_faltantes: number;
}

@Component({
  selector: 'app-nota-detalle',
  imports: [RouterLink, Estado, CurrencyPipe, DatePipe, DecimalPipe],
  templateUrl: './nota-detalle.html',
})
export class NotaDetalle {
  /** Viene de la ruta /notas-venta/:id */
  id = input.required<string>();

  private api = inject(Api);
  private avisos = inject(Notificador);
  private router = inject(Router);
  private borrador = inject(BorradorCompra);
  protected auth = inject(Auth);

  protected d = signal<DetalleNota | null>(null);
  protected procesando = signal(false);
  protected faltantes = computed(() => this.d()?.verificacion.filter(v => v.estado === 'Falta') ?? []);

  ngOnInit() { this.cargar(); }

  async cargar() {
    try {
      this.d.set(await this.api.get<DetalleNota>(`/notas-venta/${this.id()}`));
    } catch (e) {
      this.avisos.error(mensajeError(e));
    }
  }

  async procesar() {
    this.procesando.set(true);
    try {
      const r = await this.api.post<{ estado: string }>(`/notas-venta/${this.id()}/procesar`);
      if (r.estado === 'Aprobada') this.avisos.ok('Nota aprobada: se generaron las comandas de fabricación');
      else this.avisos.error('Todavía faltan insumos: la nota sigue rechazada');
      await this.cargar();
    } catch (e) {
      this.avisos.error(mensajeError(e));
    } finally {
      this.procesando.set(false);
    }
  }

  /** Lleva los faltantes al formulario de compra. */
  comprarFaltantes() {
    this.borrador.preparar(this.faltantes().map(v => ({
      id_material: v.id_material, cantidad: Math.ceil(Number(v.requerido) - Number(v.disponible)),
    })));
    this.router.navigate(['/compras'], { queryParams: { nueva: 1 } });
  }
}
