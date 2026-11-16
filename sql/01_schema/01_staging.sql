-- =============================================================================
-- 01_staging.sql
-- Raw landing tables. Every column is TEXT on purpose: CMS files mix numbers
-- with suppression markers ("*", "#"), blanks and phrases like "Not Available",
-- so we load exactly what was published and do all typing/cleaning in SQL.
-- Column order matches the CSV headers written by scripts/download_cms.py.
-- =============================================================================
DROP SCHEMA IF EXISTS staging CASCADE;
CREATE SCHEMA staging;

-- Medicare Part D Prescribers - by Provider and Drug (2024), diabetes drugs
CREATE TABLE staging.partd_prescriber_drug (
    prscrbr_npi             TEXT,
    prscrbr_last_org_name   TEXT,
    prscrbr_first_name      TEXT,
    prscrbr_city            TEXT,
    prscrbr_state_abrvtn    TEXT,
    prscrbr_state_fips      TEXT,
    prscrbr_type            TEXT,
    prscrbr_type_src        TEXT,
    brnd_name               TEXT,
    gnrc_name               TEXT,
    tot_clms                TEXT,
    tot_30day_fills         TEXT,
    tot_day_suply           TEXT,
    tot_drug_cst            TEXT,
    tot_benes               TEXT,
    ge65_sprsn_flag         TEXT,
    ge65_tot_clms           TEXT,
    ge65_tot_drug_cst       TEXT,
    ge65_bene_sprsn_flag    TEXT,
    ge65_tot_benes          TEXT
);

-- Medicare Part D Prescribers - by Provider (2024), one row per prescriber
CREATE TABLE staging.partd_prescriber (
    prscrbr_npi             TEXT,
    prscrbr_last_org_name   TEXT,
    prscrbr_first_name      TEXT,
    prscrbr_crdntls         TEXT,
    prscrbr_ent_cd          TEXT,
    prscrbr_city            TEXT,
    prscrbr_state_abrvtn    TEXT,
    prscrbr_zip5            TEXT,
    prscrbr_ruca            TEXT,
    prscrbr_ruca_desc       TEXT,
    prscrbr_type            TEXT,
    tot_clms                TEXT,
    tot_30day_fills         TEXT,
    tot_drug_cst            TEXT,
    tot_day_suply           TEXT,
    tot_benes               TEXT,
    brnd_tot_clms           TEXT,
    brnd_tot_drug_cst       TEXT,
    gnrc_tot_clms           TEXT,
    gnrc_tot_drug_cst       TEXT,
    opioid_tot_clms         TEXT,
    opioid_tot_benes        TEXT,
    opioid_prscrbr_rate     TEXT,
    antbtc_tot_clms         TEXT,
    bene_avg_age            TEXT,
    bene_dual_cnt           TEXT,
    bene_ndual_cnt          TEXT,
    bene_avg_risk_scre      TEXT
);

-- Medicare Physician & Other Practitioners - by Provider (2024)
CREATE TABLE staging.physician_provider (
    rndrng_npi                      TEXT,
    rndrng_prvdr_last_org_name      TEXT,
    rndrng_prvdr_first_name         TEXT,
    rndrng_prvdr_crdntls            TEXT,
    rndrng_prvdr_ent_cd             TEXT,
    rndrng_prvdr_city               TEXT,
    rndrng_prvdr_state_abrvtn       TEXT,
    rndrng_prvdr_zip5               TEXT,
    rndrng_prvdr_ruca               TEXT,
    rndrng_prvdr_ruca_desc          TEXT,
    rndrng_prvdr_type               TEXT,
    rndrng_prvdr_mdcr_prtcptg_ind   TEXT,
    tot_hcpcs_cds                   TEXT,
    tot_benes                       TEXT,
    tot_srvcs                       TEXT,
    tot_sbmtd_chrg                  TEXT,
    tot_mdcr_alowd_amt              TEXT,
    tot_mdcr_pymt_amt               TEXT,
    tot_mdcr_stdzd_amt              TEXT,
    bene_avg_age                    TEXT,
    bene_feml_cnt                   TEXT,
    bene_male_cnt                   TEXT,
    bene_dual_cnt                   TEXT,
    bene_ndual_cnt                  TEXT,
    bene_cc_ph_diabetes_v2_pct      TEXT,
    bene_cc_ph_hypertension_v2_pct  TEXT,
    bene_cc_ph_ckd_v2_pct           TEXT,
    bene_cc_ph_hf_nonihd_v2_pct     TEXT,
    bene_cc_bh_depress_v1_pct       TEXT,
    bene_avg_risk_scre              TEXT
);

