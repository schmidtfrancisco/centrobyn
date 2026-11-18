package ar.org.centroblancoynegro.gestion.config;

import ar.org.centroblancoynegro.gestion.auth.CsrfCookieFilter;
import ar.org.centroblancoynegro.gestion.auth.LoginHandlers;
import ar.org.centroblancoynegro.gestion.auth.LoginUserDetailsService;
import jakarta.servlet.DispatcherType;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.authentication.AuthenticationProvider;
import org.springframework.security.authentication.ProviderManager;
import org.springframework.security.authentication.AccountStatusUserDetailsChecker;
import org.springframework.security.authentication.dao.DaoAuthenticationProvider;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.crypto.factory.PasswordEncoderFactories;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.csrf.CsrfFilter;

/**
 * Seguridad de la API.
 *
 * <ul>
 *   <li>Sesión en la memoria del backend (sin Spring Session), en una cookie
 *       HttpOnly. Se permiten varias sesiones abiertas por usuario.</li>
 *   <li>Al entrar se genera un identificador de sesión nuevo (protección contra
 *       la fijación de sesión, el comportamiento por defecto).</li>
 *   <li>CSRF con el token en la cookie XSRF-TOKEN, que vuelve en el encabezado
 *       X-XSRF-TOKEN (lo que espera Angular).</li>
 * </ul>
 */
@Configuration
public class SecurityConfig {

    public static final String LOGIN_URL = "/api/auth/login";

    /** Contraseñas guardadas como {@code {bcrypt}} + hash. */
    @Bean
    public PasswordEncoder passwordEncoder() {
        return PasswordEncoderFactories.createDelegatingPasswordEncoder();
    }

    /**
     * Comprueba primero la contraseña y después el estado de la cuenta. Así un
     * usuario desactivado con una contraseña incorrecta recibe "Correo o contraseña
     * incorrectos", y solo con la contraseña correcta se entera de que está
     * desactivado. (Por defecto Spring revisa el estado antes que la contraseña.)
     */
    private static AuthenticationProvider authenticationProvider(LoginUserDetailsService userDetailsService,
                                                                 PasswordEncoder passwordEncoder) {
        DaoAuthenticationProvider provider = new DaoAuthenticationProvider(userDetailsService);
        provider.setPasswordEncoder(passwordEncoder);
        provider.setPreAuthenticationChecks(user -> { });
        provider.setPostAuthenticationChecks(new AccountStatusUserDetailsChecker());
        return provider;
    }

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http,
                                                   LoginUserDetailsService userDetailsService,
                                                   PasswordEncoder passwordEncoder,
                                                   LoginHandlers loginHandlers) throws Exception {
        http
                .authenticationManager(new ProviderManager(
                        authenticationProvider(userDetailsService, passwordEncoder)))
                .authorizeHttpRequests(auth -> auth
                        .dispatcherTypeMatchers(DispatcherType.ERROR).permitAll()
                        .requestMatchers(LOGIN_URL).permitAll()
                        .anyRequest().authenticated())
                .formLogin(form -> form
                        // La pantalla de ingreso es de Angular: así Spring no genera la suya.
                        .loginPage("/login")
                        .loginProcessingUrl(LOGIN_URL)
                        .usernameParameter("email")
                        .passwordParameter("password")
                        .successHandler(loginHandlers)
                        .failureHandler(loginHandlers))
                .exceptionHandling(ex -> ex.authenticationEntryPoint(loginHandlers))
                .csrf(csrf -> csrf.spa())
                .addFilterAfter(new CsrfCookieFilter(), CsrfFilter.class)
                // Sin pedidos guardados: es una API, no hay a dónde volver después de entrar.
                .requestCache(cache -> cache.disable())
                // Salir del sistema es de otra historia.
                .logout(AbstractHttpConfigurer::disable);
        return http.build();
    }
}
