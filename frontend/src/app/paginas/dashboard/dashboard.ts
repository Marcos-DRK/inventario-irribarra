import { CurrencyPipe, DecimalPipe } from '@angular/common';
import { Component, inject, signal } from '@angular/core';
import { Router, RouterLink } from '@angular/router';

import { Api, mensajeError } from '../../core/api';
import { Estado, NombrePipe, Notificador } from '../../core/ui';

interface DatosDashboard {
  kpis: Record<string, number>;
  notas_recientes: { id_nota_venta: number; folio: string; cliente: string; productos: string; estado: string;
                     monto_total: number }[];
  alertas: { id_alerta: number; tipo: string; material: string; unidad_medida: string; stock_disponible: number;
             stock_requerido: number; folio: string | null }[];
}

@Component({
  selector: 'app-dashboard',
  imports: [RouterLink, Estado, CurrencyPipe, DecimalPipe, NombrePipe],
  templateUrl: './dashboard.html',
})
export class Dashboard {
  private api = inject(Api);
  private avisos = inject(Notificador);
  protected router = inject(Router);
  protected d = signal<DatosDashboard | null>(null);

  protected etapas = [
    { clave: 'comandas_en_espera', nombre: 'En espera' },
    { clave: 'comandas_fabricacion', nombre: 'Fabricación' },
    { clave: 'comandas_pintura', nombre: 'Pintura' },
    { clave: 'comandas_qa', nombre: 'QA' },
    { clave: 'comandas_finalizadas_mes', nombre: 'Finalizado (mes)' },
  ];

  constructor() { this.cargar(); }

  async cargar() {
    try {
      this.d.set(await this.api.get<DatosDashboard>('/dashboard'));
    } catch (e) {
      this.avisos.error(mensajeError(e));
    }
  }

  porcentaje(a: { stock_disponible: number; stock_requerido: number }): number {
    if (!a.stock_requerido) return 100;
    return Math.max(0, Math.min(100, (a.stock_disponible / a.stock_requerido) * 100));
  }
}
