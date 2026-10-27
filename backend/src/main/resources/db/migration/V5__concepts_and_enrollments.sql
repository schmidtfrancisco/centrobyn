-- =====================================================================
--  V5 - Conceptos cobrables, precios, inscripciones y periodos
--
--  El catalogo de lo que se puede cobrar y sus precios con vigencia,
--  las inscripciones a actividades y los periodos de facturacion.
--  Depende de V2 (accounts), V3 (members, member_categories) y
--  V4 (discipline_groups).
--  enrollments va aca y no en V4 porque apunta a billable_concepts.
-- =====================================================================


-- ---------------------------------------------------------------------
--  billable_concepts
--  Algo que se puede cobrar: la cuota de una categoria, la actividad de
--  un grupo, o un cargo esporadico. La secretaria elige CUAL, nunca
--  tipea CUANTO: el precio siempre esta precargado en concept_prices.
--
--  MEMBERSHIP: tiene categoria, no grupo.
--  ACTIVITY:   tiene grupo. Con categoria = tarifa especial para esa
--              categoria; sin categoria = tarifa general del grupo.
--  OTHER:      ni categoria ni grupo. Esporadicos e inscripcion inicial.
--
--  code e income_account_id solo existen en los OTHER: en los demas la
--  cuenta sale de la categoria o del grupo.
--  El concepto por defecto puede tomar el nombre del grupo o de la
--  categoria; cualquier otro necesita nombre propio, porque es lo que
--  lo distingue y lo que se copia a la descripcion del cargo.
-- ---------------------------------------------------------------------
CREATE TABLE billable_concepts (
  id                   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  code                 VARCHAR(30),
  name                 VARCHAR(80),
  charge_type          charge_type  NOT NULL,
  member_category_id   INT,
  discipline_group_id  INT,
  income_account_id    INT,
  is_default           BOOLEAN      NOT NULL DEFAULT false,
  is_active            BOOLEAN      NOT NULL DEFAULT true,
  created_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT fk_bc_category       FOREIGN KEY (member_category_id)  REFERENCES member_categories (id),
  CONSTRAINT fk_bc_group          FOREIGN KEY (discipline_group_id) REFERENCES discipline_groups (id),
  CONSTRAINT fk_bc_income_account FOREIGN KEY (income_account_id)   REFERENCES accounts (id),

  -- A que se refiere el concepto, segun su tipo.
  CONSTRAINT ck_bc_scope CHECK (
       (charge_type = 'MEMBERSHIP' AND member_category_id IS NOT NULL
                                   AND discipline_group_id IS NULL)
    OR (charge_type = 'ACTIVITY'   AND discipline_group_id IS NOT NULL)
    OR (charge_type = 'OTHER'      AND member_category_id IS NULL
                                   AND discipline_group_id IS NULL)
  ),

  -- Codigo y cuenta propios: solo los OTHER.
  CONSTRAINT ck_bc_other_fields
    CHECK (charge_type = 'OTHER' OR (code IS NULL AND income_account_id IS NULL)),

  -- Un OTHER no tiene de donde sacar nombre ni codigo: los exige.
  CONSTRAINT ck_bc_other_required
    CHECK (charge_type <> 'OTHER' OR (name IS NOT NULL AND code IS NOT NULL)),

  -- Un OTHER no es "por defecto" de nada.
  CONSTRAINT ck_bc_other_not_default
    CHECK (charge_type <> 'OTHER' OR NOT is_default),

  -- Solo el concepto por defecto puede no tener nombre propio.
  CONSTRAINT ck_bc_named
    CHECK (is_default OR name IS NOT NULL)
);

CREATE UNIQUE INDEX ux_bc_code
  ON billable_concepts (code)
  WHERE code IS NOT NULL;

-- Los usa la generacion mensual para resolver el concepto de cada
-- inscripcion y de cada socio.
CREATE INDEX ix_bc_group
  ON billable_concepts (discipline_group_id)
  WHERE is_active AND discipline_group_id IS NOT NULL;

CREATE INDEX ix_bc_category
  ON billable_concepts (member_category_id)
  WHERE is_active AND member_category_id IS NOT NULL;

-- Un solo concepto por defecto por grupo y por categoria: si hubiera
-- dos, la generacion elegiria cualquiera.
CREATE UNIQUE INDEX ux_bc_default_group
  ON billable_concepts (discipline_group_id)
  WHERE charge_type = 'ACTIVITY' AND is_default AND is_active;

CREATE UNIQUE INDEX ux_bc_default_category
  ON billable_concepts (member_category_id)
  WHERE charge_type = 'MEMBERSHIP' AND is_default AND is_active;

-- Una sola tarifa especial por grupo y categoria.
CREATE UNIQUE INDEX ux_bc_activity_category
  ON billable_concepts (discipline_group_id, member_category_id)
  WHERE charge_type = 'ACTIVITY' AND is_active
    AND member_category_id IS NOT NULL;


