-- Q07. How concentrated is GLP-1 / GIP spending? What share comes from the
--      top 1%, 5%, 10% and 25% of prescribers?
-- Skills: running total with SUM() OVER (ORDER BY ... ROWS UNBOUNDED PRECEDING),
--         ROW_NUMBER, cumulative percent, CROSS JOIN to a list of cut-offs
WITH by_prescriber AS (
    SELECT npi, SUM(total_drug_cost) AS cost
    FROM mart.v_diabetes_prescribing
    WHERE class_family = 'GLP-1 / GIP'
    GROUP BY npi
),
running AS (
    SELECT npi, cost,
           ROW_NUMBER() OVER (ORDER BY cost DESC)                        AS rn,
           COUNT(*)     OVER ()                                          AS n_prescribers,
           SUM(cost)    OVER (ORDER BY cost DESC, npi ROWS UNBOUNDED PRECEDING) AS running_cost,
           SUM(cost)    OVER ()                                          AS total_cost
    FROM by_prescriber
)
SELECT cut.top_pct                                             AS top_pct_of_prescribers,
       MAX(r.rn)                                               AS prescribers_in_group,
       ROUND(100.0 * MAX(r.running_cost) / MAX(r.total_cost), 1) AS pct_of_glp1_spend
FROM (VALUES (1), (5), (10), (25), (50)) AS cut(top_pct)
JOIN running r ON r.rn <= CEIL(r.n_prescribers * cut.top_pct / 100.0)
GROUP BY cut.top_pct
ORDER BY cut.top_pct;
