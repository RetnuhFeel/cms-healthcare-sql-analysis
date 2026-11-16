-- Q03. Who writes GLP-1 / GIP prescriptions (Ozempic, Mounjaro, Trulicity ...)?
--      Are nurse practitioners and PAs a big part of it?
-- Skills: CASE inside aggregates, HAVING, percent of total
SELECT specialty_group,
       COUNT(DISTINCT npi)                                              AS prescribers,
       SUM(total_claims)                                                AS glp1_claims,
       ROUND(100.0 * SUM(total_claims) / SUM(SUM(total_claims)) OVER (), 1) AS pct_of_glp1_claims,
       ROUND(1.0 * SUM(total_claims) / COUNT(DISTINCT npi), 0)          AS claims_per_prescriber
FROM mart.v_diabetes_prescribing
WHERE class_family = 'GLP-1 / GIP'
GROUP BY specialty_group
HAVING COUNT(DISTINCT npi) >= 20          -- ignore groups too small to compare
ORDER BY glp1_claims DESC;
