-- =====================================================================
--  V4 - Actividades
--
--  Disciplinas, grupos, meses de cobro, horarios y profesores.
--  Depende de V2 (people, accounts).
--  Las inscripciones (enrollments) van en V5, junto al catalogo de
--  conceptos, porque apuntan a billable_concepts.
-- =====================================================================


-- ---------------------------------------------------------------------
--  disciplines
-- ---------------------------------------------------------------------
CREATE TABLE disciplines (
  id                         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  code                       VARCHAR(20),
  name                       VARCHAR(60)    NOT NULL,
  description                TEXT,
  is_active                  BOOLEAN        NOT NULL DEFAULT true,
  suggested_fee_amount       DECIMAL(12,2),
  default_income_account_id  INT,
  created_at                 TIMESTAMPTZ    NOT NULL DEFAULT now(),
  updated_at                 TIMESTAMPTZ    NOT NULL DEFAULT now(),

  CONSTRAINT ux_disciplines_code UNIQUE (code),
  CONSTRAINT fk_disciplines_income_account
    FOREIGN KEY (default_income_account_id) REFERENCES accounts (id),

  -- Cero es válido.
  CONSTRAINT ck_disciplines_fee
    CHECK (suggested_fee_amount IS NULL OR suggested_fee_amount >= 0)
);


-- ---------------------------------------------------------------------
--  discipline_groups
-- ---------------------------------------------------------------------
CREATE TABLE discipline_groups (
  id                 INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  discipline_id      INT           NOT NULL,
  name               VARCHAR(60)   NOT NULL,
  min_age            SMALLINT,
  max_age            SMALLINT,
  gender             group_gender,
  capacity           SMALLINT,
  is_active          BOOLEAN       NOT NULL DEFAULT true,
  income_account_id  INT,
  created_at         TIMESTAMPTZ   NOT NULL DEFAULT now(),
  updated_at         TIMESTAMPTZ   NOT NULL DEFAULT now(),

  CONSTRAINT ux_dg_name UNIQUE (discipline_id, name),
  CONSTRAINT fk_dg_discipline     FOREIGN KEY (discipline_id)     REFERENCES disciplines (id),
  CONSTRAINT fk_dg_income_account FOREIGN KEY (income_account_id) REFERENCES accounts (id),

  CONSTRAINT ck_dg_ages
    CHECK (min_age IS NULL OR max_age IS NULL OR max_age >= min_age),
  CONSTRAINT ck_dg_capacity
    CHECK (capacity IS NULL OR capacity > 0)
);

-- Los grupos activos de una disciplina.
CREATE INDEX ix_dg_discipline
  ON discipline_groups (discipline_id)
  WHERE is_active;


-- ---------------------------------------------------------------------
--  group_billing_months
-- ---------------------------------------------------------------------
CREATE TABLE group_billing_months (
  id                   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  discipline_group_id  INT       NOT NULL,
  month                SMALLINT  NOT NULL,

  CONSTRAINT ux_gbm_group_month UNIQUE (discipline_group_id, month),
  CONSTRAINT fk_gbm_group FOREIGN KEY (discipline_group_id) REFERENCES discipline_groups (id),

  CONSTRAINT ck_gbm_month CHECK (month BETWEEN 1 AND 12)
);


-- ---------------------------------------------------------------------
--  group_schedules
--  weekday según ISO: 1 = lunes ... 7 = domingo.
-- ---------------------------------------------------------------------
CREATE TABLE group_schedules (
  id                   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  discipline_group_id  INT          NOT NULL,
  weekday              SMALLINT     NOT NULL,
  start_time           TIME         NOT NULL,
  end_time             TIME         NOT NULL,
  description          TEXT,
  location             VARCHAR(60),               -- Cancha 2, Natatorio

  CONSTRAINT fk_gs_group FOREIGN KEY (discipline_group_id) REFERENCES discipline_groups (id),

  CONSTRAINT ck_gs_weekday CHECK (weekday BETWEEN 1 AND 7),
  -- No admite cruzar la medianoche.
  CONSTRAINT ck_gs_time    CHECK (end_time > start_time)
);

CREATE INDEX ix_gs_group ON group_schedules (discipline_group_id);

-- La grilla semanal: ORDER BY weekday, start_time sale lista.
CREATE INDEX ix_gs_weekday ON group_schedules (weekday, start_time);


-- ---------------------------------------------------------------------
--  teachers
-- ---------------------------------------------------------------------
CREATE TABLE teachers (
  id          INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  person_id   INT          NOT NULL,
  hired_on    DATE,
  is_active   BOOLEAN      NOT NULL DEFAULT true,
  notes       TEXT,
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT ux_teachers_person UNIQUE (person_id),
  CONSTRAINT fk_teachers_person FOREIGN KEY (person_id) REFERENCES people (id),

  CONSTRAINT ck_teachers_hired CHECK (hired_on IS NULL OR hired_on <= CURRENT_DATE)
);


-- ---------------------------------------------------------------------
--  group_teachers
-- ---------------------------------------------------------------------
CREATE TABLE group_teachers (
  id                   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  discipline_group_id  INT           NOT NULL,
  teacher_id           INT           NOT NULL,
  role                 teacher_role  NOT NULL DEFAULT 'HEAD',
  created_at           TIMESTAMPTZ   NOT NULL DEFAULT now(),

  CONSTRAINT ux_gt_group_teacher UNIQUE (discipline_group_id, teacher_id),
  CONSTRAINT fk_gt_group   FOREIGN KEY (discipline_group_id) REFERENCES discipline_groups (id),
  CONSTRAINT fk_gt_teacher FOREIGN KEY (teacher_id)          REFERENCES teachers (id)
);

-- "Qué grupos da este profesor".
CREATE INDEX ix_gt_teacher ON group_teachers (teacher_id);

-- Un solo titular por grupo; ayudantes, los que hagan falta.
CREATE UNIQUE INDEX ux_gt_head
  ON group_teachers (discipline_group_id)
  WHERE role = 'HEAD';
