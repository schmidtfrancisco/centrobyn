package ar.org.centroblancoynegro.gestion.auth;

import ar.org.centroblancoynegro.gestion.web.ApiProblem;
import ar.org.centroblancoynegro.gestion.web.ApiProblemWriter;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.security.authentication.DisabledException;
import org.springframework.security.authentication.InternalAuthenticationServiceException;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.security.web.authentication.AuthenticationFailureHandler;
import org.springframework.security.web.authentication.AuthenticationSuccessHandler;
import org.springframework.security.web.csrf.CsrfToken;
import org.springframework.stereotype.Component;

import java.io.IOException;

/**
 * Respuestas HTTP del ingreso al sistema, según el contrato de
 * {@code POST /api/auth/login} y {@code GET /api/auth/me}.
 */
@Component
public class LoginHandlers implements AuthenticationSuccessHandler, AuthenticationFailureHandler,
        AuthenticationEntryPoint {

    private static final Logger log = LoggerFactory.getLogger(LoginHandlers.class);

    static final ApiProblem BAD_CREDENTIALS =
            ApiProblem.of(401, "Correo o contraseña incorrectos", "BAD_CREDENTIALS");
    static final ApiProblem USER_DISABLED =
            ApiProblem.of(401, "Usuario desactivado", "USER_DISABLED");
    static final ApiProblem UNAUTHENTICATED =
            ApiProblem.of(401, "No hay una sesión iniciada", "UNAUTHENTICATED");
    static final ApiProblem INTERNAL_ERROR =
            ApiProblem.of(500, "Error interno", "INTERNAL_ERROR");

    private final LastLoginService lastLogin;
    private final ApiProblemWriter problems;

    public LoginHandlers(LastLoginService lastLogin, ApiProblemWriter problems) {
        this.lastLogin = lastLogin;
        this.problems = problems;
    }

    /** Ingreso válido: registra el último ingreso y responde 204 con la cookie de sesión. */
    @Override
    public void onAuthenticationSuccess(HttpServletRequest request, HttpServletResponse response,
                                        Authentication authentication) {
        AuthenticatedUser user = (AuthenticatedUser) authentication.getPrincipal();
        lastLogin.recordLogin(user.getId());

        // Al entrar, Spring Security descarta el token CSRF anterior. Pedir el nuevo
        // hace que vuelva en la cookie XSRF-TOKEN de esta misma respuesta.
        CsrfToken csrf = (CsrfToken) request.getAttribute(CsrfToken.class.getName());
        if (csrf != null) {
            csrf.getToken();
        }

        response.setStatus(HttpStatus.NO_CONTENT.value());
    }

    /**
     * Ingreso fallido. "Desactivado" solo llega acá si la contraseña era correcta:
     * con una contraseña incorrecta el resultado es siempre BAD_CREDENTIALS.
     */
    @Override
    public void onAuthenticationFailure(HttpServletRequest request, HttpServletResponse response,
                                        AuthenticationException exception) throws IOException {
        if (exception instanceof InternalAuthenticationServiceException) {
            log.error("Error al intentar el ingreso", exception);
            problems.write(response, INTERNAL_ERROR);
        } else if (exception instanceof DisabledException) {
            problems.write(response, USER_DISABLED);
        } else {
            problems.write(response, BAD_CREDENTIALS);
        }
    }

    /** Pedido a la API sin sesión iniciada. */
    @Override
    public void commence(HttpServletRequest request, HttpServletResponse response,
                         AuthenticationException authException) throws IOException {
        problems.write(response, UNAUTHENTICATED);
    }
}
