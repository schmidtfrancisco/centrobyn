package ar.org.centroblancoynegro.gestion.auth;

import ar.org.centroblancoynegro.gestion.users.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;

/** Registra la fecha y hora del último ingreso. Solo se llama si el ingreso fue válido. */
@Service
public class LastLoginService {

    private final UserRepository users;
    private final Clock clock;

    public LastLoginService(UserRepository users, Clock clock) {
        this.users = users;
        this.clock = clock;
    }

    @Transactional
    public void recordLogin(Integer userId) {
        users.updateLastLoginAt(userId, Instant.now(clock));
    }
}
