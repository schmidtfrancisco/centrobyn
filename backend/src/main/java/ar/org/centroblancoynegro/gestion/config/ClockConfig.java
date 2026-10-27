package ar.org.centroblancoynegro.gestion.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import java.time.Clock;
import java.time.ZoneId;

/**
 * Reloj unico de la aplicacion.
 *
 * <p>Toda fecha u hora "actual" se obtiene a partir de este bean
 * ({@code LocalDate.now(clock)}, {@code Instant.now(clock)}), nunca con
 * {@code LocalDate.now()} sin argumentos. Asi los tests pueden reemplazarlo
 * por un reloj fijo y las reglas que dependen de la fecha (vencimientos,
 * morosidad, edades) dan siempre el mismo resultado.
 */

@Configuration
public class ClockConfig {
    /** Zona horaria del club. */
    public static final ZoneId CLUB_ZONE = ZoneId.of("America/Argentina/Buenos_Aires");

    @Bean
    public Clock clock() {
        return Clock.system(CLUB_ZONE);
    }
}
