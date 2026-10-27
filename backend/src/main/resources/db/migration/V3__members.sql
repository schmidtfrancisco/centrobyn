-- =====================================================================
--  V3 - Socios
--
--  Categorias, grupos familiares, socios, responsables y las dos
--  bitacoras de cambios. Depende de V2 (people, users, accounts).
-- =====================================================================


-- ---------------------------------------------------------------------
--  member_categories
--  Que clase de socio es. Tabla de referencia: pocas filas, las carga
--  el administrador. NO guarda precio: el precio vive en el catalogo de
--  conceptos, con vigencia.
--  min_age / max_age son la regla de SUGERENCIA por edad; la verdad es
--  members.member_category_id. Los dos nulos = no se sugiere por edad.
--  charges_enrollment: si los socios de esta categoria pagan
--  inscripcion al darse de alta.
--  income_account_id nullable a proposito: se verifica al generar
--  cargos, no al crear la categoria.
--  code nullable a proposito.
-- ---------------------------------------------------------------------
CREATE TABLE member_categories (
  id                  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  code                VARCHAR(20),
  name                VARCHAR(60)  NOT NULL,
  description         TEXT,
  min_age             INT,
  max_age             INT,
  charges_enrollment  BOOLEAN      NOT NULL DEFAULT false,
  is_active           BOOLEAN      NOT NULL DEFAULT true,
  income_account_id   INT,
  created_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT ux_mc_code UNIQUE (code),
  CONSTRAINT fk_mc_income_account FOREIGN KEY (income_account_id) REFERENCES accounts (id),

  CONSTRAINT ck_mc_ages
    CHECK (min_age IS NULL OR max_age IS NULL OR max_age >= min_age),
  CONSTRAINT ck_mc_ages_range
    CHECK ((min_age IS NULL OR min_age BETWEEN 0 AND 120)
       AND (max_age IS NULL OR max_age BETWEEN 0 AND 120))
);


