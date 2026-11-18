import { Component, inject } from '@angular/core';
import { AuthService } from '../../core/auth/auth.service';

/**
 * Pantalla de inicio provisoria: solo confirma que hay una sesión iniciada.
 * La pantalla y el menú de cada rol se definen en otra historia.
 */
@Component({
  selector: 'app-home',
  template: `
    @if (auth.user(); as user) {
      <main class="flex min-h-dvh items-center justify-center p-6">
        <div class="flex flex-col gap-1 text-center">
          <h1 class="text-2xl font-semibold">Hola, {{ user.firstName }}</h1>
          <p class="text-sm text-neutral-500">Sesión iniciada como {{ user.email }}.</p>
        </div>
      </main>
    }
  `,
})
export class Home {
  protected readonly auth = inject(AuthService);
}
