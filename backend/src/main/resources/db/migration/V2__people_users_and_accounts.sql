-- =====================================================================
--  V2 - Personas, usuarios y plan de cuentas
--
--  Las tablas de las que dependen casi todas las demás: por eso van
--  primero.
-- =====================================================================


-- ---------------------------------------------------------------------
--  people
-- ---------------------------------------------------------------------
CREATE TABLE people (
  id               INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  first_name       VARCHAR(60)   NOT NULL,
  last_name        VARCHAR(60)   NOT NULL,
  document_type    document_type DEFAULT 'DNI',
  document_number  VARCHAR(20),
  birth_date       DATE,
  email            VARCHAR(120),
  phone            VARCHAR(30),
  address          VARCHAR(150),
  photo_url        VARCHAR(255),          -- ruta al archivo, no la imagen
  created_at       TIMESTAMPTZ   NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ   NOT NULL DEFAULT now(),

  CONSTRAINT ck_people_birth_date
    CHECK (birth_date IS NULL OR birth_date <= CURRENT_DATE)
);

-- La unicidad es del par tipo + número, no del número solo.
-- Parcial porque el documento es opcional a nivel persona.
CREATE UNIQUE INDEX ux_people_document
  ON people (document_type, document_number)
  WHERE document_number IS NOT NULL;

CREATE INDEX ix_people_name ON people (last_name, first_name);


-- ---------------------------------------------------------------------
--  users
-- ---------------------------------------------------------------------
CREATE TABLE users (
  id                      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  person_id               INT          NOT NULL,
  email                   VARCHAR(120) NOT NULL,
  password_hash           VARCHAR(120),
  is_active               BOOLEAN      NOT NULL DEFAULT true,
  last_login_at           TIMESTAMPTZ,
  password_token          VARCHAR(100),
  password_token_expires  TIMESTAMPTZ,
  failed_login_attempts   SMALLINT     NOT NULL DEFAULT 0,
  locked_until            TIMESTAMPTZ,
  created_at              TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at              TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT ux_users_person UNIQUE (person_id),
  CONSTRAINT fk_users_person FOREIGN KEY (person_id) REFERENCES people (id),

  -- El token y su vencimiento existen juntos o no existen.
  CONSTRAINT ck_users_password_token
    CHECK ((password_token IS NULL) = (password_token_expires IS NULL))
);

-- Único sin distinguir mayúsculas.
CREATE UNIQUE INDEX ux_users_email ON users (lower(email));

CREATE UNIQUE INDEX ux_users_password_token
  ON users (password_token)
  WHERE password_token IS NOT NULL;


-- ---------------------------------------------------------------------
--  user_roles
--  El único (user_id, role) también sirve para buscar por usuario,
--  porque user_id es su primera columna.
-- ---------------------------------------------------------------------
CREATE TABLE user_roles (
  id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id  INT       NOT NULL,
  role     user_role NOT NULL,

  CONSTRAINT ux_user_roles_user_role UNIQUE (user_id, role),
  CONSTRAINT fk_user_roles_user FOREIGN KEY (user_id) REFERENCES users (id)
);


-- ---------------------------------------------------------------------
--  accounts
--  Árbol de profundidad variable
--  (parent_id recursivo). Formato de number_code: 1.1.1.01.001
-- ---------------------------------------------------------------------
CREATE TABLE accounts (
  id            INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  parent_id     INT,
  code          VARCHAR(20),               -- abreviatura: SYJ, FMA, CS
  number_code   VARCHAR(20)  NOT NULL,     -- 1.1.1.01.001
  name          VARCHAR(80)  NOT NULL,
  account_type  account_type,
  is_postable   BOOLEAN      NOT NULL DEFAULT true,
  is_active     BOOLEAN      NOT NULL DEFAULT true,
  created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT ux_accounts_code        UNIQUE (code),
  CONSTRAINT ux_accounts_number_code UNIQUE (number_code),
  CONSTRAINT fk_accounts_parent FOREIGN KEY (parent_id) REFERENCES accounts (id),

  CONSTRAINT ck_accounts_not_self_parent
    CHECK (parent_id IS NULL OR parent_id <> id)
);

-- Armado del árbol: los hijos de cada nodo.
CREATE INDEX ix_accounts_parent ON accounts (parent_id);

CREATE INDEX ix_accounts_postable
  ON accounts (account_type)
  WHERE is_postable AND is_active;


-- ---------------------------------------------------------------------
--  accounting_periods
--  Tabla de control, no de clasificación: nadie la referencia.
-- ---------------------------------------------------------------------
CREATE TABLE accounting_periods (
  id                 INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  year               SMALLINT     NOT NULL,
  month              SMALLINT     NOT NULL,
  is_closed          BOOLEAN      NOT NULL DEFAULT false,
  closed_at          TIMESTAMPTZ,
  closed_by_user_id  INT,
  notes              VARCHAR(200),

  CONSTRAINT ux_ap_year_month UNIQUE (year, month),
  CONSTRAINT fk_ap_closed_by FOREIGN KEY (closed_by_user_id) REFERENCES users (id),

  CONSTRAINT ck_ap_month  CHECK (month BETWEEN 1 AND 12),
  CONSTRAINT ck_ap_year   CHECK (year BETWEEN 2000 AND 2100),
  CONSTRAINT ck_ap_closed CHECK ((is_closed = true) = (closed_at IS NOT NULL))
);
