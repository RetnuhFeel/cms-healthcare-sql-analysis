-- Q01. Which diabetes drug classes drive Medicare Part D spending in Tennessee?
-- Business ask: "Finance wants to know where the diabetes drug dollars go."
-- Skills: GROUP BY, SUM() OVER () for percent of total, ROUND, ORDER BY
SELECT drug_class,
       COUNT(DISTINCT npi)                                       AS prescribers,
       SUM(total_claims)                                         AS claims,
       ROUND(SUM(total_drug_cost) / 1e6, 1)                      AS drug_cost_millions,
       ROUND(100.0 * SUM(total_drug_cost)
             / SUM(SUM(total_drug_cost)) OVER (), 1)             AS pct_of_diabetes_spend,
       ROUND(100.0 * SUM(total_claims)
             / SUM(SUM(total_claims)) OVER (), 1)                AS pct_of_diabetes_claims
FROM mart.v_diabetes_prescribing
GROUP BY drug_class
ORDER BY drug_cost_millions DESC;
