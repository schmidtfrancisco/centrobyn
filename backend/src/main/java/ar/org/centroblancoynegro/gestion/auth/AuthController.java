package ar.org.centroblancoynegro.gestion.auth;

import ar.org.centroblancoynegro.gestion.users.UserRole;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * Datos del usuario con la sesión iniciada.
 *
 * <p>{@code POST /api/auth/login} no está acá: lo atiende el filtro de
 * Spring Security configurado en {@code SecurityConfig}.
 */
@RestController
@RequestMapping("/api/auth")
public class AuthController {

    public record MeResponse(Integer id, String email, String firstName, String lastName,
                             List<UserRole> roles) {
    }

    @GetMapping("/me")
    public MeResponse me(@AuthenticationPrincipal AuthenticatedUser user) {
        return new MeResponse(user.getId(), user.getEmail(), user.getFirstName(),
                user.getLastName(), user.sortedRoles());
    }
}
