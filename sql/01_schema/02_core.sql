-- =============================================================================
-- 02_core.sql
-- Clean, typed tables that the analysis queries read from.
--   ref.*   small lookup tables
--   core.*  one table per business entity, with keys, constraints and indexes
-- =============================================================================
DROP SCHEMA IF EXISTS mart CASCADE;   -- views depend on core, so drop them first
DROP SCHEMA IF EXISTS core CASCADE;
DROP SCHEMA IF EXISTS ref  CASCADE;
CREATE SCHEMA ref;
CREATE SCHEMA core;

-- ---------------------------------------------------------------- lookups
CREATE TABLE ref.diabetes_drug_class (
    generic_name    TEXT PRIMARY KEY,          -- lower-cased, trimmed join key
    drug_class      TEXT    NOT NULL,
    is_combination  BOOLEAN NOT NULL
);

CREATE TABLE ref.state (
    state_code  CHAR(2) PRIMARY KEY,
    state_name  TEXT NOT NULL UNIQUE
);

-- ---------------------------------------------------------------- providers
-- One row per clinician/organization (NPI) seen in either 2024 provider file.
CREATE TABLE core.provider (
    npi             CHAR(10) PRIMARY KEY CHECK (npi ~ '^[0-9]{10}$'),
    last_org_name   TEXT,
    first_name      TEXT,
    credentials     TEXT,
    entity_type     TEXT CHECK (entity_type IN ('Individual', 'Organization')),
    city            TEXT,
    state_code      CHAR(2) REFERENCES ref.state (state_code),
    zip5            CHAR(5),
    ruca_code       NUMERIC(4,1),
    geography       TEXT CHECK (geography IN ('Metropolitan', 'Micropolitan', 'Small town / Rural')),
    specialty       TEXT
);
CREATE INDEX ix_provider_specialty ON core.provider (specialty);
CREATE INDEX ix_provider_city      ON core.provider (city);

-- Medicare Part B (physician & other practitioner) totals, 2024
CREATE TABLE core.physician_utilization (
    npi                     CHAR(10) PRIMARY KEY REFERENCES core.provider (npi),
    data_year               SMALLINT NOT NULL,
    participates_in_mdcr    BOOLEAN,
    distinct_hcpcs_codes    INTEGER,
    total_beneficiaries     INTEGER,
    total_services          NUMERIC(14,1),
    submitted_charges       NUMERIC(16,2),
    allowed_amount          NUMERIC(16,2),
    medicare_payment        NUMERIC(16,2),
    standardized_payment    NUMERIC(16,2),
    bene_avg_age            NUMERIC(5,1),
    bene_female_cnt         INTEGER,
    bene_male_cnt           INTEGER,
    bene_dual_cnt           INTEGER,
    bene_nondual_cnt        INTEGER,
    pct_bene_diabetes       NUMERIC(5,2),   -- percent (0-100); NULL when suppressed
    pct_bene_hypertension   NUMERIC(5,2),
    pct_bene_ckd            NUMERIC(5,2),
    pct_bene_heart_failure  NUMERIC(5,2),
    pct_bene_depression     NUMERIC(5,2),
    bene_avg_risk_score     NUMERIC(6,4)
);

-- Medicare Part D prescribing totals, 2024
CREATE TABLE core.partd_prescriber (
    npi                     CHAR(10) PRIMARY KEY REFERENCES core.provider (npi),
    data_year               SMALLINT NOT NULL,
    total_claims            INTEGER NOT NULL CHECK (total_claims >= 0),
    total_30day_fills       NUMERIC(14,1),
    total_drug_cost         NUMERIC(16,2) NOT NULL CHECK (total_drug_cost >= 0),
    total_day_supply        INTEGER,
    total_beneficiaries     INTEGER,            -- NULL when CMS suppressed (<11)
    brand_claims            INTEGER,
    brand_drug_cost         NUMERIC(16,2),
    generic_claims          INTEGER,
    generic_drug_cost       NUMERIC(16,2),
    opioid_claims           INTEGER,
    opioid_beneficiaries    INTEGER,
    opioid_prescriber_rate  NUMERIC(6,2),
    antibiotic_claims       INTEGER,
    bene_avg_age            NUMERIC(5,1),
    bene_dual_cnt           INTEGER,
    bene_nondual_cnt        INTEGER,
    bene_avg_risk_score     NUMERIC(6,4)
);

