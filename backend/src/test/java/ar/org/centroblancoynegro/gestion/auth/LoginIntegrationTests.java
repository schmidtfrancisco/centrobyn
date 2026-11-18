package ar.org.centroblancoynegro.gestion.auth;

import jakarta.servlet.http.Cookie;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockHttpSession;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.transaction.annotation.Transactional;

import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.cookie;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * US-91: iniciar sesión. Corre contra la base de tests; cada test se deshace
 * al terminar.
 */
@SpringBootTest
@AutoConfigureMockMvc
@Transactional
class LoginIntegrationTests {

    private static final Instant NOW = Instant.parse("2026-03-10T15:30:00Z");
    private static final String PASSWORD = "Socio2026";

    @TestConfiguration
    static class FixedClock {
        @Bean
        @Primary
        Clock fixedClock() {
            return Clock.fixed(NOW, ZoneOffset.UTC);
        }
    }

    @Autowired
    MockMvc mvc;

    @Autowired
    JdbcTemplate jdbc;

    @Autowired
    PasswordEncoder passwordEncoder;

    private int anaId;
    private int jorgeId;

    @BeforeEach
    void createUsers() {
        anaId = createUser("Ana", "Pérez", "ana.perez@gmail.com", passwordEncoder.encode(PASSWORD), true);
        addRole(anaId, "STAFF");
        addRole(anaId, "MEMBER");
        jorgeId = createUser("Jorge", "Díaz", "jorge.diaz@gmail.com", passwordEncoder.encode(PASSWORD), false);
        createUser("Laura", "Gómez", "laura.gomez@gmail.com", null, true);
    }

    // ---- Entrar ----------------------------------------------------------

