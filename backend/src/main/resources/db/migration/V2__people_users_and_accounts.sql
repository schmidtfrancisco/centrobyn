-- =====================================================================
--  V2 - Personas, usuarios y plan de cuentas
--
--  Las tablas de las que dependen casi todas las demas: por eso van
--  primero. Ver Decisiones en Notion para el por que de cada una.
-- =====================================================================


-- ---------------------------------------------------------------------
--  people
--  Cualquier ser humano que el club necesite nombrar. Los roles
--  (members, teachers, users, collectors, third_parties) cuelgan de aca.
--  Sin is_active: se da de baja el rol, no la persona.
--  email es contacto, no credencial: puede repetirse (una madre en las
--  fichas de sus hijos). La credencial unica vive en users.
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

-- La unicidad es del par tipo + numero, no del numero solo.
-- Parcial porque el documento es opcional a nivel persona.
CREATE UNIQUE INDEX ux_people_document
  ON people (document_type, document_number)
  WHERE document_number IS NOT NULL;

-- Busqueda de la secretaria por apellido.
CREATE INDEX ix_people_name ON people (last_name, first_name);


-- ---------------------------------------------------------------------
--  users
--  Acceso al sistema. Rol sobre people: el portero y el contador no
--  son socios.
--  password_hash admite nulo a proposito: el usuario se da de alta y
--  define su contrasenia desde un link (password_token).
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

-- El mail es la credencial: unico sin distinguir mayusculas.
CREATE UNIQUE INDEX ux_users_email ON users (lower(email));

CREATE UNIQUE INDEX ux_users_password_token
  ON users (password_token)
  WHERE password_token IS NOT NULL;


-- ---------------------------------------------------------------------
--  user_roles
--  Una persona puede tener varios roles (profesor y socio a la vez).
--  El unico (user_id, role) tambien sirve para buscar por usuario,
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
--  El plan de cuentas del contador. Arbol de profundidad variable
--  (parent_id recursivo). Formato de number_code: 1.1.1.01.001
--  account_type se guarda, no se deduce: en este plan "4." contiene
--  recursos y gastos. Nulo en los titulos mixtos.
--  is_postable distingue imputables de titulos.
--  Ninguna logica depende del nombre: tiene errores de tipeo.
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

-- Armado del arbol: los hijos de cada nodo.
CREATE INDEX ix_accounts_parent ON accounts (parent_id);

-- El desplegable al cargar un movimiento: solo imputables y activas.
CREATE INDEX ix_accounts_postable
  ON accounts (account_type)
  WHERE is_postable AND is_active;


-- ---------------------------------------------------------------------
--  accounting_periods
--  Tabla de control, no de clasificacion: nadie la referencia. Se
--  consulta por (year, month) para saber si un mes admite escrituras.
--  Fila inexistente = periodo abierto.
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
