-- =============================================================================
-- 02_providers.sql
-- Build the provider dimension and the two provider-level fact tables.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- core.provider
-- A clinician can appear in the Part B (physician) file, the Part D file, or
-- both. Stack both sources, then keep ONE row per NPI with ROW_NUMBER(),
-- preferring the Part B record because it carries entity type and credentials
-- for organizations as well.
-- ---------------------------------------------------------------------------
WITH stacked AS (
    SELECT util.clean_text(rndrng_npi)                  AS npi,
           util.clean_text(rndrng_prvdr_last_org_name)  AS last_org_name,
           util.clean_text(rndrng_prvdr_first_name)     AS first_name,
           rndrng_prvdr_crdntls                         AS raw_credentials,
           rndrng_prvdr_ent_cd                          AS ent_cd,
           rndrng_prvdr_city                            AS city,
           rndrng_prvdr_state_abrvtn                    AS state_code,
           rndrng_prvdr_zip5                            AS zip5,
           rndrng_prvdr_ruca                            AS ruca,
           rndrng_prvdr_type                            AS specialty,
           1                                            AS source_priority
    FROM staging.physician_provider
    UNION ALL
    SELECT util.clean_text(prscrbr_npi), util.clean_text(prscrbr_last_org_name),
           util.clean_text(prscrbr_first_name), prscrbr_crdntls, prscrbr_ent_cd,
           prscrbr_city, prscrbr_state_abrvtn, prscrbr_zip5, prscrbr_ruca,
           prscrbr_type, 2
    FROM staging.partd_prescriber
),
ranked AS (
    SELECT s.*,
           ROW_NUMBER() OVER (PARTITION BY npi ORDER BY source_priority) AS rn
    FROM stacked s
    WHERE npi ~ '^[0-9]{10}$'           -- drop malformed identifiers
)
INSERT INTO core.provider (npi, last_org_name, first_name, credentials, entity_type,
                           city, state_code, zip5, ruca_code, geography, specialty)
SELECT npi,
       last_org_name,
       first_name,
       -- 'M.D.', 'm.d', 'MD ' all become 'MD'
       NULLIF(REGEXP_REPLACE(UPPER(COALESCE(raw_credentials, '')), '[.\s]', '', 'g'), ''),
       CASE UPPER(TRIM(ent_cd)) WHEN 'I' THEN 'Individual' WHEN 'O' THEN 'Organization' END,
       INITCAP(util.clean_text(city)),
       UPPER(TRIM(state_code)),
       LPAD(util.clean_text(zip5), 5, '0'),            -- restore leading zeros
       NULLIF(util.to_num(ruca), 99),                   -- 99 = 'Unknown'
       CASE
           WHEN FLOOR(util.to_num(ruca)) BETWEEN 1 AND 3  THEN 'Metropolitan'
           WHEN FLOOR(util.to_num(ruca)) BETWEEN 4 AND 6  THEN 'Micropolitan'
           WHEN FLOOR(util.to_num(ruca)) BETWEEN 7 AND 10 THEN 'Small town / Rural'
       END,
       util.clean_text(specialty)
FROM ranked
WHERE rn = 1;

-- ---------------------------------------------------------------------------
-- core.physician_utilization  (Medicare Part B, 2024)
-- ---------------------------------------------------------------------------
INSERT INTO core.physician_utilization
SELECT util.clean_text(rndrng_npi),
       2024,
       util.to_bool(rndrng_prvdr_mdcr_prtcptg_ind),
       util.to_int(tot_hcpcs_cds),
       util.to_int(tot_benes),
       util.to_num(tot_srvcs),
       util.to_num(tot_sbmtd_chrg),
       util.to_num(tot_mdcr_alowd_amt),
       util.to_num(tot_mdcr_pymt_amt),
       util.to_num(tot_mdcr_stdzd_amt),
       util.to_num(bene_avg_age),
       util.to_int(bene_feml_cnt),
       util.to_int(bene_male_cnt),
       util.to_int(bene_dual_cnt),
       util.to_int(bene_ndual_cnt),
       util.to_num(bene_cc_ph_diabetes_v2_pct),
       util.to_num(bene_cc_ph_hypertension_v2_pct),
       util.to_num(bene_cc_ph_ckd_v2_pct),
       util.to_num(bene_cc_ph_hf_nonihd_v2_pct),
       util.to_num(bene_cc_bh_depress_v1_pct),
       util.to_num(bene_avg_risk_scre)
FROM staging.physician_provider
WHERE util.clean_text(rndrng_npi) IN (SELECT npi FROM core.provider);

-- ---------------------------------------------------------------------------
-- core.partd_prescriber  (Medicare Part D, 2024)
-- Blank beneficiary counts are CMS suppression (fewer than 11) -> stay NULL.
-- ---------------------------------------------------------------------------
INSERT INTO core.partd_prescriber
SELECT util.clean_text(prscrbr_npi),
       2024,
       util.to_int(tot_clms),
       util.to_num(tot_30day_fills),
       util.to_num(tot_drug_cst),
       util.to_int(tot_day_suply),
       util.to_int(tot_benes),
       util.to_int(brnd_tot_clms),
       util.to_num(brnd_tot_drug_cst),
       util.to_int(gnrc_tot_clms),
       util.to_num(gnrc_tot_drug_cst),
       util.to_int(opioid_tot_clms),
       util.to_int(opioid_tot_benes),
       util.to_num(opioid_prscrbr_rate),
       util.to_int(antbtc_tot_clms),
       util.to_num(bene_avg_age),
       util.to_int(bene_dual_cnt),
       util.to_int(bene_ndual_cnt),
       util.to_num(bene_avg_risk_scre)
FROM staging.partd_prescriber
WHERE util.clean_text(prscrbr_npi) IN (SELECT npi FROM core.provider);

-- ---------------------------------------------------------------------------
-- core.partd_prescriber_drug  (diabetes drugs, 2024)
-- GE65 flags: '*' = fewer than 11, '#' = hidden so the '*' cell can't be
-- back-calculated. Either way the 65+ numbers are unusable -> suppressed = TRUE.
-- ---------------------------------------------------------------------------
INSERT INTO core.partd_prescriber_drug
SELECT util.clean_text(prscrbr_npi),
       2024,
       util.clean_text(brnd_name),
       LOWER(util.clean_text(gnrc_name)),
       util.clean_text(prscrbr_type),
       util.to_int(tot_clms),
       util.to_num(tot_30day_fills),
       util.to_int(tot_day_suply),
       util.to_num(tot_drug_cst),
       util.to_int(tot_benes),
       util.to_int(ge65_tot_clms),
       util.to_num(ge65_tot_drug_cst),
       COALESCE(TRIM(ge65_sprsn_flag) IN ('*', '#'), FALSE)
FROM staging.partd_prescriber_drug;
