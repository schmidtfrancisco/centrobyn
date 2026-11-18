package ar.org.centroblancoynegro.gestion.users;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Integer> {

    /**
     * Busca por correo sin distinguir mayúsculas, con la persona y los roles.
     * Usa el índice único sobre {@code lower(email)}.
     *
     * @param normalizedEmail el correo ya en minúsculas y sin espacios alrededor
     */
    @Query("""
            select u from User u
            join fetch u.person
            left join fetch u.roles
            where lower(u.email) = :email
            """)
    Optional<User> findForLogin(@Param("email") String normalizedEmail);

    @Modifying
    @Query("update User u set u.lastLoginAt = :at where u.id = :id")
    int updateLastLoginAt(@Param("id") Integer id, @Param("at") Instant at);
}
