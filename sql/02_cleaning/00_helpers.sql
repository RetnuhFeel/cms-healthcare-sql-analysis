-- =============================================================================
-- 00_helpers.sql
-- Small reusable cleaning functions. Plain SQL functions, IMMUTABLE so they can
-- be inlined by the planner.
-- =============================================================================
DROP SCHEMA IF EXISTS util CASCADE;
CREATE SCHEMA util;

-- Turn a CMS text value into NUMERIC.
-- Blank strings, suppression markers ('*', '#') and phrases such as
-- 'Not Available' / 'Not Applicable' become NULL instead of raising an error.
CREATE FUNCTION util.to_num(raw TEXT)
RETURNS NUMERIC
LANGUAGE sql IMMUTABLE
AS $$
    SELECT CASE
             WHEN REPLACE(TRIM(raw), ',', '') ~ '^-?[0-9]+(\.[0-9]+)?$'
             THEN REPLACE(TRIM(raw), ',', '')::NUMERIC
           END;
$$;

-- Same idea for whole numbers.
CREATE FUNCTION util.to_int(raw TEXT)
RETURNS INTEGER
LANGUAGE sql IMMUTABLE
AS $$
    SELECT ROUND(util.to_num(raw))::INTEGER;
$$;

-- Trim and convert empty strings to NULL.
CREATE FUNCTION util.clean_text(raw TEXT)
RETURNS TEXT
LANGUAGE sql IMMUTABLE
AS $$
    SELECT NULLIF(REGEXP_REPLACE(TRIM(raw), '\s+', ' ', 'g'), '');
$$;

-- Map Yes/Y/No/N style flags to BOOLEAN (anything else -> NULL).
CREATE FUNCTION util.to_bool(raw TEXT)
RETURNS BOOLEAN
LANGUAGE sql IMMUTABLE
AS $$
    SELECT CASE UPPER(TRIM(raw))
             WHEN 'Y' THEN TRUE  WHEN 'YES' THEN TRUE
             WHEN 'N' THEN FALSE WHEN 'NO'  THEN FALSE
           END;
$$;
