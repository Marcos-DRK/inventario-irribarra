import { Component, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';

import { mensajeError } from '../../core/api';
import { Auth } from '../../core/auth';

@Component({
  selector: 'app-login',
  imports: [FormsModule],
  template: `
    <div class="fondo">
      <form class="card caja" (ngSubmit)="entrar()">
        <img class="logo" src="logo.png" alt="Tomas Irribarra · Saunas & Wellness">
        <h1>Taller Irribarra</h1>
        <p class="muted small">Sistema de Gestión de Inventario y Producción</p>

        <div class="campo">
          <label for="usuario">Usuario</label>
          <input id="usuario" class="input" name="usuario" [(ngModel)]="usuario" autocomplete="username" required />
        </div>
        <div class="campo">
          <label for="password">Contraseña</label>
          <input id="password" class="input" name="password" type="password" [(ngModel)]="password"
                 autocomplete="current-password" required />
        </div>

        @if (error()) { <div class="aviso bad">{{ error() }}</div> }

        <button class="btn primario" type="submit" [disabled]="cargando() || !usuario || !password">
          {{ cargando() ? 'Ingresando…' : 'Iniciar sesión' }}
        </button>
        <p class="muted small pie">Acceso restringido · Administrador / Trabajador de taller</p>
      </form>
    </div>`,
  styles: `
    .fondo { min-height: 100vh; display: grid; place-items: center; padding: 16px;
             background: linear-gradient(135deg, #e9e6dc, #f5f1e8 60%, #efe7da); }
    .caja { width: 100%; max-width: 340px; padding: 28px 26px; display: flex; flex-direction: column; gap: 12px; }
    .logo { width: 110px; height: 110px; border-radius: 50%; object-fit: cover; margin: 0 auto; }
    h1 { text-align: center; font-size: 19px; }
    p { text-align: center; margin: -6px 0 6px; }
    .pie { margin: 4px 0 0; }`,
})
export class Login {
  private auth = inject(Auth);
  private router = inject(Router);

  protected usuario = '';
  protected password = '';
  protected cargando = signal(false);
  protected error = signal('');

  constructor() {
    if (this.auth.token()) this.router.navigateByUrl('/dashboard');
  }

  async entrar() {
    this.cargando.set(true);
    this.error.set('');
    try {
      await this.auth.login(this.usuario, this.password);
      this.router.navigateByUrl('/dashboard');
    } catch (e) {
      this.error.set(mensajeError(e));
    } finally {
      this.cargando.set(false);
    }
  }
}
