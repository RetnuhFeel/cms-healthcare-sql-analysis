-- =============================================================================
-- 03_drugs_enrollment.sql
-- Drug trend table (state + national, 2019-2024) and monthly enrollment.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- core.partd_geo_drug
-- CMS spells some brand names differently from year to year (extra spaces,
-- case). Normalize whitespace and keep a single row per natural key in case
-- the cleanup creates duplicates (summing the measures).
-- ---------------------------------------------------------------------------
INSERT INTO core.partd_geo_drug
SELECT util.to_int(data_year)::SMALLINT,
       util.clean_text(prscrbr_geo_lvl),
       util.clean_text(prscrbr_geo_desc),
       util.clean_text(brnd_name),
       LOWER(util.clean_text(gnrc_name)),
       SUM(util.to_int(tot_prscrbrs)),
       SUM(util.to_int(tot_clms)),
       SUM(util.to_num(tot_30day_fills)),
       SUM(util.to_num(tot_drug_cst)),
       SUM(util.to_int(tot_benes)),
       MAX(util.to_num(lis_bene_cst_shr)),
       MAX(util.to_num(nonlis_bene_cst_shr)),
       BOOL_OR(util.to_bool(opioid_drug_flag)),
       BOOL_OR(util.to_bool(antbtc_drug_flag))
FROM staging.partd_geo_drug
GROUP BY 1, 2, 3, 4, 5;

-- ---------------------------------------------------------------------------
-- core.monthly_enrollment
-- The file stores YEAR and a MONTH *name*; MONTH = 'Year' rows are annual
-- averages, which we leave out of the monthly table. TO_DATE builds a real
-- first-of-month DATE so we can use date functions downstream.
-- '*' (small-cell suppression) becomes NULL via util.to_int().
-- ---------------------------------------------------------------------------
INSERT INTO core.monthly_enrollment
SELECT UPPER(TRIM(bene_state_abrvtn)),
       TO_DATE(TRIM(year) || '-' || TRIM(month) || '-01', 'YYYY-FMMonth-DD'),
       util.to_int(tot_benes),
       util.to_int(orgnl_mdcr_benes),
       util.to_int(ma_and_oth_benes),
       util.to_int(aged_tot_benes),
       util.to_int(dsbld_tot_benes),
       util.to_int(dual_tot_benes),
       util.to_int(prscrptn_drug_tot_benes)
FROM staging.monthly_enrollment
WHERE TRIM(month) <> 'Year'
  AND UPPER(TRIM(bene_state_abrvtn)) NOT IN ('FO', 'UK')
  AND util.to_int(tot_benes) > 0;
