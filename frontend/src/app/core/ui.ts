import { Component, Injectable, Pipe, PipeTransform, input, output, signal } from '@angular/core';

// ---------------------------------------------------------------------
// Avisos flotantes (toasts)
// ---------------------------------------------------------------------
export interface Aviso { id: number; texto: string; tipo: 'ok' | 'bad' | 'info'; }

@Injectable({ providedIn: 'root' })
export class Notificador {
  readonly avisos = signal<Aviso[]>([]);
  private siguiente = 1;

  ok(texto: string) { this.mostrar(texto, 'ok'); }
  error(texto: string) { this.mostrar(texto, 'bad', 7000); }
  info(texto: string) { this.mostrar(texto, 'info'); }

  cerrar(id: number) { this.avisos.update(l => l.filter(a => a.id !== id)); }

  private mostrar(texto: string, tipo: Aviso['tipo'], ms = 4000) {
    const id = this.siguiente++;
    this.avisos.update(l => [...l, { id, texto, tipo }]);
    setTimeout(() => this.cerrar(id), ms);
  }
}

@Component({
  selector: 'app-avisos',
  template: `
    <div class="avisos">
      @for (a of notificador.avisos(); track a.id) {
        <div class="aviso {{ a.tipo }}" role="status" (click)="notificador.cerrar(a.id)">{{ a.texto }}</div>
      }
    </div>`,
  styles: `
    .avisos { position: fixed; right: 16px; bottom: 16px; z-index: 100; display: flex; flex-direction: column;
              gap: 8px; max-width: min(420px, calc(100vw - 32px)); }
    .aviso { box-shadow: 0 4px 16px rgba(0,0,0,.12); cursor: pointer; }`,
})
export class Avisos {
  constructor(public notificador: Notificador) {}
}

// ---------------------------------------------------------------------
// Ventana modal reutilizable
// ---------------------------------------------------------------------
@Component({
  selector: 'app-modal',
  template: `
    @if (abierto()) {
      <div class="fondo" (click)="cerrar.emit()">
        <div class="ventana card" [style.max-width.px]="ancho()" (click)="$event.stopPropagation()"
             role="dialog" aria-modal="true">
          <div class="card-header">
            <h2>{{ titulo() }}</h2>
            <button class="btn icono" type="button" (click)="cerrar.emit()" aria-label="Cerrar">✕</button>
          </div>
          <div class="card-body"><ng-content /></div>
        </div>
      </div>
    }`,
  styles: `
    .fondo { position: fixed; inset: 0; background: rgba(47, 38, 32, .45); z-index: 50; display: flex;
             align-items: flex-start; justify-content: center; padding: 6vh 16px; overflow-y: auto; }
    .ventana { width: 100%; }`,
})
export class Modal {
  abierto = input(false);
  titulo = input('');
  ancho = input(560);
  cerrar = output<void>();
}

// ---------------------------------------------------------------------
// Estados -> color de badge
// ---------------------------------------------------------------------
const COLORES: Record<string, string> = {
  OK: 'ok', Aprobada: 'ok', Facturada: 'ok', Disponible: 'ok', Resuelta: 'ok', Activo: 'ok', Finalizado: 'ok',
  Descontado: 'info', Utilizado: 'info', EnVerificacion: 'warn', Recibida: 'warn', Reservado: 'warn',
  Bajo: 'warn', Justo: 'warn', Pendiente: 'warn', BajoMinimo: 'warn', Fabricacion: 'info', Pintura: 'info', QA: 'info',
  RechazadaStock: 'bad', 'Sin stock': 'bad', Critico: 'bad', Falta: 'bad', Faltante: 'bad', Descartado: 'bad',
  Inactivo: 'bad', FALLIDO: 'bad', LOGOUT: '', EnEspera: '',
};

const NOMBRES: Record<string, string> = {
  EnVerificacion: 'En verificación', RechazadaStock: 'Falta stock', EnEspera: 'En espera',
  Fabricacion: 'Fabricación', Critico: 'Crítico', BajoMinimo: 'Bajo mínimo', Ferreteria: 'Ferretería',
  CARGA_INICIAL: 'Carga inicial', ENTRADA_FACTURA: 'Entrada factura', SALIDA_FABRICACION: 'Salida fabricación',
  AJUSTE: 'Ajuste', Sauna_Ext: 'Sauna exterior', Sauna_Int: 'Sauna interior',
};

@Pipe({ name: 'colorEstado' })
export class ColorEstadoPipe implements PipeTransform {
  transform(estado: string | null | undefined): string {
    return COLORES[estado ?? ''] ?? '';
  }
}

@Pipe({ name: 'nombre' })
export class NombrePipe implements PipeTransform {
  transform(valor: string | null | undefined): string {
    return NOMBRES[valor ?? ''] ?? valor ?? '';
  }
}

@Component({
  selector: 'app-estado',
  imports: [ColorEstadoPipe, NombrePipe],
  template: `<span class="badge {{ valor() | colorEstado }}">{{ texto() || (valor() | nombre) }}</span>`,
})
export class Estado {
  valor = input<string | null | undefined>('');
  texto = input('');
}
