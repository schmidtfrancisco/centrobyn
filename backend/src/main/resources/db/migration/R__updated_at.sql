-- =====================================================================
--  R__updated_at - Mantener updated_at al dia
--
--  Migracion REPETIBLE: Flyway la vuelve a ejecutar cada vez que cambia
--  este archivo, siempre despues de todas las V. Por eso todo lo que
--  hace tiene que poder correr dos veces sin romperse (OR REPLACE,
--  DROP ... IF EXISTS).
--
--  Por que un trigger y no @UpdateTimestamp de Hibernate: updated_at
--  no es una regla de negocio, es auditoria, y su valor esta en que no
--  se pueda saltear. El trigger lo actualiza aunque el cambio venga de
--  un UPDATE a mano en la base, un script de carga o un test.
--
--  AL AGREGAR UNA TABLA CON updated_at: sumarla a la lista de abajo.
--  Si no, la columna va a quedar para siempre con la fecha de alta.
-- =====================================================================


CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Un trigger por tabla. DROP + CREATE en lugar de CREATE OR REPLACE
-- TRIGGER para que funcione tambien en PostgreSQL anterior a la 14.

DROP TRIGGER IF EXISTS tr_people_updated_at ON people;
CREATE TRIGGER tr_people_updated_at
  BEFORE UPDATE ON people
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS tr_users_updated_at ON users;
CREATE TRIGGER tr_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS tr_accounts_updated_at ON accounts;
CREATE TRIGGER tr_accounts_updated_at
  BEFORE UPDATE ON accounts
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS tr_member_categories_updated_at ON member_categories;
CREATE TRIGGER tr_member_categories_updated_at
  BEFORE UPDATE ON member_categories
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS tr_family_groups_updated_at ON family_groups;
CREATE TRIGGER tr_family_groups_updated_at
  BEFORE UPDATE ON family_groups
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS tr_members_updated_at ON members;
CREATE TRIGGER tr_members_updated_at
  BEFORE UPDATE ON members
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS tr_disciplines_updated_at ON disciplines;
CREATE TRIGGER tr_disciplines_updated_at
  BEFORE UPDATE ON disciplines
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS tr_discipline_groups_updated_at ON discipline_groups;
CREATE TRIGGER tr_discipline_groups_updated_at
  BEFORE UPDATE ON discipline_groups
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS tr_teachers_updated_at ON teachers;
CREATE TRIGGER tr_teachers_updated_at
  BEFORE UPDATE ON teachers
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS tr_billable_concepts_updated_at ON billable_concepts;
CREATE TRIGGER tr_billable_concepts_updated_at
  BEFORE UPDATE ON billable_concepts
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS tr_third_parties_updated_at ON third_parties;
CREATE TRIGGER tr_third_parties_updated_at
  BEFORE UPDATE ON third_parties
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS tr_checks_updated_at ON checks;
CREATE TRIGGER tr_checks_updated_at
  BEFORE UPDATE ON checks
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS tr_collectors_updated_at ON collectors;
CREATE TRIGGER tr_collectors_updated_at
  BEFORE UPDATE ON collectors
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS tr_debit_mandates_updated_at ON debit_mandates;
CREATE TRIGGER tr_debit_mandates_updated_at
  BEFORE UPDATE ON debit_mandates
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS tr_club_settings_updated_at ON club_settings;
CREATE TRIGGER tr_club_settings_updated_at
  BEFORE UPDATE ON club_settings
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
