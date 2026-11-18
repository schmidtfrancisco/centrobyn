package ar.org.centroblancoynegro.gestion.web;

import jakarta.servlet.http.HttpServletResponse;
import org.springframework.stereotype.Component;
import tools.jackson.databind.json.JsonMapper;

import java.io.IOException;
import java.nio.charset.StandardCharsets;

/**
 * Escribe un {@link ApiProblem} directamente en la respuesta. Lo usan los
 * filtros de seguridad, que responden antes de llegar a un controlador.
 */
@Component
public class ApiProblemWriter {

    private final JsonMapper jsonMapper;

    public ApiProblemWriter(JsonMapper jsonMapper) {
        this.jsonMapper = jsonMapper;
    }

    public void write(HttpServletResponse response, ApiProblem problem) throws IOException {
        response.setStatus(problem.status());
        response.setContentType(ApiProblem.MEDIA_TYPE);
        response.setCharacterEncoding(StandardCharsets.UTF_8.name());
        jsonMapper.writeValue(response.getOutputStream(), problem);
    }
}
