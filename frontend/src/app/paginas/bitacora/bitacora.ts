import { DatePipe } from '@angular/common';
import { Component, inject, signal } from '@angular/core';

import { Api, mensajeError } from '../../core/api';
import { Estado, Notificador } from '../../core/ui';

interface Acceso { id_acceso: number; nombre_usuario: string; resultado: string; ip: string | null; detalle: string | null; fecha: string; }
interface Auditoria {
  id_auditoria: number; tabla: string; accion: string; id_registro: number; usuario: string; fecha: string;
  valor_anterior: string | Record<string, unknown> | null; valor_nuevo: string | Record<string, unknown> | null;
}

function aObjeto(v: Auditoria['valor_nuevo']): Record<string, unknown> {
  if (!v) return {};
  return typeof v === 'string' ? JSON.parse(v) : v;
}

@Component({
  selector: 'app-bitacora',
  imports: [Estado, DatePipe],
  template: `
    <div class="card">
      <div class="card-header">
        <div class="tabs">
          <button type="button" [class.activo]="vista() === 'accesos'" (click)="vista.set('accesos')">Accesos al sistema</button>
          <button type="button" [class.activo]="vista() === 'auditoria'" (click)="vista.set('auditoria')">Cambios en los datos</button>
        </div>
        <button class="btn chico" type="button" (click)="cargar()">↻ Actualizar</button>
      </div>
      <div class="tabla-wrap">
        @if (vista() === 'accesos') {
          <table class="tabla">
            <thead><tr><th>Fecha</th><th>Usuario</th><th>Resultado</th><th>IP</th><th>Detalle</th></tr></thead>
            <tbody>
              @for (a of accesos(); track a.id_acceso) {
                <tr><td class="nowrap">{{ a.fecha | date:'dd-MM-yyyy HH:mm:ss' }}</td><td class="mono">{{ a.nombre_usuario }}</td>
                    <td><app-estado [valor]="a.resultado" /></td><td class="mono">{{ a.ip || '—' }}</td>
                    <td class="muted">{{ a.detalle || '' }}</td></tr>
              } @empty { <tr><td colspan="5" class="vacio">Sin registros</td></tr> }
            </tbody>
          </table>
        } @else {
          <table class="tabla">
            <thead><tr><th>Fecha</th><th>Usuario</th><th>Tabla</th><th>Acción</th><th>ID</th><th>Cambios</th></tr></thead>
            <tbody>
              @for (a of auditoria(); track a.id_auditoria) {
                <tr><td class="nowrap">{{ a.fecha | date:'dd-MM-yyyy HH:mm:ss' }}</td><td class="mono">{{ a.usuario }}</td>
                    <td class="mono">{{ a.tabla }}</td><td><span class="badge">{{ a.accion }}</span></td><td>{{ a.id_registro }}</td>
                    <td class="small">{{ cambios(a) }}</td></tr>
              } @empty { <tr><td colspan="6" class="vacio">Sin registros</td></tr> }
            </tbody>
          </table>
        }
      </div>
    </div>`,
})
export class Bitacora {
  private api = inject(Api);
  private avisos = inject(Notificador);
  protected vista = signal<'accesos' | 'auditoria'>('accesos');
  protected accesos = signal<Acceso[]>([]);
  protected auditoria = signal<Auditoria[]>([]);

  constructor() { this.cargar(); }

  async cargar() {
    try {
      const [ac, au] = await Promise.all([
        this.api.get<Acceso[]>('/bitacora/accesos'),
        this.api.get<Auditoria[]>('/bitacora/auditoria'),
      ]);
      this.accesos.set(ac);
      this.auditoria.set(au);
    } catch (e) {
      this.avisos.error(mensajeError(e));
    }
  }

  /** Muestra solo los campos que cambiaron: "stock_actual: 250 → 151". */
  cambios(a: Auditoria): string {
    const antes = aObjeto(a.valor_anterior);
    const despues = aObjeto(a.valor_nuevo);
    if (!a.valor_anterior) return Object.entries(despues).map(([k, v]) => `${k}: ${v}`).join(' · ');
    return Object.keys(despues)
      .filter(k => String(antes[k]) !== String(despues[k]))
      .map(k => `${k}: ${antes[k] ?? '—'} → ${despues[k]}`)
      .join(' · ') || 'sin cambios visibles';
  }
}
