-- =============================================================================
-- 04_hospitals.sql
-- Hospital dimension and HCAHPS patient-survey results.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- core.hospital
-- * CCNs and ZIPs are identifiers, not numbers: LPAD keeps leading zeros
--   (Alabama CCNs start with '01').
-- * 'Not Available' ratings -> NULL.
-- * CMS has 12 ownership labels; analysts usually need 5 groups.
-- ---------------------------------------------------------------------------
INSERT INTO core.hospital
SELECT LPAD(util.clean_text(facility_id), 6, '0'),
       util.clean_text(facility_name),
       INITCAP(util.clean_text(city_town)),
       UPPER(TRIM(state)),
       LPAD(util.clean_text(zip_code), 5, '0'),
       INITCAP(util.clean_text(county_parish)),
       util.clean_text(hospital_type),
       CASE
           WHEN hospital_ownership ILIKE 'Voluntary non-profit%'           THEN 'Non-profit'
           WHEN hospital_ownership ILIKE 'Proprietary%'
             OR hospital_ownership ILIKE 'Physician%'                      THEN 'For-profit'
           WHEN hospital_ownership IN ('Government - Federal',
                                       'Veterans Health Administration',
                                       'Department of Defense')            THEN 'Federal government'
           WHEN hospital_ownership ILIKE 'Government%'                     THEN 'State/local government'
           WHEN hospital_ownership ILIKE 'Tribal%'                         THEN 'Tribal'
           ELSE 'Other / unknown'
       END,
       util.clean_text(hospital_ownership),
       util.to_bool(emergency_services),
       COALESCE(util.to_bool(birthing_friendly), FALSE),   -- blank means "not designated"
       util.to_int(hospital_overall_rating)::SMALLINT,
       util.to_int(count_readm_measures_better),
       util.to_int(count_readm_measures_worse),
       util.to_int(count_facility_readm_measures)
FROM staging.hospital_general_info;

-- ---------------------------------------------------------------------------
-- core.hcahps_response
-- Percent / star columns hold either a number or 'Not Applicable' /
-- 'Not Available'. Dates arrive as MM/DD/YYYY text.
-- Only hospitals present in the general-information file are kept (FK).
-- ---------------------------------------------------------------------------
INSERT INTO core.hcahps_response
SELECT LPAD(util.clean_text(h.facility_id), 6, '0'),
       util.clean_text(h.hcahps_measure_id),
       util.clean_text(h.hcahps_question),
       util.clean_text(h.hcahps_answer_description),
       util.to_int(h.patient_survey_star_rating)::SMALLINT,
       util.to_int(h.hcahps_answer_percent)::SMALLINT,
       util.to_int(h.hcahps_linear_mean_value)::SMALLINT,
       util.to_int(h.number_of_completed_surveys),
       util.to_int(h.survey_response_rate_percent)::SMALLINT,
       TO_DATE(h.start_date, 'MM/DD/YYYY'),
       TO_DATE(h.end_date,   'MM/DD/YYYY')
FROM staging.hcahps_hospital h
JOIN core.hospital c ON c.ccn = LPAD(util.clean_text(h.facility_id), 6, '0');
