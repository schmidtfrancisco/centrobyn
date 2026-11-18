import { HttpErrorResponse } from '@angular/common/http';

/** Cuerpo de error de la API: Problem Details (RFC 9457) con el formato del contrato. */
export interface ApiProblem {
  status: number;
  title: string;
  code: string;
  details?: Record<string, unknown>;
}

/** Devuelve el `code` del error de la API, o `null` si la respuesta no es un Problem Details. */
export function problemCode(error: unknown): string | null {
  if (error instanceof HttpErrorResponse) {
    const body = error.error as Partial<ApiProblem> | null;
    if (body && typeof body === 'object' && typeof body.code === 'string') {
      return body.code;
    }
  }
  return null;
}
