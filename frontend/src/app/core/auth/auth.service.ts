import { HttpClient, HttpErrorResponse, HttpHeaders } from '@angular/common/http';
import { Injectable, computed, inject, signal } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { problemCode } from '../api/api-problem';

export type UserRole =
  | 'ADMIN'
  | 'STAFF'
  | 'GATEKEEPER'
  | 'TEACHER'
  | 'MEMBER'
  | 'ACCOUNTANT'
  | 'COLLECTOR';

/** Respuesta de `GET /api/auth/me`. */
export interface CurrentUser {
  id: number;
  email: string;
  firstName: string;
  lastName: string;
  roles: UserRole[];
}

/** Resultado de un intento de ingreso. */
export type LoginResult =
  | { ok: true; user: CurrentUser }
  | { ok: false; reason: 'BAD_CREDENTIALS' | 'USER_DISABLED' | 'UNAVAILABLE' };

/**
 * Sesión del usuario. La sesión vive en el backend (cookie HttpOnly); acá solo
 * se guarda quién es el usuario, que se pide a `GET /api/auth/me`.
 */
@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly http = inject(HttpClient);

  private readonly _user = signal<CurrentUser | null>(null);
  readonly user = this._user.asReadonly();
  readonly isAuthenticated = computed(() => this._user() !== null);

  /**
   * Pregunta al backend si hay una sesión abierta. Se llama al arrancar la app,
   * así al recargar la página se sigue adentro. Además trae la cookie
   * XSRF-TOKEN, que hace falta para poder entrar.
   */
  async loadSession(): Promise<CurrentUser | null> {
    try {
      const user = await firstValueFrom(this.http.get<CurrentUser>('/api/auth/me'));
      this._user.set(user);
    } catch {
      this._user.set(null);
    }
    return this._user();
  }

  /** `email` y `password` van tal cual: el backend normaliza el correo y nunca recorta la contraseña. */
  async login(email: string, password: string): Promise<LoginResult> {
    // URLSearchParams codifica todo (HttpParams deja "+" sin codificar y llegaría como espacio).
    const body = new URLSearchParams({ email, password }).toString();
    const headers = new HttpHeaders({ 'Content-Type': 'application/x-www-form-urlencoded' });

    try {
      await firstValueFrom(this.http.post('/api/auth/login', body, { headers }));
    } catch (error) {
      const code = problemCode(error);
      if (code === 'BAD_CREDENTIALS' || code === 'USER_DISABLED') {
        return { ok: false, reason: code };
      }
      // Un 403 sin Problem Details es el token CSRF vencido o ausente: se pide uno
      // nuevo para que el próximo intento funcione.
      if (error instanceof HttpErrorResponse && error.status === 403) {
        await this.loadSession();
      }
      return { ok: false, reason: 'UNAVAILABLE' };
    }

    const user = await this.loadSession();
    return user ? { ok: true, user } : { ok: false, reason: 'UNAVAILABLE' };
  }
}
