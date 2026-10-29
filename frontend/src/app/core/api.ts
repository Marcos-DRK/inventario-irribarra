import { HttpClient, HttpErrorResponse, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { firstValueFrom } from 'rxjs';

/**
 * Dirección de la API FastAPI (se ejecuta en el mismo computador).
 * Con `ng serve` (puerto 4200) se llama a la API en el 8000; la web construida
 * la sirve la propia API, así que basta una ruta relativa.
 */
export const API_URL = location.port === '4200' ? 'http://localhost:8000/api' : '/api';

type Parametros = Record<string, string | number | boolean | null | undefined>;

function aParams(parametros?: Parametros): HttpParams {
  let p = new HttpParams();
  for (const [clave, valor] of Object.entries(parametros ?? {})) {
    if (valor !== null && valor !== undefined && valor !== '') p = p.set(clave, String(valor));
  }
  return p;
}

/** Cliente HTTP con promesas (async/await) para todas las pantallas. */
@Injectable({ providedIn: 'root' })
export class Api {
  private http = inject(HttpClient);

  get<T>(ruta: string, parametros?: Parametros): Promise<T> {
    return firstValueFrom(this.http.get<T>(API_URL + ruta, { params: aParams(parametros) }));
  }

  post<T>(ruta: string, cuerpo: unknown = {}): Promise<T> {
    return firstValueFrom(this.http.post<T>(API_URL + ruta, cuerpo));
  }

  put<T>(ruta: string, cuerpo: unknown): Promise<T> {
    return firstValueFrom(this.http.put<T>(API_URL + ruta, cuerpo));
  }

  patch<T>(ruta: string, cuerpo: unknown): Promise<T> {
    return firstValueFrom(this.http.patch<T>(API_URL + ruta, cuerpo));
  }

  delete<T>(ruta: string): Promise<T> {
    return firstValueFrom(this.http.delete<T>(API_URL + ruta));
  }

  /** Descarga un archivo (PDF / Excel) respetando el nombre que envía la API. */
  async descargar(ruta: string): Promise<void> {
    const resp = await firstValueFrom(
      this.http.get(API_URL + ruta, { observe: 'response', responseType: 'blob' }));
    const disposicion = resp.headers.get('Content-Disposition') ?? '';
    const nombre = /filename="?([^"]+)"?/.exec(disposicion)?.[1] ?? 'reporte';
    const url = URL.createObjectURL(resp.body!);
    const a = document.createElement('a');
    a.href = url;
    a.download = nombre;
    a.click();
    setTimeout(() => URL.revokeObjectURL(url), 2000);
  }
}

/** Convierte cualquier error de la API en un mensaje legible. */
export function mensajeError(error: unknown): string {
  if (error instanceof HttpErrorResponse) {
    if (error.status === 0) return 'No hay conexión con la API (¿está iniciada en el puerto 8000?)';
    const detalle = error.error?.detail;
    if (typeof detalle === 'string') return detalle;
    if (Array.isArray(detalle)) {
      return detalle.map((d: { loc?: string[]; msg: string }) =>
        `${d.loc?.slice(1).join('.') ?? ''}: ${d.msg}`).join(' · ');
    }
    return `Error ${error.status}`;
  }
  return error instanceof Error ? error.message : 'Error inesperado';
}
