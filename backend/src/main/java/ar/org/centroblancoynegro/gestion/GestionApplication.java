package ar.org.centroblancoynegro.gestion;

import ar.org.centroblancoynegro.gestion.config.ClockConfig;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

import java.util.TimeZone;

@SpringBootApplication
public class GestionApplication {

	public static void main(String[] args) {
		TimeZone.setDefault(TimeZone.getTimeZone(ClockConfig.CLUB_ZONE));
		SpringApplication.run(GestionApplication.class, args);
	}

}