-- ---------------------------------------------------------------------
--  family_groups
--  Agrupa socios que se pueden cobrar juntos. Existe SOLO para eso: no
--  define precios, descuentos ni responsabilidad legal (eso lo dice
--  member_guardians). Habilita juntar, no obliga.
--  El nombre puede repetirse a proposito.
-- ---------------------------------------------------------------------
CREATE TABLE family_groups (
  id          INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name        VARCHAR(80)  NOT NULL,
  is_active   BOOLEAN      NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- Busqueda al armar un recibo. Sin unique: dos "Familia Sanchez" son
-- dos familias distintas.
CREATE INDEX ix_fg_name ON family_groups (name);


-- ---------------------------------------------------------------------
--  members
--  Rol de socio sobre una persona. No repite datos personales.
--  status + left_on es una desnormalizacion deliberada junto con
--  member_status_changes: se escriben siempre en la misma transaccion.
--  joined_on SIN default: al migrar socios existentes, un default de
--  hoy borraria la antiguedad sin dejar rastro.
--  member_number es identidad publica, distinta del id. Se puede
--  corregir.
--  card_token nulo = el socio nunca pidio el carnet digital.
--  family_group_id nulo = socio suelto.
-- ---------------------------------------------------------------------
CREATE TABLE members (
  id                    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  person_id             INT           NOT NULL,
  member_number         VARCHAR(20)   NOT NULL,
  member_category_id    INT           NOT NULL,
  category_overridden   BOOLEAN       NOT NULL DEFAULT false,  -- no reclasificar por edad
  status                member_status NOT NULL,
  joined_on             DATE          NOT NULL,
  left_on               DATE,
  family_group_id       INT,
  card_token            UUID,
  card_token_issued_at  TIMESTAMPTZ,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT now(),

  CONSTRAINT ux_members_person UNIQUE (person_id),
  CONSTRAINT ux_members_number UNIQUE (member_number),
  CONSTRAINT fk_members_person       FOREIGN KEY (person_id)          REFERENCES people (id),
  CONSTRAINT fk_members_category     FOREIGN KEY (member_category_id) REFERENCES member_categories (id),
  CONSTRAINT fk_members_family_group FOREIGN KEY (family_group_id)    REFERENCES family_groups (id),

  CONSTRAINT ck_members_dates
    CHECK (left_on IS NULL OR left_on >= joined_on),
  -- Inactivo y fecha de baja se implican mutuamente.
  CONSTRAINT ck_members_inactive_left
    CHECK ((status = 'INACTIVE') = (left_on IS NOT NULL)),
  CONSTRAINT ck_members_token
    CHECK ((card_token IS NULL) = (card_token_issued_at IS NULL))
);

-- El indice mas caliente del sistema: cada escaneo del carnet en la
-- puerta. Parcial porque la mayoria de los socios no tiene token.
CREATE UNIQUE INDEX ux_members_card_token
  ON members (card_token)
  WHERE card_token IS NOT NULL;

-- Lo recorre el proceso de generacion mensual.
CREATE INDEX ix_members_status ON members (status);

CREATE INDEX ix_members_category ON members (member_category_id);

-- "Los socios de este grupo": armado del recibo y sugerencia al cobrar.
CREATE INDEX ix_members_family_group
  ON members (family_group_id)
  WHERE family_group_id IS NOT NULL;


-- ---------------------------------------------------------------------
--  member_guardians
--  Adulto responsable de un socio menor. Es una relacion, no un texto:
--  un chico puede tener madre y padre, una madre varios hijos.
--  Hace tres trabajos: a quien llamar, a quien reclamar la deuda, y
--  quien puede ver el carnet.
--  relationship es texto libre a proposito: el codigo no ramifica
--  segun el valor.
--  Sin fecha de fin: cuando el socio cumple 18 se borra la fila.
-- ---------------------------------------------------------------------
CREATE TABLE member_guardians (
  id                  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  member_id           INT          NOT NULL,
  guardian_person_id  INT          NOT NULL,
  relationship        VARCHAR(30),               -- madre, padre, tutor, abuela...
  is_primary          BOOLEAN      NOT NULL DEFAULT false,
  created_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT ux_mg_member_guardian UNIQUE (member_id, guardian_person_id),
  CONSTRAINT fk_mg_member   FOREIGN KEY (member_id)          REFERENCES members (id),
  CONSTRAINT fk_mg_guardian FOREIGN KEY (guardian_person_id) REFERENCES people (id)
);

-- Sostiene el login del responsable: "de que socios es responsable
-- esta persona".
CREATE INDEX ix_mg_guardian ON member_guardians (guardian_person_id);

-- Un solo responsable principal por socio.
CREATE UNIQUE INDEX ux_mg_primary
  ON member_guardians (member_id)
  WHERE is_primary = true;


-- ---------------------------------------------------------------------
--  member_status_changes
--  Bitacora: solo INSERT, nunca UPDATE ni DELETE.
--  status = el estado AL QUE paso.
--  Sin changed_on: el estado del socio es lo que dice el sistema, no
--  hay un estado real afuera esperando ser registrado. Una baja
--  retroactiva se expresa en members.left_on. Con created_at por
--  default la fecha no se puede falsear desde la aplicacion.
--  changed_by_user_id nulo = lo hizo un proceso automatico.
-- ---------------------------------------------------------------------
CREATE TABLE member_status_changes (
  id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  member_id           INT            NOT NULL,
  status              member_status  NOT NULL,
  reason              VARCHAR(200),
  changed_by_user_id  INT,
  created_at          TIMESTAMPTZ    NOT NULL DEFAULT now(),

  CONSTRAINT fk_msc_member     FOREIGN KEY (member_id)          REFERENCES members (id),
  CONSTRAINT fk_msc_changed_by FOREIGN KEY (changed_by_user_id) REFERENCES users (id)
);

-- "El ultimo cambio de este socio": descendente para no ordenar.
CREATE INDEX ix_msc_member ON member_status_changes (member_id, created_at DESC);

-- Informes agregados: bajas en un periodo.
CREATE INDEX ix_msc_date ON member_status_changes (created_at);


-- ---------------------------------------------------------------------
--  member_category_changes
--  Misma forma y reglas que member_status_changes. Tabla propia y no
--  una generica de cambios: asi la categoria conserva su foranea real.
-- ---------------------------------------------------------------------
CREATE TABLE member_category_changes (
  id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  member_id           INT          NOT NULL,
  member_category_id  INT          NOT NULL,     -- la categoria a la que paso
  reason              VARCHAR(200),
  changed_by_user_id  INT,
  created_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT fk_mcc_member     FOREIGN KEY (member_id)          REFERENCES members (id),
  CONSTRAINT fk_mcc_category   FOREIGN KEY (member_category_id) REFERENCES member_categories (id),
  CONSTRAINT fk_mcc_changed_by FOREIGN KEY (changed_by_user_id) REFERENCES users (id)
);

CREATE INDEX ix_mcc_member ON member_category_changes (member_id, created_at DESC);

CREATE INDEX ix_mcc_date ON member_category_changes (created_at);
