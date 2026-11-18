package ar.org.centroblancoynegro.gestion.users;

/**
 * Roles de usuario. Coincide con el enum {@code user_role} de la base,
 * con los mismos nombres y en el mismo orden.
 */
public enum UserRole {
    ADMIN,
    STAFF,
    GATEKEEPER,
    TEACHER,
    MEMBER,
    ACCOUNTANT,
    COLLECTOR
}
