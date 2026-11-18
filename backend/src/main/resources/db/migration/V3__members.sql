-- =====================================================================
--  V3 - Socios
--
--  Categorías, grupos familiares, socios, responsables y las dos
--  bitácoras de cambios. Depende de V2 (people, users, accounts).
-- =====================================================================


-- ---------------------------------------------------------------------
--  member_categories
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
-- ---------------------------------------------------------------------
CREATE TABLE family_groups (
  id          INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name        VARCHAR(80)  NOT NULL,
  is_active   BOOLEAN      NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX ix_fg_name ON family_groups (name);


-- ---------------------------------------------------------------------
--  members
-- ---------------------------------------------------------------------
CREATE TABLE members (
  id                    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  person_id             INT           NOT NULL,
  member_number         VARCHAR(20)   NOT NULL,
  member_category_id    INT           NOT NULL,
  category_overridden   BOOLEAN       NOT NULL DEFAULT false,
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

-- Parcial porque la mayoría de los socios no tiene token.
CREATE UNIQUE INDEX ux_members_card_token
  ON members (card_token)
  WHERE card_token IS NOT NULL;

CREATE INDEX ix_members_status ON members (status);

CREATE INDEX ix_members_category ON members (member_category_id);

CREATE INDEX ix_members_family_group
  ON members (family_group_id)
  WHERE family_group_id IS NOT NULL;


-- ---------------------------------------------------------------------
--  member_guardians
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

CREATE INDEX ix_mg_guardian ON member_guardians (guardian_person_id);

-- Un solo responsable principal por socio.
CREATE UNIQUE INDEX ux_mg_primary
  ON member_guardians (member_id)
  WHERE is_primary = true;


-- ---------------------------------------------------------------------
--  member_status_changes
--  status = el estado AL QUE paso.
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

-- "El último cambio de este socio": descendente para no ordenar.
CREATE INDEX ix_msc_member ON member_status_changes (member_id, created_at DESC);

CREATE INDEX ix_msc_date ON member_status_changes (created_at);


-- ---------------------------------------------------------------------
--  member_category_changes
--  Misma forma y reglas que member_status_changes. Tabla propia y no
--  una genérica de cambios: asi la categoria conserva su foránea real.
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
