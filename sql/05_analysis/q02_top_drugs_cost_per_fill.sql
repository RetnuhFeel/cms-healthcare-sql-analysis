-- Q02. What are the 10 most expensive diabetes drugs, and what does a 30-day supply cost?
-- Skills: aggregation, NULLIF to avoid divide-by-zero, ROW_NUMBER for ranking
WITH drug_totals AS (
    SELECT brand_name,
           generic_name,
           drug_class,
           SUM(total_claims)       AS claims,
           SUM(total_30day_fills)  AS fills_30day,
           SUM(total_drug_cost)    AS drug_cost
    FROM mart.v_diabetes_prescribing
    WHERE class_family <> 'Supplies'
    GROUP BY brand_name, generic_name, drug_class
)
SELECT ROW_NUMBER() OVER (ORDER BY drug_cost DESC)            AS spend_rank,
       brand_name,
       drug_class,
       claims,
       ROUND(drug_cost / 1e6, 1)                              AS drug_cost_millions,
       ROUND(drug_cost / NULLIF(fills_30day, 0), 0)           AS cost_per_30day_fill
FROM drug_totals
ORDER BY spend_rank
LIMIT 10;
