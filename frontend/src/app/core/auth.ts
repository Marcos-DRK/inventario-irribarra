import { HttpErrorResponse, HttpInterceptorFn } from '@angular/common/http';
import { Injectable, computed, inject, signal } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { catchError, throwError } from 'rxjs';

import { Api } from './api';

export interface Usuario {
  id: number;
  usuario: string;
  rol: 'Administrador' | 'Trabajador';
  nombre: string;
}

const CLAVE = 'irribarra.sesion';

function leerSesion(): { token: string; usuario: Usuario } | null {
  try {
    const texto = localStorage.getItem(CLAVE);
    return texto ? JSON.parse(texto) : null;
  } catch {
    return null;
  }
}

/** Estado de la sesión (token JWT + datos del usuario). */
@Injectable({ providedIn: 'root' })
export class Auth {
  private api = inject(Api);
  private router = inject(Router);
  private sesion = signal(leerSesion());

  readonly usuario = computed(() => this.sesion()?.usuario ?? null);
  readonly token = computed(() => this.sesion()?.token ?? null);
  readonly esAdmin = computed(() => this.usuario()?.rol === 'Administrador');
  readonly iniciales = computed(() =>
    (this.usuario()?.nombre ?? '').split(' ').map(p => p[0]).slice(0, 2).join('').toUpperCase());

  async login(usuario: string, password: string): Promise<void> {
    const r = await this.api.post<{ token: string; usuario: Usuario }>('/auth/login', { usuario, password });
    this.sesion.set(r);
    try { localStorage.setItem(CLAVE, JSON.stringify(r)); } catch { /* sin almacenamiento */ }
  }

  async logout(): Promise<void> {
    if (this.token()) {
      try { await this.api.post('/auth/logout'); } catch { /* la sesión se cierra igual */ }
    }
    this.limpiar();
    this.router.navigateByUrl('/login');
  }

  /** Cierra la sesión local sin llamar a la API (token vencido). */
  limpiar(): void {
    this.sesion.set(null);
    try { localStorage.removeItem(CLAVE); } catch { /* sin almacenamiento */ }
  }
}

/** Agrega el token a cada petición y envía al login si la sesión venció. */
export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const auth = inject(Auth);
  const router = inject(Router);
  const token = auth.token();
  const peticion = token ? req.clone({ setHeaders: { Authorization: `Bearer ${token}` } }) : req;
  return next(peticion).pipe(
    catchError((error: HttpErrorResponse) => {
      if (error.status === 401 && !req.url.endsWith('/auth/login')) {
        auth.limpiar();
        router.navigateByUrl('/login');
      }
      return throwError(() => error);
    }),
  );
};

export const authGuard: CanActivateFn = () => {
  const auth = inject(Auth);
  return auth.token() ? true : inject(Router).parseUrl('/login');
};

export const adminGuard: CanActivateFn = () => {
  const auth = inject(Auth);
  return auth.esAdmin() ? true : inject(Router).parseUrl('/dashboard');
};
