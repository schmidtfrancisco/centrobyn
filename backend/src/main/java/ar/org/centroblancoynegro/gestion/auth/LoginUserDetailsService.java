package ar.org.centroblancoynegro.gestion.auth;

import ar.org.centroblancoynegro.gestion.users.User;
import ar.org.centroblancoynegro.gestion.users.UserRepository;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Locale;

/**
 * Busca al usuario que intenta entrar.
 *
 * <p>Un correo inexistente y una cuenta sin activar (sin contraseña) se
 * tratan igual: los dos lanzan {@link UsernameNotFoundException}. Ante esa
 * excepción, {@code DaoAuthenticationProvider} compara la contraseña contra
 * un hash de relleno, así el tiempo de respuesta no delata qué correos existen,
 * y la convierte en "credenciales incorrectas".
 */
@Service
public class LoginUserDetailsService implements UserDetailsService {

    private final UserRepository users;

    public LoginUserDetailsService(UserRepository users) {
        this.users = users;
    }

    /** El correo se compara en minúsculas y sin espacios alrededor. */
    public static String normalizeEmail(String email) {
        return email == null ? "" : email.strip().toLowerCase(Locale.ROOT);
    }

    @Override
    @Transactional(readOnly = true)
    public AuthenticatedUser loadUserByUsername(String email) {
        User user = users.findForLogin(normalizeEmail(email))
                .filter(u -> u.getPasswordHash() != null)
                .orElseThrow(() -> new UsernameNotFoundException("Usuario inexistente o sin activar"));

        return new AuthenticatedUser(
                user.getId(),
                user.getEmail(),
                user.getPerson().getFirstName(),
                user.getPerson().getLastName(),
                user.getRoles(),
                user.isActive(),
                user.getPasswordHash());
    }
}