-- Medicare Part D Prescribers - by Geography and Drug (2019-2024), state + national
CREATE TABLE staging.partd_geo_drug (
    data_year               TEXT,
    prscrbr_geo_lvl         TEXT,
    prscrbr_geo_cd          TEXT,
    prscrbr_geo_desc        TEXT,
    brnd_name               TEXT,
    gnrc_name               TEXT,
    tot_prscrbrs            TEXT,
    tot_clms                TEXT,
    tot_30day_fills         TEXT,
    tot_drug_cst            TEXT,
    tot_benes               TEXT,
    ge65_sprsn_flag         TEXT,
    ge65_tot_clms           TEXT,
    ge65_tot_drug_cst       TEXT,
    ge65_bene_sprsn_flag    TEXT,
    ge65_tot_benes          TEXT,
    lis_bene_cst_shr        TEXT,
    nonlis_bene_cst_shr     TEXT,
    opioid_drug_flag        TEXT,
    antbtc_drug_flag        TEXT
);

-- Medicare Monthly Enrollment (state + national)
CREATE TABLE staging.monthly_enrollment (
    year                     TEXT,
    month                    TEXT,
    bene_geo_lvl             TEXT,
    bene_state_abrvtn        TEXT,
    bene_state_desc          TEXT,
    tot_benes                TEXT,
    orgnl_mdcr_benes         TEXT,
    ma_and_oth_benes         TEXT,
    aged_tot_benes           TEXT,
    dsbld_tot_benes          TEXT,
    dual_tot_benes           TEXT,
    prscrptn_drug_tot_benes  TEXT
);

-- Provider Data Catalog: Hospital General Information (all states)
CREATE TABLE staging.hospital_general_info (
    facility_id                       TEXT,
    facility_name                     TEXT,
    address                           TEXT,
    city_town                         TEXT,
    state                             TEXT,
    zip_code                          TEXT,
    county_parish                     TEXT,
    telephone_number                  TEXT,
    hospital_type                     TEXT,
    hospital_ownership                TEXT,
    emergency_services                TEXT,
    birthing_friendly                 TEXT,
    hospital_overall_rating           TEXT,
    hospital_overall_rating_footnote  TEXT,
    mort_group_measure_count          TEXT,
    count_facility_mort_measures      TEXT,
    count_mort_measures_better        TEXT,
    count_mort_measures_no_different  TEXT,
    count_mort_measures_worse         TEXT,
    mort_group_footnote               TEXT,
    safety_group_measure_count        TEXT,
    count_facility_safety_measures    TEXT,
    count_safety_measures_better      TEXT,
    count_safety_measures_no_different TEXT,
    count_safety_measures_worse       TEXT,
    safety_group_footnote             TEXT,
    readm_group_measure_count         TEXT,
    count_facility_readm_measures     TEXT,
    count_readm_measures_better       TEXT,
    count_readm_measures_no_different TEXT,
    count_readm_measures_worse        TEXT,
    readm_group_footnote              TEXT,
    pt_exp_group_measure_count        TEXT,
    count_facility_pt_exp_measures    TEXT,
    pt_exp_group_footnote             TEXT,
    te_group_measure_count            TEXT,
    count_facility_te_measures        TEXT,
    te_group_footnote                 TEXT
);

-- Provider Data Catalog: Patient survey (HCAHPS) - Hospital (one state)
CREATE TABLE staging.hcahps_hospital (
    facility_id                           TEXT,
    facility_name                         TEXT,
    address                               TEXT,
    city_town                             TEXT,
    state                                 TEXT,
    zip_code                              TEXT,
    county_parish                         TEXT,
    telephone_number                      TEXT,
    hcahps_measure_id                     TEXT,
    hcahps_question                       TEXT,
    hcahps_answer_description             TEXT,
    patient_survey_star_rating            TEXT,
    patient_survey_star_rating_footnote   TEXT,
    hcahps_answer_percent                 TEXT,
    hcahps_answer_percent_footnote        TEXT,
    hcahps_linear_mean_value              TEXT,
    number_of_completed_surveys           TEXT,
    number_of_completed_surveys_footnote  TEXT,
    survey_response_rate_percent          TEXT,
    survey_response_rate_percent_footnote TEXT,
    start_date                            TEXT,
    end_date                              TEXT
);

-- Hand-built lookup: diabetes drug generic name -> therapeutic class
CREATE TABLE staging.diabetes_drug_class (
    gnrc_name       TEXT,
    drug_class      TEXT,
    is_combination  TEXT
);
