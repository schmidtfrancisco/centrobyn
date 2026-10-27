-- Se ejecuta UNA sola vez: cuando el volumen esta vacio y Postgres se inicializa.
-- Crea la base aislada para los tests. Copia la configuracion de template1,
-- asi que hereda el orden ICU es-AR. Su duena es POSTGRES_USER.
CREATE DATABASE club_test;
 