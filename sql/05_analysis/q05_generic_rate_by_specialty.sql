-- Q05. Which specialties have the lowest generic-dispensing rate across ALL Part D drugs?
--      (Generic rate is a classic pharmacy cost-control KPI.)
-- Skills: JOIN, COALESCE, NULLIF, HAVING, ORDER BY a computed column
SELECT p.specialty,
       COUNT(*)                                                         AS prescribers,
       SUM(d.total_claims)                                              AS total_claims,
       ROUND(100.0 * SUM(COALESCE(d.generic_claims, 0))
             / NULLIF(SUM(d.total_claims), 0), 1)                       AS generic_rate_pct,
       ROUND(SUM(d.total_drug_cost) / NULLIF(SUM(d.total_claims), 0), 0) AS avg_cost_per_claim
FROM core.partd_prescriber d
JOIN core.provider p ON p.npi = d.npi
GROUP BY p.specialty
HAVING COUNT(*) >= 50
ORDER BY generic_rate_pct ASC
LIMIT 10;
