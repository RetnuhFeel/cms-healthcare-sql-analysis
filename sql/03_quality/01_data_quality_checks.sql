-- =============================================================================
-- 01_data_quality_checks.sql
-- Data-quality assertions. Each check counts the rows that FAIL a rule.
--   severity 'error' -> the build stops (CI goes red) if failed_rows > 0
--   severity 'warn'  -> reported, but known/acceptable in CMS data
-- Results are kept in dq.check_results so they can be queried later.
-- =============================================================================
DROP SCHEMA IF EXISTS dq CASCADE;
CREATE SCHEMA dq;

CREATE TABLE dq.check_results (
    check_id     SERIAL PRIMARY KEY,
    check_name   TEXT    NOT NULL,
    severity     TEXT    NOT NULL CHECK (severity IN ('error', 'warn')),
    failed_rows  BIGINT  NOT NULL,
    checked_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO dq.check_results (check_name, severity, failed_rows)

-- 1. Completeness: nothing lost between staging and core -------------------
SELECT 'row count: partd_prescriber_drug staging = core', 'error',
       ABS((SELECT COUNT(*) FROM staging.partd_prescriber_drug)
         - (SELECT COUNT(*) FROM core.partd_prescriber_drug))
UNION ALL
SELECT 'row count: partd_prescriber staging = core', 'error',
       ABS((SELECT COUNT(*) FROM staging.partd_prescriber)
         - (SELECT COUNT(*) FROM core.partd_prescriber))
UNION ALL
SELECT 'row count: physician_provider staging = core', 'error',
       ABS((SELECT COUNT(*) FROM staging.physician_provider)
         - (SELECT COUNT(*) FROM core.physician_utilization))
UNION ALL
SELECT 'row count: hospital staging = core', 'error',
       ABS((SELECT COUNT(*) FROM staging.hospital_general_info)
         - (SELECT COUNT(*) FROM core.hospital))

-- 2. Money reconciles to the cent after type casting ------------------------
UNION ALL
SELECT 'reconcile: Part D drug cost (staging vs core), cents off', 'error',
       ABS(ROUND(100 * ((SELECT SUM(util.to_num(tot_drug_cst)) FROM staging.partd_prescriber)
                      - (SELECT SUM(total_drug_cost) FROM core.partd_prescriber))))::BIGINT
UNION ALL
SELECT 'reconcile: Part B Medicare payment (staging vs core), cents off', 'error',
       ABS(ROUND(100 * ((SELECT SUM(util.to_num(tot_mdcr_pymt_amt)) FROM staging.physician_provider)
                      - (SELECT SUM(medicare_payment) FROM core.physician_utilization))))::BIGINT

-- 3. Unexpected formats: a value that is not blank, not a suppression marker
--    and not a documented phrase, but still failed numeric conversion ---------
UNION ALL
SELECT 'format: unparseable Part D numeric values', 'error', COUNT(*)
FROM staging.partd_prescriber s
CROSS JOIN LATERAL (VALUES (s.tot_clms), (s.tot_drug_cst), (s.tot_benes), (s.opioid_tot_clms)) v(val)
WHERE util.clean_text(v.val) IS NOT NULL
  AND util.clean_text(v.val) NOT IN ('*', '#')
  AND util.to_num(v.val) IS NULL
UNION ALL
SELECT 'format: unparseable HCAHPS values', 'error', COUNT(*)
FROM staging.hcahps_hospital s
CROSS JOIN LATERAL (VALUES (s.patient_survey_star_rating), (s.hcahps_answer_percent),
                           (s.number_of_completed_surveys)) v(val)
WHERE util.clean_text(v.val) NOT IN ('Not Applicable', 'Not Available')
  AND util.to_num(v.val) IS NULL
UNION ALL
SELECT 'format: hospital CCN is not 6 characters', 'error', COUNT(*)
FROM core.hospital WHERE LENGTH(ccn) <> 6

-- 4. Uniqueness and referential integrity -----------------------------------
UNION ALL
SELECT 'unique: one provider row per NPI', 'error',
       COUNT(*) - COUNT(DISTINCT npi) FROM core.provider
UNION ALL
SELECT 'orphans: drug rows whose NPI has no Part D summary row', 'warn', COUNT(*)
FROM core.partd_prescriber_drug d
WHERE NOT EXISTS (SELECT 1 FROM core.partd_prescriber p WHERE p.npi = d.npi)
UNION ALL
SELECT 'mapping: diabetes-looking 2024 drug names missing from ref table', 'warn', COUNT(DISTINCT g.generic_name)
FROM core.partd_geo_drug g
LEFT JOIN ref.diabetes_drug_class r ON r.generic_name = g.generic_name
WHERE g.data_year = 2024
  AND g.generic_name ~ '(insulin|metformin|gliflozin|gliptin|glutide|tirzepatide|glipizide|glimepiride|glyburide|pioglitazone)'
  AND g.generic_name <> 'teduglutide'          -- GLP-2 drug for short bowel syndrome, not diabetes
  AND r.generic_name IS NULL

UNION ALL
-- CMS hides prescriber-drug rows with fewer than 11 claims. If the provider-level
-- file explains less than 80% of the state total, the sample is probably incomplete.
SELECT 'coverage: prescriber-level diabetes claims < 80% of state total (2024)', 'error',
       CASE WHEN (SELECT SUM(total_claims) FROM core.partd_prescriber_drug)
               < 0.8 * (SELECT SUM(g.total_claims)
                        FROM core.partd_geo_drug g
                        JOIN ref.diabetes_drug_class c ON c.generic_name = g.generic_name
                        WHERE g.geo_level = 'State' AND g.data_year = 2024)
            THEN 1 ELSE 0 END
UNION ALL
SELECT 'suppression: prescribers with a hidden beneficiary count (<11)', 'warn', COUNT(*)
FROM core.partd_prescriber WHERE total_beneficiaries IS NULL

-- 5. Business-rule ranges -----------------------------------------------------
UNION ALL
SELECT 'range: negative Part D cost or claims', 'error', COUNT(*)
FROM core.partd_prescriber WHERE total_drug_cost < 0 OR total_claims < 0
UNION ALL
SELECT 'logic: brand + generic claims exceed total claims', 'error', COUNT(*)
FROM core.partd_prescriber
WHERE COALESCE(brand_claims, 0) + COALESCE(generic_claims, 0) > total_claims
UNION ALL
SELECT 'logic: Medicare paid more than the allowed amount', 'warn', COUNT(*)
FROM core.physician_utilization WHERE medicare_payment > allowed_amount
UNION ALL
SELECT 'range: chronic-condition percent outside 0-100', 'error', COUNT(*)
FROM core.physician_utilization
WHERE pct_bene_diabetes NOT BETWEEN 0 AND 100 OR pct_bene_hypertension NOT BETWEEN 0 AND 100
UNION ALL
SELECT 'logic: state claims exceed national claims for the same drug/year', 'error', COUNT(*)
FROM core.partd_geo_drug s
JOIN core.partd_geo_drug n
  ON n.data_year = s.data_year AND n.brand_name = s.brand_name
 AND n.generic_name = s.generic_name AND n.geo_level = 'National'
WHERE s.geo_level = 'State' AND s.total_claims > n.total_claims
UNION ALL
SELECT 'logic: HCAHPS period end before start', 'error', COUNT(*)
FROM core.hcahps_response WHERE period_end < period_start

-- 6. Time series: every state has an unbroken run of months ------------------
UNION ALL
SELECT 'continuity: gaps in monthly enrollment series', 'error', COUNT(*)
FROM (
    SELECT month_start,
           LAG(month_start) OVER (PARTITION BY state_code ORDER BY month_start) AS prev_month
    FROM core.monthly_enrollment
) t
WHERE prev_month IS NOT NULL AND month_start <> prev_month + INTERVAL '1 month'
UNION ALL
SELECT 'logic: Original Medicare + MA differs from total by > 0.1%', 'warn', COUNT(*)
FROM core.monthly_enrollment
WHERE ABS(original_medicare_benes + medicare_advantage_benes - total_benes) > 0.001 * total_benes;

-- Show the report.
SELECT check_id, severity, failed_rows,
       CASE WHEN failed_rows = 0 THEN 'PASS'
            WHEN severity = 'warn' THEN 'WARN'
            ELSE 'FAIL' END AS status,
       check_name
FROM dq.check_results
ORDER BY check_id;

-- Stop the build if any error-level check failed.
DO $$
DECLARE
    n_failed INTEGER;
BEGIN
    SELECT COUNT(*) INTO n_failed
    FROM dq.check_results
    WHERE severity = 'error' AND failed_rows > 0;

    IF n_failed > 0 THEN
        RAISE EXCEPTION 'Data-quality checks failed: % error-level check(s). See dq.check_results.', n_failed;
    END IF;
    RAISE NOTICE 'All error-level data-quality checks passed.';
END $$;
