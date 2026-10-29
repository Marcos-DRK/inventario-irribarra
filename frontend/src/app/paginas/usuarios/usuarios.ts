import { DatePipe } from '@angular/common';
import { Component, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';

import { Api, mensajeError } from '../../core/api';
import { Auth } from '../../core/auth';
import { Estado, Modal, Notificador } from '../../core/ui';

interface Usuario {
  id_usuario: number; rut: string; nombres: string; apellidos: string; correo: string; nombre_usuario: string;
  rol: string; estado: string; fecha_creacion: string; ultimo_acceso: string | null;
}

@Component({
  selector: 'app-usuarios',
  imports: [FormsModule, Estado, Modal, DatePipe],
  template: `
    <div class="card">
      <div class="card-header">
        <h2>Usuarios del sistema</h2>
        <button class="btn primario" type="button" (click)="nuevo()">+ Nuevo usuario</button>
      </div>
      <div class="tabla-wrap">
        <table class="tabla">
          <thead><tr><th>Usuario</th><th>Nombre</th><th>RUT</th><th>Correo</th><th>Rol</th><th>Estado</th>
                     <th>Último acceso</th><th></th></tr></thead>
          <tbody>
            @for (u of usuarios(); track u.id_usuario) {
              <tr>
                <td class="mono">{{ u.nombre_usuario }}</td>
                <td>{{ u.nombres }} {{ u.apellidos }}</td>
                <td class="nowrap">{{ u.rut }}</td>
                <td>{{ u.correo }}</td>
                <td><span class="badge" [class.info]="u.rol === 'Administrador'">{{ u.rol }}</span></td>
                <td><app-estado [valor]="u.estado" /></td>
                <td class="nowrap small">{{ u.ultimo_acceso ? (u.ultimo_acceso | date:'dd-MM-yyyy HH:mm') : 'Nunca' }}</td>
                <td class="right nowrap">
                  <button class="btn chico" type="button" (click)="editar(u)">Editar</button>
                  <button class="btn chico" type="button" (click)="clave.set(u); nuevaClave = ''">Contraseña</button>
                </td>
              </tr>
            }
          </tbody>
        </table>
      </div>
    </div>

    <app-modal [abierto]="editando() !== null" [titulo]="editando() === 'nuevo' ? 'Nuevo usuario' : 'Editar usuario'"
               [ancho]="600" (cerrar)="editando.set(null)">
      <form #f="ngForm" (ngSubmit)="guardar()">
        <div class="form-grid">
          @if (editando() === 'nuevo') {
            <div class="campo"><label>Nombre de usuario</label>
              <input class="input" name="nu" [(ngModel)]="form.nombre_usuario" pattern="[a-z0-9._-]+" minlength="3" required />
              <span class="ayuda">Minúsculas, números, punto o guion</span></div>
            <div class="campo"><label>Contraseña</label>
              <input class="input" type="password" name="pw" [(ngModel)]="form.password" minlength="8" required autocomplete="new-password" />
              <span class="ayuda">Mínimo 8 caracteres (se guarda con bcrypt)</span></div>
          }
          <div class="campo"><label>Nombres</label><input class="input" name="n" [(ngModel)]="form.nombres" required /></div>
          <div class="campo"><label>Apellidos</label><input class="input" name="a" [(ngModel)]="form.apellidos" required /></div>
          <div class="campo"><label>RUT</label><input class="input" name="r" [(ngModel)]="form.rut" required /></div>
          <div class="campo"><label>Correo</label><input class="input" type="email" name="c" [(ngModel)]="form.correo" required /></div>
          <div class="campo"><label>Rol</label>
            <select class="input" name="rol" [(ngModel)]="form.rol">
              <option value="Trabajador">Trabajador de taller</option><option value="Administrador">Administrador</option>
            </select></div>
          @if (editando() !== 'nuevo') {
            <div class="campo"><label>Estado</label>
              <select class="input" name="est" [(ngModel)]="form.estado">
                <option value="Activo">Activo</option><option value="Inactivo">Inactivo (no puede ingresar)</option>
              </select></div>
          }
        </div>
        <div class="row end mt">
          <button class="btn" type="button" (click)="editando.set(null)">Cancelar</button>
          <button class="btn primario" type="submit" [disabled]="f.invalid">Guardar</button>
        </div>
      </form>
    </app-modal>

    <app-modal [abierto]="!!clave()" [titulo]="'Cambiar contraseña de ' + (clave()?.nombre_usuario ?? '')" (cerrar)="clave.set(null)">
      <form #fc="ngForm" (ngSubmit)="cambiarClave()">
        <div class="campo"><label>Nueva contraseña</label>
          <input class="input" type="password" name="nc" [(ngModel)]="nuevaClave" minlength="8" required autocomplete="new-password" /></div>
        <div class="row end mt">
          <button class="btn" type="button" (click)="clave.set(null)">Cancelar</button>
          <button class="btn primario" type="submit" [disabled]="fc.invalid">Cambiar</button>
        </div>
      </form>
    </app-modal>`,
})
export class Usuarios {
  private api = inject(Api);
  private avisos = inject(Notificador);
  private auth = inject(Auth);

  protected usuarios = signal<Usuario[]>([]);
  protected editando = signal<'nuevo' | number | null>(null);
  protected clave = signal<Usuario | null>(null);
  protected nuevaClave = '';
  protected form = this.vacio();

  constructor() { this.cargar(); }

  private vacio() {
    return { nombre_usuario: '', password: '', nombres: '', apellidos: '', rut: '', correo: '', rol: 'Trabajador',
             estado: 'Activo' };
  }

  async cargar() {
    try {
      this.usuarios.set(await this.api.get<Usuario[]>('/usuarios'));
    } catch (e) {
      this.avisos.error(mensajeError(e));
    }
  }

  nuevo() {
    this.form = this.vacio();
    this.editando.set('nuevo');
  }

  editar(u: Usuario) {
    this.form = { ...this.vacio(), nombres: u.nombres, apellidos: u.apellidos, rut: u.rut, correo: u.correo,
                  rol: u.rol, estado: u.estado };
    this.editando.set(u.id_usuario);
  }

  async guardar() {
    const id = this.editando();
    try {
      if (id === 'nuevo') {
        const { estado, ...datos } = this.form;
        await this.api.post('/usuarios', datos);
        this.avisos.ok(`Usuario ${this.form.nombre_usuario} creado`);
      } else {
        const { nombre_usuario, password, ...datos } = this.form;
        await this.api.put(`/usuarios/${id}`, datos);
        this.avisos.ok('Usuario actualizado');
      }
      this.editando.set(null);
      await this.cargar();
    } catch (e) {
      this.avisos.error(mensajeError(e));
    }
  }

  async cambiarClave() {
    const u = this.clave()!;
    try {
      await this.api.patch(`/usuarios/${u.id_usuario}/password`, { password: this.nuevaClave });
      this.avisos.ok('Contraseña actualizada');
      this.clave.set(null);
    } catch (e) {
      this.avisos.error(mensajeError(e));
    }
  }
}
