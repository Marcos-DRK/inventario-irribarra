import { Injectable, signal } from '@angular/core';

export interface LineaBorrador { id_material: number; cantidad: number; }

/** Lleva los materiales faltantes (de una nota o de las alertas) al formulario de compra. */
@Injectable({ providedIn: 'root' })
export class BorradorCompra {
  readonly lineas = signal<LineaBorrador[]>([]);

  preparar(lineas: LineaBorrador[]) { this.lineas.set(lineas); }

  tomar(): LineaBorrador[] {
    const l = this.lineas();
    this.lineas.set([]);
    return l;
  }
}
