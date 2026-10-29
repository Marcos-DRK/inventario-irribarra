import { CdkDrag, CdkDragDrop, CdkDropList, CdkDropListGroup } from '@angular/cdk/drag-drop';
import { DatePipe, DecimalPipe } from '@angular/common';
import { Component, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';

import { Api, mensajeError } from '../../core/api';
import { Estado, Modal, NombrePipe, Notificador } from '../../core/ui';

interface Comanda {
  id_comanda: number; estado: string; folio: string; id_nota_venta: number; producto: string; cantidad: number;
  diseno_personalizado: string | null; id_trabajador_asignado: number | null; trabajador: string | null;
  fecha_despacho: string | null; fecha_inicio: string | null; fecha_termino: string | null;
}
interface Retazo {
  id_merma: number; material: string; largo_cm: number; ancho_cm: number; espesor_cm: number;
  valor_estimado: number; bodega: string; estado?: string;
}

@Component({
  selector: 'app-comandas',
  imports: [CdkDropListGroup, CdkDropList, CdkDrag, FormsModule, RouterLink, Modal, Estado, NombrePipe,
            DatePipe, DecimalPipe],
  templateUrl: './comandas.html',
  styleUrl: './comandas.css',
})
export class Comandas {
  private api = inject(Api);
  private avisos = inject(Notificador);

  protected etapas = ['EnEspera', 'Fabricacion', 'Pintura', 'QA', 'Finalizado'];
  protected comandas = signal<Comanda[]>([]);
  protected actualizado = signal<Date | null>(null);
  protected trabajadores = signal<{ id_usuario: number; nombre: string }[]>([]);
  protected porEtapa = computed(() => {
    const grupos: Record<string, Comanda[]> = {};
    for (const e of this.etapas) grupos[e] = [];
    for (const c of this.comandas()) grupos[c.estado]?.push(c);
    return grupos;
  });

  // Panel de detalle
  protected seleccionada = signal<Comanda | null>(null);
  protected sugeridas = signal<Retazo[]>([]);
  protected reservadas = signal<Retazo[]>([]);
  protected asignado: number | null = null;

  constructor() {
    this.cargar();
    this.api.get<{ id_usuario: number; nombre: string }[]>('/comandas/trabajadores')
      .then(t => this.trabajadores.set(t)).catch(() => {});
  }

  async cargar() {
    try {
      const r = await this.api.get<{ comandas: Comanda[] }>('/comandas');
      this.comandas.set(r.comandas);
      this.actualizado.set(new Date());
    } catch (e) {
      this.avisos.error(mensajeError(e));
    }
  }

  /** Arrastrar una tarjeta a otra columna = cambiar de etapa. */
  async soltar(evento: CdkDragDrop<string, string, Comanda>) {
    if (evento.previousContainer === evento.container) return;
    await this.mover(evento.item.data, evento.container.data);
  }

  async mover(c: Comanda, estado: string) {
    const anterior = c.estado;
    this.comandas.update(l => l.map(x => x.id_comanda === c.id_comanda ? { ...x, estado } : x));
    try {
      const actual = await this.api.patch<Comanda>(`/comandas/${c.id_comanda}/estado`, { estado });
      this.comandas.update(l => l.map(x => x.id_comanda === c.id_comanda ? actual : x));
      if (anterior === 'EnEspera' && estado === 'Fabricacion') {
        this.avisos.ok(`Comanda ${c.id_comanda} en fabricación: se descontó el material de la receta`);
      }
      if (this.seleccionada()?.id_comanda === c.id_comanda) this.seleccionada.set(actual);
    } catch (e) {
      this.avisos.error(mensajeError(e));
      await this.cargar();
    }
  }

  vecina(estado: string, paso: number): string | null {
    return this.etapas[this.etapas.indexOf(estado) + paso] ?? null;
  }

  async abrir(c: Comanda) {
    this.seleccionada.set(c);
    this.asignado = c.id_trabajador_asignado;
    this.sugeridas.set([]);
    this.reservadas.set([]);
    if (c.estado === 'EnEspera') await this.cargarRetazos(c.id_comanda);
  }

  private async cargarRetazos(id: number) {
    try {
      const r = await this.api.get<{ sugeridas: Retazo[]; reservadas: Retazo[] }>(`/comandas/${id}/mermas-sugeridas`);
      this.sugeridas.set(r.sugeridas);
      this.reservadas.set(r.reservadas);
    } catch (e) {
      this.avisos.error(mensajeError(e));
    }
  }

  async asignar() {
    const c = this.seleccionada()!;
    try {
      const actual = await this.api.patch<Comanda>(`/comandas/${c.id_comanda}/asignar`, { id_trabajador: this.asignado });
      this.comandas.update(l => l.map(x => x.id_comanda === c.id_comanda ? actual : x));
      this.seleccionada.set(actual);
      this.avisos.ok('Trabajador asignado');
    } catch (e) {
      this.avisos.error(mensajeError(e));
    }
  }

  async retazo(r: Retazo, accion: 'reservar' | 'liberar') {
    const c = this.seleccionada()!;
    try {
      await this.api.patch(`/mermas/${r.id_merma}`, { accion, id_comanda: c.id_comanda });
      this.avisos.ok(accion === 'reservar'
        ? 'Retazo reservado: reemplazará 1 unidad al pasar a fabricación'
        : 'Retazo liberado');
      await this.cargarRetazos(c.id_comanda);
    } catch (e) {
      this.avisos.error(mensajeError(e));
    }
  }
}
