package ar.org.centroblancoynegro.gestion.web;

import com.fasterxml.jackson.annotation.JsonInclude;

import java.util.Map;

/**
 * Cuerpo de error según Problem Details (RFC 9457), con el formato del
 * contrato: {@code status}, {@code title}, {@code code} y, solo cuando
 * corresponde, {@code details}.
 *
 * @param status  igual al código HTTP
 * @param title   descripción corta del tipo de error
 * @param code    identificador en MAYÚSCULAS
 * @param details datos adicionales; se omite si es {@code null}
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public record ApiProblem(int status, String title, String code, Map<String, Object> details) {

    public static final String MEDIA_TYPE = "application/problem+json";

    public static ApiProblem of(int status, String title, String code) {
        return new ApiProblem(status, title, code, null);
    }
}
