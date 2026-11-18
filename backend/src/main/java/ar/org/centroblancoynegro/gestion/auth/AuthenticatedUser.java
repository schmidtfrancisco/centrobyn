package ar.org.centroblancoynegro.gestion.auth;

import ar.org.centroblancoynegro.gestion.users.UserRole;
import org.springframework.security.core.CredentialsContainer;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.util.Collection;
import java.util.List;
import java.util.Set;

/**
 * Usuario con la sesión iniciada. Es lo que queda guardado en la sesión
 * (en la memoria del backend), así que solo lleva datos simples.
 *
 * <p>Cada rol se publica como la autoridad {@code ROLE_<rol>}, para poder
 * usar {@code hasRole("ADMIN")}.
 */
public final class AuthenticatedUser implements UserDetails, CredentialsContainer {

    private final Integer id;
    private final String email;
    private final String firstName;
    private final String lastName;
    private final Set<UserRole> roles;
    private final boolean active;
    private String passwordHash;

    public AuthenticatedUser(Integer id, String email, String firstName, String lastName,
                             Set<UserRole> roles, boolean active, String passwordHash) {
        this.id = id;
        this.email = email;
        this.firstName = firstName;
        this.lastName = lastName;
        this.roles = Set.copyOf(roles);
        this.active = active;
        this.passwordHash = passwordHash;
    }

    public Integer getId() {
        return id;
    }

    public String getEmail() {
        return email;
    }

    public String getFirstName() {
        return firstName;
    }

    public String getLastName() {
        return lastName;
    }

    public Set<UserRole> getRoles() {
        return roles;
    }

    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        return roles.stream()
                .map(role -> new SimpleGrantedAuthority("ROLE_" + role.name()))
                .toList();
    }

    @Override
    public String getPassword() {
        return passwordHash;
    }

    @Override
    public String getUsername() {
        return email;
    }

    @Override
    public boolean isEnabled() {
        return active;
    }

    /** Una vez autenticado, el hash no se guarda en la sesión. */
    @Override
    public void eraseCredentials() {
        passwordHash = null;
    }

    /** Roles ordenados como en el enum, para respuestas estables. */
    public List<UserRole> sortedRoles() {
        return roles.stream().sorted().toList();
    }
}