-- Part D claims by prescriber and drug (diabetes drugs), 2024
CREATE TABLE core.partd_prescriber_drug (
    npi                 CHAR(10) NOT NULL REFERENCES core.provider (npi),
    data_year           SMALLINT NOT NULL,
    brand_name          TEXT NOT NULL,
    generic_name        TEXT NOT NULL REFERENCES ref.diabetes_drug_class (generic_name),
    prescriber_type     TEXT,
    total_claims        INTEGER NOT NULL CHECK (total_claims >= 11),  -- CMS publishes rows with 11+ claims only
    total_30day_fills   NUMERIC(12,1),
    total_day_supply    INTEGER,
    total_drug_cost     NUMERIC(14,2) NOT NULL CHECK (total_drug_cost >= 0),
    total_beneficiaries INTEGER,                -- NULL when suppressed
    ge65_claims         INTEGER,
    ge65_drug_cost      NUMERIC(14,2),
    ge65_suppressed     BOOLEAN NOT NULL,
    PRIMARY KEY (npi, data_year, brand_name, generic_name)
);
CREATE INDEX ix_ppd_generic ON core.partd_prescriber_drug (generic_name);

-- ---------------------------------------------------------------- drug trends
-- Part D totals by drug for one state and the nation, 2019-2024
CREATE TABLE core.partd_geo_drug (
    data_year           SMALLINT NOT NULL CHECK (data_year BETWEEN 2013 AND 2030),
    geo_level           TEXT     NOT NULL CHECK (geo_level IN ('State', 'National')),
    geo_name            TEXT     NOT NULL,
    brand_name          TEXT     NOT NULL,
    generic_name        TEXT     NOT NULL,
    total_prescribers   INTEGER,
    total_claims        INTEGER  NOT NULL,
    total_30day_fills   NUMERIC(14,1),
    total_drug_cost     NUMERIC(16,2) NOT NULL,
    total_beneficiaries INTEGER,
    lis_bene_cost_share    NUMERIC(16,2),  -- total out-of-pocket paid by low-income-subsidy enrollees
    nonlis_bene_cost_share NUMERIC(16,2),  -- total out-of-pocket paid by everyone else
    is_opioid           BOOLEAN,
    is_antibiotic       BOOLEAN,
    PRIMARY KEY (data_year, geo_level, geo_name, brand_name, generic_name)
);
CREATE INDEX ix_geo_generic ON core.partd_geo_drug (generic_name, data_year);

-- ---------------------------------------------------------------- enrollment
CREATE TABLE core.monthly_enrollment (
    state_code              CHAR(2) NOT NULL,     -- 'US' for the national total
    month_start             DATE    NOT NULL CHECK (EXTRACT(DAY FROM month_start) = 1),
    total_benes             INTEGER NOT NULL CHECK (total_benes > 0),
    original_medicare_benes INTEGER,
    medicare_advantage_benes INTEGER,
    aged_benes              INTEGER,
    disabled_benes          INTEGER,
    dual_eligible_benes     INTEGER,
    part_d_benes            INTEGER,
    PRIMARY KEY (state_code, month_start)
);

-- ---------------------------------------------------------------- hospitals
CREATE TABLE core.hospital (
    ccn                 CHAR(6) PRIMARY KEY,      -- CMS Certification Number
    hospital_name       TEXT NOT NULL,
    city                TEXT,
    state_code          CHAR(2) NOT NULL,
    zip5                CHAR(5),
    county              TEXT,
    hospital_type       TEXT,
    ownership_group     TEXT,                     -- standardized ownership category
    ownership_detail    TEXT,                     -- CMS original wording
    has_emergency_services BOOLEAN,
    birthing_friendly   BOOLEAN,
    overall_rating      SMALLINT CHECK (overall_rating BETWEEN 1 AND 5),
    readm_measures_better INTEGER,
    readm_measures_worse  INTEGER,
    readm_measures_reported INTEGER
);
CREATE INDEX ix_hospital_state ON core.hospital (state_code);

CREATE TABLE core.hcahps_response (
    ccn                 CHAR(6) NOT NULL REFERENCES core.hospital (ccn),
    measure_id          TEXT    NOT NULL,
    question            TEXT,
    answer_description  TEXT,
    star_rating         SMALLINT CHECK (star_rating BETWEEN 1 AND 5),
    answer_percent      SMALLINT CHECK (answer_percent BETWEEN 0 AND 100),
    linear_mean_value   SMALLINT,
    completed_surveys   INTEGER,
    response_rate_pct   SMALLINT,
    period_start        DATE,
    period_end          DATE,
    PRIMARY KEY (ccn, measure_id),
    CHECK (period_end >= period_start)
);
