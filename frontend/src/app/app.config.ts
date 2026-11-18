import {
  ApplicationConfig,
  inject,
  provideAppInitializer,
  provideBrowserGlobalErrorListeners,
} from '@angular/core';
import { provideHttpClient, withXsrfConfiguration } from '@angular/common/http';
import { provideRouter } from '@angular/router';
import { routes } from './app.routes';
import { AuthService } from './core/auth/auth.service';

export const appConfig: ApplicationConfig = {
  providers: [
    provideBrowserGlobalErrorListeners(),
    // CSRF: el backend deja el token en la cookie XSRF-TOKEN y Angular lo
    // reenvía en el encabezado X-XSRF-TOKEN en cada pedido que modifica algo.
    provideHttpClient(withXsrfConfiguration({ cookieName: 'XSRF-TOKEN', headerName: 'X-XSRF-TOKEN' })),
    provideRouter(routes),
    // Antes de la primera navegación: ¿ya hay una sesión abierta? (recargar la página)
    provideAppInitializer(() => inject(AuthService).loadSession()),
  ],
};