-- ---------------------------------------------------------------------
--  concept_prices
--  El precio es un hecho con fecha, no un atributo del concepto.
--  Sin valid_to: seria redundante y podria desincronizarse; sin el,
--  dos precios vigentes a la vez son imposibles de representar.
--  Precio vigente: la fila con el mayor valid_from <= FECHA DEL PERIODO
--  (nunca CURRENT_DATE: un cargo atrasado se cobra al precio de su mes).
--  Las fechas futuras son el caso principal: programar un aumento.
-- ---------------------------------------------------------------------
CREATE TABLE concept_prices (
  id          INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  concept_id  INT            NOT NULL,
  amount      DECIMAL(12,2)  NOT NULL,
  valid_from  DATE           NOT NULL,
  created_at  TIMESTAMPTZ    NOT NULL DEFAULT now(),

  -- Dos precios con la misma fecha de inicio darian un resultado
  -- arbitrario. Tambien es el indice que usa la consulta del vigente.
  CONSTRAINT ux_cp_concept_valid_from UNIQUE (concept_id, valid_from),
  CONSTRAINT fk_cp_concept FOREIGN KEY (concept_id) REFERENCES billable_concepts (id),

  -- Cero es valido: cuota societaria del vitalicio, no socios de
  -- colonia. Con precio cero no se emite el cargo.
  CONSTRAINT ck_cp_amount CHECK (amount >= 0)
);


-- ---------------------------------------------------------------------
--  enrollments
--  Que actividades hace cada socio. Bisagra entre la oferta y la
--  cobranza: el proceso mensual recorre las activas y emite un cargo
--  por cada una.
--  Activa = ended_on IS NULL. Sin columna de estado.
--  Un socio puede dejar y volver: son dos inscripciones distintas. Lo
--  que se impide son dos ACTIVAS a la vez en el mismo grupo.
--  concept_id nulo = se resuelve como siempre (tarifa de su categoria
--  o la por defecto del grupo). Con valor = concepto acordado para esa
--  inscripcion. Que sea de tipo ACTIVITY y del mismo grupo lo valida
--  el servicio.
--  Al dar de baja se llena ended_on: no se borra, genero cargos.
-- ---------------------------------------------------------------------
CREATE TABLE enrollments (
  id                   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  member_id            INT          NOT NULL,
  discipline_group_id  INT          NOT NULL,
  concept_id           INT,
  enrolled_on          DATE         NOT NULL,
  ended_on             DATE,
  created_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT fk_enrollments_member  FOREIGN KEY (member_id)           REFERENCES members (id),
  CONSTRAINT fk_enrollments_group   FOREIGN KEY (discipline_group_id) REFERENCES discipline_groups (id),
  CONSTRAINT fk_enrollments_concept FOREIGN KEY (concept_id)          REFERENCES billable_concepts (id),

  CONSTRAINT ck_enrollments_dates
    CHECK (ended_on IS NULL OR ended_on >= enrolled_on)
);

CREATE UNIQUE INDEX ux_enrollments_active
  ON enrollments (member_id, discipline_group_id)
  WHERE ended_on IS NULL;

-- Historial completo de un socio, incluidas las terminadas.
CREATE INDEX ix_enrollments_member ON enrollments (member_id);

-- Control de cupo y lista de inscriptos de un grupo.
CREATE INDEX ix_enrollments_group_active
  ON enrollments (discipline_group_id)
  WHERE ended_on IS NULL;


-- ---------------------------------------------------------------------
--  billing_periods
--  Que meses se facturaron y cuando vencen. Existe porque la cuota es
--  mensual con el mismo vencimiento para todos: el periodo es un objeto
--  compartido, no un dato de cada socio.
--  El estado es la puerta que impide generar dos veces el mismo mes
--  (la garantia real esta en los indices unicos de charges).
--  Se crean por adelantado ("abrir el anio"): para cobrar por
--  adelantado los periodos futuros tienen que existir.
-- ---------------------------------------------------------------------
CREATE TABLE billing_periods (
  id            INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  year          SMALLINT               NOT NULL,
  month         SMALLINT               NOT NULL,
  due_date      DATE                   NOT NULL,
  status        billing_period_status  NOT NULL DEFAULT 'OPEN',
  generated_at  TIMESTAMPTZ,

  -- Impide que existan dos "marzo 2026".
  CONSTRAINT ux_bp_year_month UNIQUE (year, month),

  CONSTRAINT ck_bp_month CHECK (month BETWEEN 1 AND 12),
  CONSTRAINT ck_bp_year  CHECK (year BETWEEN 2000 AND 2100),
  CONSTRAINT ck_bp_generated
    CHECK ((status = 'OPEN') = (generated_at IS NULL))
);