    @Test
    void validLogin_startsSession_andMeReturnsTheUser() throws Exception {
        MockHttpSession session = sessionOf(login("ana.perez@gmail.com", PASSWORD));
        assertThat(session).isNotNull();

        mvc.perform(get("/api/auth/me").session(session))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(anaId))
                .andExpect(jsonPath("$.email").value("ana.perez@gmail.com"))
                .andExpect(jsonPath("$.firstName").value("Ana"))
                .andExpect(jsonPath("$.lastName").value("Pérez"))
                .andExpect(jsonPath("$.roles[0]").value("STAFF"))
                .andExpect(jsonPath("$.roles[1]").value("MEMBER"))
                .andExpect(jsonPath("$.roles.length()").value(2));
    }

    @Test
    void emailWithOtherCaseAndSurroundingSpaces_logsIn() throws Exception {
        login("  Ana.Perez@Gmail.com ", PASSWORD).andExpect(status().isNoContent());
    }

    @Test
    void validLogin_recordsLastLogin() throws Exception {
        login("ana.perez@gmail.com", PASSWORD).andExpect(status().isNoContent());

        assertThat(lastLoginAt(anaId)).isEqualTo(NOW);
    }

    @Test
    void validLogin_generatesANewSessionId() throws Exception {
        MockHttpSession before = new MockHttpSession();
        String idBefore = before.getId();

        MvcResult result = mvc.perform(loginRequest("ana.perez@gmail.com", PASSWORD)
                        .session(before)
                        // Como un contenedor real: la cookie apunta a una sesión que existe.
                        .with(request -> {
                            request.setRequestedSessionId(idBefore);
                            request.setRequestedSessionIdValid(true);
                            return request;
                        }))
                .andExpect(status().isNoContent())
                .andReturn();

        assertThat(result.getRequest().getSession(false).getId()).isNotEqualTo(idBefore);
    }

    @Test
    void secondLoginOfTheSameUser_keepsBothSessionsOpen() throws Exception {
        MockHttpSession computer = sessionOf(login("ana.perez@gmail.com", PASSWORD));
        MockHttpSession phone = sessionOf(login("ana.perez@gmail.com", PASSWORD));

        assertThat(computer.getId()).isNotEqualTo(phone.getId());
        mvc.perform(get("/api/auth/me").session(computer)).andExpect(status().isOk());
        mvc.perform(get("/api/auth/me").session(phone)).andExpect(status().isOk());
    }

    @Test
    void validLogin_sendsANewCsrfCookie() throws Exception {
        login("ana.perez@gmail.com", PASSWORD)
                .andExpect(status().isNoContent())
                .andExpect(cookie().exists("XSRF-TOKEN"));
    }

    // ---- Cuando no entra -------------------------------------------------

    @Test
    void wrongPassword_isBadCredentials() throws Exception {
        expectBadCredentials(login("ana.perez@gmail.com", "otra"));
    }

    @Test
    void passwordIsNeverTrimmed() throws Exception {
        expectBadCredentials(login("ana.perez@gmail.com", PASSWORD + " "));
    }

    @Test
    void unknownEmail_isBadCredentials() throws Exception {
        expectBadCredentials(login("nadie@gmail.com", PASSWORD));
    }

    @Test
    void accountNotActivated_isBadCredentials() throws Exception {
        expectBadCredentials(login("laura.gomez@gmail.com", PASSWORD));
        expectBadCredentials(login("laura.gomez@gmail.com", ""));
    }

    @Test
    void disabledUserWithCorrectPassword_isUserDisabled() throws Exception {
        login("jorge.diaz@gmail.com", PASSWORD)
                .andExpect(status().isUnauthorized())
                .andExpect(content().contentTypeCompatibleWith("application/problem+json"))
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.code").value("USER_DISABLED"))
                .andExpect(jsonPath("$.title").isString())
                .andExpect(jsonPath("$.details").doesNotExist());
        assertThat(lastLoginAt(jorgeId)).isNull();
    }

    @Test
    void disabledUserWithWrongPassword_isBadCredentials() throws Exception {
        expectBadCredentials(login("jorge.diaz@gmail.com", "otra"));
    }

    @Test
    void emptyFields_areBadCredentials() throws Exception {
        expectBadCredentials(login("", PASSWORD));
        expectBadCredentials(login("ana.perez@gmail.com", ""));
    }

    @Test
    void loginWithWrongCsrfToken_isRejected() throws Exception {
        Cookie xsrf = mvc.perform(get("/api/auth/me")).andReturn().getResponse().getCookie("XSRF-TOKEN");
        mvc.perform(post("/api/auth/login")
                        .cookie(xsrf)
                        .header("X-XSRF-TOKEN", "otro-token")
                        .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                        .param("email", "ana.perez@gmail.com")
                        .param("password", PASSWORD))
                .andExpect(status().isForbidden());
    }

    @Test
    void loginWithoutCsrfToken_isRejected() throws Exception {
        mvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                        .param("email", "ana.perez@gmail.com")
                        .param("password", PASSWORD))
                .andExpect(status().isForbidden());
    }

    // ---- Lo que no toca --------------------------------------------------

    @Test
    void failedAttempt_doesNotChangeLastLogin() throws Exception {
        Instant previous = Instant.parse("2026-01-02T10:00:00Z");
        jdbc.update("UPDATE users SET last_login_at = ? WHERE id = ?", Timestamp.from(previous), anaId);

        login("ana.perez@gmail.com", "otra").andExpect(status().isUnauthorized());

        assertThat(lastLoginAt(anaId)).isEqualTo(previous);
    }

    @Test
    void failedAttempt_doesNotTouchLockoutColumns() throws Exception {
        login("ana.perez@gmail.com", "otra").andExpect(status().isUnauthorized());

        assertThat(jdbc.queryForObject(
                "SELECT failed_login_attempts FROM users WHERE id = ?", Integer.class, anaId)).isZero();
        assertThat(jdbc.queryForObject(
                "SELECT locked_until FROM users WHERE id = ?", Timestamp.class, anaId)).isNull();
    }

    // ---- GET /api/auth/me ------------------------------------------------

    @Test
    void meWithoutSession_isUnauthenticated_andSendsCsrfCookie() throws Exception {
        mvc.perform(get("/api/auth/me"))
                .andExpect(status().isUnauthorized())
                .andExpect(content().contentTypeCompatibleWith("application/problem+json"))
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.code").value("UNAUTHENTICATED"))
                .andExpect(jsonPath("$.details").doesNotExist())
                .andExpect(cookie().exists("XSRF-TOKEN"))
                .andExpect(cookie().httpOnly("XSRF-TOKEN", false));
    }

    // ---- Ayudas ----------------------------------------------------------

    /**
     * Como Angular: pide la cookie XSRF-TOKEN y reenvía su valor en el encabezado
     * X-XSRF-TOKEN. (No se usa {@code csrf()} de spring-security-test porque
     * reemplaza el repositorio de tokens para todo el contexto.)
     */
    private MockHttpServletRequestBuilder loginRequest(String email, String password) throws Exception {
        Cookie xsrf = mvc.perform(get("/api/auth/me")).andReturn().getResponse().getCookie("XSRF-TOKEN");
        assertThat(xsrf).isNotNull();
        return post("/api/auth/login")
                .cookie(xsrf)
                .header("X-XSRF-TOKEN", xsrf.getValue())
                .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                .param("email", email)
                .param("password", password);
    }

    private ResultActions login(String email, String password) throws Exception {
        return mvc.perform(loginRequest(email, password));
    }

    private MockHttpSession sessionOf(ResultActions result) throws Exception {
        return (MockHttpSession) result.andExpect(status().isNoContent())
                .andReturn().getRequest().getSession(false);
    }

    private void expectBadCredentials(ResultActions result) throws Exception {
        result.andExpect(status().isUnauthorized())
                .andExpect(content().contentTypeCompatibleWith("application/problem+json"))
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.title").value("Correo o contraseña incorrectos"))
                .andExpect(jsonPath("$.code").value("BAD_CREDENTIALS"))
                .andExpect(jsonPath("$.details").doesNotExist());
    }

    private int createUser(String firstName, String lastName, String email, String passwordHash, boolean active) {
        Integer personId = jdbc.queryForObject(
                "INSERT INTO people (first_name, last_name) VALUES (?, ?) RETURNING id",
                Integer.class, firstName, lastName);
        return jdbc.queryForObject(
                "INSERT INTO users (person_id, email, password_hash, is_active) VALUES (?, ?, ?, ?) RETURNING id",
                Integer.class, personId, email, passwordHash, active);
    }

    private void addRole(int userId, String role) {
        jdbc.update("INSERT INTO user_roles (user_id, role) VALUES (?, ?::user_role)", userId, role);
    }

    private Instant lastLoginAt(int userId) {
        Timestamp at = jdbc.queryForObject("SELECT last_login_at FROM users WHERE id = ?", Timestamp.class, userId);
        return at == null ? null : at.toInstant();
    }
}
