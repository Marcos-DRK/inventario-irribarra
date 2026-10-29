import { CurrencyPipe, DatePipe, DecimalPipe } from '@angular/common';
import { Component, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';

import { Api, mensajeError } from '../../core/api';
import { Estado, Modal, Notificador } from '../../core/ui';

interface Merma {
  id_merma: number; material: string; largo_cm: number; ancho_cm: number; espesor_cm: number; supera_minimo: number;
  valor_estimado: number; estado: string; bodega: string; fecha_registro: string; id_comanda_uso: number | null;
  registrado_por: string;
}
interface MaterialMadera { id_material: number; nombre: string; tipo: string; id_bodega: number; }

@Component({
  selector: 'app-mermas',
  imports: [FormsModule, Estado, Modal, DatePipe, DecimalPipe, CurrencyPipe],
  templateUrl: './mermas.html',
})
export class Mermas {
  private api = inject(Api);
  private avisos = inject(Notificador);

  protected mermas = signal<Merma[]>([]);
  protected filtro = signal('');
  protected filtros = ['', 'Disponible', 'Reservado', 'Utilizado', 'Descartado'];
  protected visibles = computed(() =>
    this.filtro() ? this.mermas().filter(m => m.estado === this.filtro()) : this.mermas());
  protected ahorro = computed(() =>
    this.mermas().filter(m => m.estado === 'Utilizado').reduce((s, m) => s + Number(m.valor_estimado), 0));

  protected registrando = signal(false);
  protected maderas = signal<MaterialMadera[]>([]);
  protected bodegas = signal<{ id_bodega: number; nombre: string }[]>([]);
  protected minimos = signal<Record<string, number>>({});
  protected form = { id_material: null as number | null, largo_cm: null as number | null,
                     ancho_cm: null as number | null, espesor_cm: null as number | null, id_bodega: 1 };

  constructor() {
    this.cargar();
    Promise.all([
      this.api.get<MaterialMadera[]>('/materiales', { tipo: 'Madera' }),
      this.api.get<{ id_bodega: number; nombre: string }[]>('/bodegas'),
      this.api.get<{ clave: string; valor: number }[]>('/mermas/parametros'),
    ]).then(([m, b, p]) => {
      this.maderas.set(m);
      this.bodegas.set(b);
      this.minimos.set(Object.fromEntries(p.map(x => [x.clave, Number(x.valor)])));
    }).catch(e => this.avisos.error(mensajeError(e)));
  }

  async cargar() {
    try {
      this.mermas.set(await this.api.get<Merma[]>('/mermas'));
    } catch (e) {
      this.avisos.error(mensajeError(e));
    }
  }

  /** Vista previa de la regla que aplica el trigger trg_merma_clasificar. */
  reutilizable(): boolean | null {
    const { largo_cm, ancho_cm } = this.form;
    if (!largo_cm || !ancho_cm) return null;
    return largo_cm >= (this.minimos()['merma_largo_minimo_cm'] ?? 0)
        && ancho_cm >= (this.minimos()['merma_ancho_minimo_cm'] ?? 0);
  }

  abrir() {
    this.form = { id_material: null, largo_cm: null, ancho_cm: null, espesor_cm: null, id_bodega: 1 };
    this.registrando.set(true);
  }

  async guardar() {
    try {
      const m = await this.api.post<Merma>('/mermas', this.form);
      this.registrando.set(false);
      if (m.supera_minimo) this.avisos.ok(`Retazo #${m.id_merma} registrado como reutilizable`);
      else this.avisos.info(`Retazo #${m.id_merma} bajo la medida mínima: quedó como descarte`);
      await this.cargar();
    } catch (e) {
      this.avisos.error(mensajeError(e));
    }
  }

  async accion(m: Merma, accion: 'liberar' | 'descartar') {
    try {
      await this.api.patch(`/mermas/${m.id_merma}`, { accion });
      await this.cargar();
    } catch (e) {
      this.avisos.error(mensajeError(e));
    }
  }
}
