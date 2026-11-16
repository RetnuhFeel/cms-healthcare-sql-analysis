-- =============================================================================
-- load_staging.sql  (psql script)
-- Bulk-load the gzipped sample CSVs into the staging schema with \copy.
-- Run from the repository root:  psql -f scripts/load_staging.sql
-- =============================================================================
\set ON_ERROR_STOP on
\echo 'Loading staging tables ...'

\copy staging.partd_prescriber_drug FROM PROGRAM 'gzip -dc data/sample/partd_prescriber_drug_2024.csv.gz' WITH (FORMAT csv, HEADER true)
\copy staging.partd_prescriber      FROM PROGRAM 'gzip -dc data/sample/partd_prescriber_2024.csv.gz'      WITH (FORMAT csv, HEADER true)
\copy staging.physician_provider    FROM PROGRAM 'gzip -dc data/sample/physician_provider_2024.csv.gz'    WITH (FORMAT csv, HEADER true)
\copy staging.partd_geo_drug        FROM PROGRAM 'gzip -dc data/sample/partd_geo_drug_2019_2024.csv.gz'   WITH (FORMAT csv, HEADER true)
\copy staging.monthly_enrollment    FROM PROGRAM 'gzip -dc data/sample/monthly_enrollment.csv.gz'         WITH (FORMAT csv, HEADER true)
\copy staging.hospital_general_info FROM PROGRAM 'gzip -dc data/sample/hospital_general_info.csv.gz'      WITH (FORMAT csv, HEADER true)
\copy staging.hcahps_hospital       FROM PROGRAM 'gzip -dc data/sample/hcahps_hospital.csv.gz'            WITH (FORMAT csv, HEADER true)
\copy staging.diabetes_drug_class   FROM 'data/reference/diabetes_drug_classes.csv'                       WITH (FORMAT csv, HEADER true)

SELECT 'partd_prescriber_drug' AS staging_table, COUNT(*) AS row_count FROM staging.partd_prescriber_drug
UNION ALL SELECT 'partd_prescriber',      COUNT(*) FROM staging.partd_prescriber
UNION ALL SELECT 'physician_provider',    COUNT(*) FROM staging.physician_provider
UNION ALL SELECT 'partd_geo_drug',        COUNT(*) FROM staging.partd_geo_drug
UNION ALL SELECT 'monthly_enrollment',    COUNT(*) FROM staging.monthly_enrollment
UNION ALL SELECT 'hospital_general_info', COUNT(*) FROM staging.hospital_general_info
UNION ALL SELECT 'hcahps_hospital',       COUNT(*) FROM staging.hcahps_hospital
UNION ALL SELECT 'diabetes_drug_class',   COUNT(*) FROM staging.diabetes_drug_class;
