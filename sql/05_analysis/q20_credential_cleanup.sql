-- Q20. How messy were the raw credential strings, and what is the clinician mix
--      once they are standardized?
-- Skills: string functions (UPPER, REGEXP_REPLACE, SPLIT_PART, LIKE),
--         comparing raw vs cleaned values, COUNT DISTINCT
WITH raw AS (
    SELECT rndrng_npi AS npi, rndrng_prvdr_crdntls AS raw_credential
    FROM staging.physician_provider
    WHERE rndrng_prvdr_ent_cd = 'I'
),
cleaned AS (
    SELECT npi,
           raw_credential,
           -- 'M.D.' -> 'MD', 'MD, PHD' -> 'MD' (keep the first credential listed)
           SPLIT_PART(REGEXP_REPLACE(UPPER(COALESCE(raw_credential, '')), '[.\s]', '', 'g'), ',', 1) AS first_credential
    FROM raw
)
SELECT CASE
           WHEN first_credential = ''                                   THEN 'Missing'
           WHEN first_credential IN ('MD', 'DO')                        THEN first_credential || ' (physician)'
           WHEN first_credential LIKE '%NP%' OR first_credential LIKE 'APRN%'
             OR first_credential LIKE 'APN%'                            THEN 'Nurse practitioner'
           WHEN first_credential LIKE 'PA%'                             THEN 'Physician assistant'
           WHEN first_credential LIKE 'CRNA%'                           THEN 'Nurse anesthetist'
           WHEN first_credential IN ('DPT', 'PT', 'MPT')                THEN 'Physical therapist'
           ELSE 'Other'
       END                                        AS credential_group,
       COUNT(*)                                   AS clinicians,
       COUNT(DISTINCT raw_credential)             AS raw_spellings,
       COUNT(DISTINCT first_credential)           AS cleaned_spellings,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_clinicians
FROM cleaned
GROUP BY 1
ORDER BY clinicians DESC;
