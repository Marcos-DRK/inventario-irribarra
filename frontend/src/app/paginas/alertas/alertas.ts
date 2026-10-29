import { DatePipe, DecimalPipe } from '@angular/common';
import { Component, computed, inject, signal } from '@angular/core';
import { Router, RouterLink } from '@angular/router';

import { Api, mensajeError } from '../../core/api';
import { Auth } from '../../core/auth';
import { BorradorCompra } from '../../core/borrador-compra';
import { Estado, Notificador } from '../../core/ui';

interface Alerta {
  id_alerta: number; tipo: string; estado: string; fecha_alerta: string; fecha_resolucion: string | null;
  stock_disponible: number; stock_requerido: number; faltante: number; id_material: number; codigo_interno: string;
  material: string; unidad_medida: string; stock_actual: number; id_nota_venta: number | null; folio: string | null;
}

@Component({
  selector: 'app-alertas',
  imports: [RouterLink, Estado, DatePipe, DecimalPipe],
  template: `
    <div class="card">
      <div class="card-header">
        <div class="tabs">
          @for (f of filtros; track f.valor) {
            <button type="button" [class.activo]="filtro() === f.valor" (click)="cambiar(f.valor)">{{ f.texto }}</button>
          }
        </div>
        @if (pendientes().length) {
          <button class="btn primario" type="button" (click)="comprar()">Comprar faltantes ({{ materialesFaltantes().length }})</button>
        }
      </div>
      <div class="tabla-wrap">
        <table class="tabla">
          <thead><tr><th>Fecha</th><th>Tipo</th><th>Material</th><th class="num">Disponible</th><th class="num">Requerido</th>
                     <th class="num">Faltante</th><th>Nota</th><th>Estado</th><th></th></tr></thead>
          <tbody>
            @for (a of alertas(); track a.id_alerta) {
              <tr>
                <td class="nowrap">{{ a.fecha_alerta | date:'dd-MM-yyyy HH:mm' }}</td>
                <td><app-estado [valor]="a.tipo" /></td>
                <td><a [routerLink]="['/materiales', a.id_material]">{{ a.material }}</a>
                    <div class="small muted">Stock actual {{ a.stock_actual | number:'1.0-2' }} {{ a.unidad_medida }}</div></td>
                <td class="num">{{ a.stock_disponible | number:'1.0-2' }}</td>
                <td class="num">{{ a.stock_requerido | number:'1.0-2' }}</td>
                <td class="num" style="color: var(--rojo)"><strong>{{ a.faltante | number:'1.0-2' }} {{ a.unidad_medida }}</strong></td>
                <td>@if (a.id_nota_venta) { <a [routerLink]="['/notas-venta', a.id_nota_venta]">N° {{ a.folio }}</a> } @else { — }</td>
                <td><app-estado [valor]="a.estado" />
                    @if (a.fecha_resolucion) { <div class="small muted">{{ a.fecha_resolucion | date:'dd-MM HH:mm' }}</div> }</td>
                <td class="right">
                  @if (auth.esAdmin() && a.estado === 'Pendiente') {
                    <button class="btn chico" type="button" (click)="resolver(a)">Resolver</button>
                  }
                </td>
              </tr>
            } @empty {
              <tr><td colspan="9" class="vacio">{{ filtro() === 'Pendiente' ? 'No hay alertas pendientes 🎉' : 'Sin alertas' }}</td></tr>
            }
          </tbody>
        </table>
      </div>
      <div class="card-body small muted" style="border-top: 1px solid var(--borde)">
        Las alertas <strong>Faltante</strong> se generan al recibir una nota de venta sin stock suficiente; las de
        <strong>Bajo mínimo</strong> cuando un material queda bajo su stock mínimo. Ambas se resuelven solas al registrar la compra.
      </div>
    </div>`,
})
export class Alertas {
  private api = inject(Api);
  private avisos = inject(Notificador);
  private router = inject(Router);
  private borrador = inject(BorradorCompra);
  protected auth = inject(Auth);

  protected alertas = signal<Alerta[]>([]);
  protected filtro = signal('Pendiente');
  protected filtros = [{ valor: 'Pendiente', texto: 'Pendientes' }, { valor: 'Resuelta', texto: 'Resueltas' },
                       { valor: '', texto: 'Todas' }];
  protected pendientes = computed(() => this.alertas().filter(a => a.estado === 'Pendiente'));
  /** Mayor faltante por material (una línea por material en la compra). */
  protected materialesFaltantes = computed(() => {
    const porMaterial = new Map<number, number>();
    for (const a of this.pendientes()) {
      porMaterial.set(a.id_material, Math.max(porMaterial.get(a.id_material) ?? 0, Math.ceil(Number(a.faltante))));
    }
    return [...porMaterial].map(([id_material, cantidad]) => ({ id_material, cantidad }));
  });

  constructor() { this.cargar(); }

  async cargar() {
    try {
      this.alertas.set(await this.api.get<Alerta[]>('/alertas', { estado: this.filtro() }));
    } catch (e) {
      this.avisos.error(mensajeError(e));
    }
  }

  cambiar(valor: string) {
    this.filtro.set(valor);
    this.cargar();
  }

  async resolver(a: Alerta) {
    try {
      await this.api.patch(`/alertas/${a.id_alerta}/resolver`, {});
      this.avisos.ok('Alerta marcada como resuelta');
      await this.cargar();
    } catch (e) {
      this.avisos.error(mensajeError(e));
    }
  }

  comprar() {
    this.borrador.preparar(this.materialesFaltantes());
    this.router.navigate(['/compras'], { queryParams: { nueva: 1 } });
  }
}
