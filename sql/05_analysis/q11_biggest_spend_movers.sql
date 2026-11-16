-- Q11. Which drugs (any therapeutic area) added the most Tennessee Part D spending
--      between 2019 and 2024? Flag drugs that did not exist in 2019.
-- Skills: pivot with SUM ... FILTER, COALESCE for missing years, CASE labels
WITH pivoted AS (
    SELECT generic_name,
           SUM(total_drug_cost) FILTER (WHERE data_year = 2019) AS cost_2019,
           SUM(total_drug_cost) FILTER (WHERE data_year = 2024) AS cost_2024
    FROM core.partd_geo_drug
    WHERE geo_name = 'Tennessee'
    GROUP BY generic_name
)
SELECT INITCAP(generic_name)                                        AS generic_name,
       ROUND(COALESCE(cost_2019, 0) / 1e6, 1)                       AS cost_2019_millions,
       ROUND(COALESCE(cost_2024, 0) / 1e6, 1)                       AS cost_2024_millions,
       ROUND((COALESCE(cost_2024, 0) - COALESCE(cost_2019, 0)) / 1e6, 1) AS added_millions,
       CASE WHEN cost_2019 IS NULL THEN 'New since 2019'
            ELSE ROUND(100.0 * (cost_2024 - cost_2019) / cost_2019, 0)::TEXT || '%'
       END                                                          AS growth
FROM pivoted
ORDER BY added_millions DESC
LIMIT 10;
