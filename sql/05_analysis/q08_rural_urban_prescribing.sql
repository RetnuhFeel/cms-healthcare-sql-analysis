-- Q08. Do rural prescribers use newer diabetes drugs (GLP-1 / GIP, SGLT2) as often as
--      metro prescribers?
-- Skills: CASE buckets, conditional aggregation with FILTER, COALESCE for unknowns
SELECT COALESCE(geography, 'Unknown')                                      AS geography,
       COUNT(DISTINCT npi)                                                 AS prescribers,
       SUM(total_claims)                                                   AS diabetes_claims,
       ROUND(100.0 * SUM(total_claims) FILTER (WHERE class_family = 'GLP-1 / GIP')
             / SUM(total_claims), 1)                                       AS pct_glp1_gip,
       ROUND(100.0 * SUM(total_claims) FILTER (WHERE drug_class = 'SGLT2 inhibitor')
             / SUM(total_claims), 1)                                       AS pct_sglt2,
       ROUND(100.0 * SUM(total_claims) FILTER (WHERE drug_class IN ('Sulfonylurea', 'Biguanide (metformin)'))
             / SUM(total_claims), 1)                                       AS pct_metformin_or_su,
       ROUND(SUM(total_drug_cost) / SUM(total_claims), 0)                  AS avg_cost_per_claim
FROM mart.v_diabetes_prescribing
WHERE class_family <> 'Supplies'
GROUP BY COALESCE(geography, 'Unknown')
ORDER BY prescribers DESC;
