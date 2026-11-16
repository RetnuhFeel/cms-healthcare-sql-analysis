-- =============================================================================
-- 01_reference.sql  - lookup tables
-- =============================================================================

-- Diabetes drug classes: lower-case + trim the join key so it matches CMS
-- generic names regardless of capitalization or stray spaces.
INSERT INTO ref.diabetes_drug_class (generic_name, drug_class, is_combination)
SELECT DISTINCT ON (LOWER(util.clean_text(gnrc_name)))
       LOWER(util.clean_text(gnrc_name)),
       util.clean_text(drug_class),
       util.to_bool(is_combination)
FROM staging.diabetes_drug_class
WHERE util.clean_text(gnrc_name) IS NOT NULL
ORDER BY LOWER(util.clean_text(gnrc_name));

-- States: taken from the enrollment file (50 states + DC + territories),
-- skipping the 'US' national total and the 'FO' (foreign) / 'UK' (unknown) buckets.
INSERT INTO ref.state (state_code, state_name)
SELECT DISTINCT UPPER(TRIM(bene_state_abrvtn)), util.clean_text(bene_state_desc)
FROM staging.monthly_enrollment
WHERE bene_geo_lvl = 'State'
  AND UPPER(TRIM(bene_state_abrvtn)) NOT IN ('US', 'FO', 'UK');
