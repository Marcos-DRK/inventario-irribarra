import { CurrencyPipe, DatePipe, DecimalPipe } from '@angular/common';
import { Component, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';

import { Api, mensajeError } from '../../core/api';
import { Estado, NombrePipe, Notificador } from '../../core/ui';

interface Reporte {
  periodo: string;
  resumen: { consumo_total_materiales: number; total_alertas: number; ahorro_por_reciclaje: number;
             comandas_finalizadas: number; fecha_generacion: string };
  por_categoria: { categoria: string; consumo: number }[];
  top_materiales: { codigo_interno: string; material: string; unidad_medida: string; cantidad: number; costo: number }[];
  alertas: { id_alerta: number; tipo: string; material: string; estado: string; folio: string | null }[];
  mermas: { id_merma: number; material: string; valor_estimado: number }[];
}

const MESES = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre',
               'Noviembre', 'Diciembre'];

@Component({
  selector: 'app-reportes',
  imports: [FormsModule, Estado, NombrePipe, CurrencyPipe, DecimalPipe, DatePipe],
  templateUrl: './reportes.html',
})
export class Reportes {
  private api = inject(Api);
  private avisos = inject(Notificador);

  protected periodos = signal<string[]>([]);
  protected periodo = '';
  protected r = signal<Reporte | null>(null);
  protected descargando = signal('');
  protected maxCategoria = computed(() => Math.max(1, ...(this.r()?.por_categoria ?? []).map(c => Number(c.consumo))));

  async ngOnInit() {
    try {
      this.periodos.set(await this.api.get<string[]>('/reportes/periodos'));
      this.periodo = this.periodos()[0];
      await this.cargar();
    } catch (e) {
      this.avisos.error(mensajeError(e));
    }
  }

  nombre(periodo: string): string {
    const [a, m] = periodo.split('-');
    return `${MESES[Number(m) - 1]} ${a}`;
  }

  async cargar() {
    try {
      this.r.set(await this.api.get<Reporte>(`/reportes/mensual/${this.periodo}`));
    } catch (e) {
      this.avisos.error(mensajeError(e));
    }
  }

  async descargar(tipo: 'pdf' | 'excel') {
    this.descargando.set(tipo);
    try {
      await this.api.descargar(tipo === 'pdf' ? `/reportes/mensual/${this.periodo}/pdf` : '/reportes/inventario/excel');
    } catch (e) {
      this.avisos.error(mensajeError(e));
    } finally {
      this.descargando.set('');
    }
  }
}
