-- =============================================================================
-- 01_views.sql
-- Reusable, analyst-friendly views (the "mart" layer). Analysis queries read
-- from these so business logic such as specialty grouping lives in ONE place.
-- =============================================================================
DROP SCHEMA IF EXISTS mart CASCADE;
CREATE SCHEMA mart;

-- ---------------------------------------------------------------------------
-- Specialty grouping used across the project.
-- ---------------------------------------------------------------------------
CREATE FUNCTION mart.specialty_group(specialty TEXT)
RETURNS TEXT
LANGUAGE sql IMMUTABLE
AS $$
    SELECT CASE
        WHEN specialty IN ('Family Practice', 'Internal Medicine', 'General Practice',
                           'Geriatric Medicine', 'Preventive Medicine')       THEN 'Primary care physician'
        WHEN specialty IN ('Nurse Practitioner', 'Physician Assistant',
                           'Certified Clinical Nurse Specialist')             THEN 'NP / PA'
        WHEN specialty = 'Endocrinology'                                      THEN 'Endocrinology'
        WHEN specialty ILIKE '%cardiology%'                                    THEN 'Cardiology'
        WHEN specialty = 'Nephrology'                                         THEN 'Nephrology'
        WHEN specialty IS NULL                                                THEN 'Unknown'
        ELSE 'Other specialty'
    END;
$$;

-- ---------------------------------------------------------------------------
-- One row per provider with both Part B and Part D activity side by side.
-- LEFT JOINs keep providers who only appear in one program.
-- ---------------------------------------------------------------------------
CREATE VIEW mart.v_provider_profile AS
SELECT p.npi,
       p.entity_type,
       p.credentials,
       p.city,
       p.state_code,
       p.geography,
       p.specialty,
       mart.specialty_group(p.specialty)          AS specialty_group,
       (b.npi IS NOT NULL)                        AS in_part_b,
       (d.npi IS NOT NULL)                        AS in_part_d,
       b.total_beneficiaries                      AS part_b_beneficiaries,
       b.medicare_payment                         AS part_b_payment,
       b.pct_bene_diabetes,
       b.bene_avg_risk_score                      AS part_b_risk_score,
       d.total_claims                             AS part_d_claims,
       d.total_drug_cost                          AS part_d_drug_cost,
       d.generic_claims                           AS part_d_generic_claims,
       d.brand_claims                             AS part_d_brand_claims
FROM core.provider p
LEFT JOIN core.physician_utilization b ON b.npi = p.npi
LEFT JOIN core.partd_prescriber      d ON d.npi = p.npi;

-- ---------------------------------------------------------------------------
-- Diabetes prescribing rows enriched with drug class and prescriber details.
-- ---------------------------------------------------------------------------
CREATE VIEW mart.v_diabetes_prescribing AS
SELECT d.npi,
       d.data_year,
       d.brand_name,
       d.generic_name,
       c.drug_class,
       c.is_combination,
       CASE
           WHEN c.drug_class IN ('GLP-1 receptor agonist', 'GIP/GLP-1 receptor agonist')
                THEN 'GLP-1 / GIP'
           WHEN c.drug_class LIKE 'Insulin -%' OR c.drug_class = 'Insulin + GLP-1 combination'
                THEN 'Insulin'
           WHEN c.drug_class = 'Insulin delivery supplies' THEN 'Supplies'
           ELSE 'Other oral / non-insulin'
       END                                         AS class_family,
       p.city,
       p.geography,
       p.specialty,
       mart.specialty_group(p.specialty)           AS specialty_group,
       d.total_claims,
       d.total_30day_fills,
       d.total_drug_cost,
       d.total_beneficiaries
FROM core.partd_prescriber_drug d
JOIN ref.diabetes_drug_class c ON c.generic_name = d.generic_name
JOIN core.provider           p ON p.npi = d.npi;

-- ---------------------------------------------------------------------------
-- HCAHPS pivot: one row per hospital with the headline survey measures.
-- Conditional aggregation (MAX ... FILTER) turns rows into columns.
-- ---------------------------------------------------------------------------
CREATE VIEW mart.v_hospital_patient_experience AS
SELECT h.ccn,
       h.hospital_name,
       h.city,
       h.state_code,
       h.hospital_type,
       h.ownership_group,
       h.overall_rating,
       MAX(r.star_rating)       FILTER (WHERE r.measure_id = 'H_STAR_RATING')     AS hcahps_summary_stars,
       MAX(r.answer_percent)    FILTER (WHERE r.measure_id = 'H_RECMND_DY')       AS pct_definitely_recommend,
       MAX(r.answer_percent)    FILTER (WHERE r.measure_id = 'H_HSP_RATING_9_10') AS pct_rating_9_or_10,
       MAX(r.answer_percent)    FILTER (WHERE r.measure_id = 'H_COMP_1_A_P')      AS pct_nurse_always_communicated,
       MAX(r.completed_surveys)                                                   AS completed_surveys,
       MIN(r.period_start)                                                        AS period_start,
       MAX(r.period_end)                                                          AS period_end
FROM core.hospital h
LEFT JOIN core.hcahps_response r ON r.ccn = h.ccn
GROUP BY h.ccn, h.hospital_name, h.city, h.state_code, h.hospital_type,
         h.ownership_group, h.overall_rating;

-- ---------------------------------------------------------------------------
-- Annual enrollment per state: average of the monthly counts in each year,
-- plus the share of beneficiaries in Medicare Advantage.
-- ---------------------------------------------------------------------------
CREATE VIEW mart.v_enrollment_annual AS
SELECT state_code,
       EXTRACT(YEAR FROM month_start)::INT                          AS calendar_year,
       COUNT(*)                                                     AS months_reported,
       ROUND(AVG(total_benes))                                      AS avg_total_benes,
       ROUND(AVG(medicare_advantage_benes))                         AS avg_ma_benes,
       ROUND(100.0 * SUM(medicare_advantage_benes) / NULLIF(SUM(total_benes), 0), 1) AS ma_share_pct
FROM core.monthly_enrollment
GROUP BY state_code, EXTRACT(YEAR FROM month_start);

-- ---------------------------------------------------------------------------
-- Stored function: year-over-year trend for one drug in one geography.
-- Example:  SELECT * FROM mart.drug_trend('semaglutide', 'Tennessee');
-- ---------------------------------------------------------------------------
CREATE FUNCTION mart.drug_trend(p_generic_name TEXT, p_geo_name TEXT DEFAULT 'National')
RETURNS TABLE (
    data_year        SMALLINT,
    total_claims     BIGINT,
    total_drug_cost  NUMERIC,
    cost_per_claim   NUMERIC,
    claims_yoy_pct   NUMERIC
)
LANGUAGE sql STABLE
AS $$
    WITH yearly AS (
        SELECT g.data_year,
               SUM(g.total_claims)    AS total_claims,
               SUM(g.total_drug_cost) AS total_drug_cost
        FROM core.partd_geo_drug g
        WHERE g.generic_name = LOWER(TRIM(p_generic_name))
          AND g.geo_name     = p_geo_name
        GROUP BY g.data_year
    )
    SELECT data_year,
           total_claims,
           ROUND(total_drug_cost, 0),
           ROUND(total_drug_cost / NULLIF(total_claims, 0), 2),
           ROUND(100.0 * (total_claims - LAG(total_claims) OVER (ORDER BY data_year))
                 / NULLIF(LAG(total_claims) OVER (ORDER BY data_year), 0), 1)
    FROM yearly
    ORDER BY data_year;
$$;
