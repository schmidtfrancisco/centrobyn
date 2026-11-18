import { Component, DestroyRef, ElementRef, inject, signal, viewChild } from '@angular/core';
import { Router } from '@angular/router';
import { LucideCircleCheck, LucideCircleX, LucideEye, LucideEyeOff, LucideLogIn } from '@lucide/angular';
import { AuthService } from '../../../core/auth/auth.service';

type Status = 'idle' | 'loading' | 'bad' | 'off' | 'unavailable' | 'ok';

/** Cuánto se muestra el saludo antes de ir a la pantalla de inicio. */
const WELCOME_DELAY_MS = 800;

@Component({
  selector: 'app-login',
  imports: [LucideCircleCheck, LucideCircleX, LucideEye, LucideEyeOff, LucideLogIn],
  templateUrl: './login.html',
})
export class Login {
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);

  private readonly emailInput = viewChild.required<ElementRef<HTMLInputElement>>('emailInput');
  private readonly passwordInput = viewChild.required<ElementRef<HTMLInputElement>>('passwordInput');

  protected readonly email = signal('');
  protected readonly password = signal('');
  protected readonly showPassword = signal(false);
  protected readonly emailError = signal('');
  protected readonly passwordError = signal('');
  protected readonly status = signal<Status>('idle');
  protected readonly welcomeName = signal('');

  private timer: ReturnType<typeof setTimeout> | undefined;

  constructor() {
    inject(DestroyRef).onDestroy(() => clearTimeout(this.timer));
  }

  protected onEmail(value: string): void {
    this.email.set(value);
    this.emailError.set('');
  }

  protected onPassword(value: string): void {
    this.password.set(value);
    this.passwordError.set('');
  }

  protected toggleShowPassword(): void {
    this.showPassword.update((show) => !show);
  }

  protected async submit(event: Event): Promise<void> {
    event.preventDefault();
    if (this.status() === 'loading' || this.status() === 'ok') {
      return;
    }

    // Campos vacíos: se indica qué falta y no se hace el intento.
    // El correo vacío se mira sin espacios; la contraseña nunca se recorta.
    const emailError = this.email().trim() ? '' : 'Ingresá tu correo.';
    const passwordError = this.password() ? '' : 'Ingresá tu contraseña.';
    this.emailError.set(emailError);
    this.passwordError.set(passwordError);
    if (emailError || passwordError) {
      this.status.set('idle');
      (emailError ? this.emailInput() : this.passwordInput()).nativeElement.focus();
      return;
    }

    this.status.set('loading');
    const result = await this.auth.login(this.email(), this.password());

    if (result.ok) {
      this.welcomeName.set(result.user.firstName);
      this.status.set('ok');
      this.timer = setTimeout(() => this.router.navigateByUrl('/'), WELCOME_DELAY_MS);
      return;
    }

    this.status.set(
      result.reason === 'BAD_CREDENTIALS' ? 'bad' : result.reason === 'USER_DISABLED' ? 'off' : 'unavailable',
    );
    if (result.reason !== 'UNAVAILABLE') {
      this.password.set('');
      setTimeout(() => this.passwordInput().nativeElement.focus());
    }
  }
}
