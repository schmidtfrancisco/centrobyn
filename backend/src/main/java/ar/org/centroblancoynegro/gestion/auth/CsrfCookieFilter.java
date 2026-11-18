package ar.org.centroblancoynegro.gestion.auth;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.web.csrf.CsrfToken;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

/**
 * Spring Security genera el token CSRF recién cuando alguien lo pide. Este
 * filtro lo pide en cada pedido, así la cookie XSRF-TOKEN llega siempre
 * al navegador, incluso en un 401 de {@code GET /api/auth/me}. Angular la lee
 * y la reenvía en el encabezado X-XSRF-TOKEN.
 */
public class CsrfCookieFilter extends OncePerRequestFilter {

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                    FilterChain chain) throws ServletException, IOException {
        CsrfToken csrf = (CsrfToken) request.getAttribute(CsrfToken.class.getName());
        if (csrf != null) {
            csrf.getToken();
        }
        chain.doFilter(request, response);
    }
}
