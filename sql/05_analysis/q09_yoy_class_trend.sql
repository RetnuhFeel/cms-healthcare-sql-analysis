-- Q09. How fast has Tennessee Part D spending grown for each diabetes drug family
--      from 2019 to 2024, compared with the nation?
-- Skills: LAG() for year-over-year change, CTEs, joining to a lookup, PARTITION BY
WITH family_year AS (
    SELECT g.geo_name,
           g.data_year,
           CASE
               WHEN c.drug_class IN ('GLP-1 receptor agonist', 'GIP/GLP-1 receptor agonist') THEN 'GLP-1 / GIP'
               WHEN c.drug_class = 'SGLT2 inhibitor'                                       THEN 'SGLT2'
               WHEN c.drug_class LIKE 'Insulin%' AND c.drug_class <> 'Insulin delivery supplies' THEN 'Insulin'
               ELSE 'Other'
           END                     AS drug_family,
           SUM(g.total_drug_cost)  AS drug_cost
    FROM core.partd_geo_drug g
    JOIN ref.diabetes_drug_class c ON c.generic_name = g.generic_name
    WHERE g.geo_name IN ('Tennessee', 'National')
    GROUP BY 1, 2, 3
)
SELECT geo_name,
       drug_family,
       data_year,
       ROUND(drug_cost / 1e6, 1)                                            AS drug_cost_millions,
       ROUND(100.0 * (drug_cost - LAG(drug_cost) OVER w)
             / NULLIF(LAG(drug_cost) OVER w, 0), 1)                         AS yoy_change_pct
FROM family_year
WHERE drug_family IN ('GLP-1 / GIP', 'SGLT2', 'Insulin')
WINDOW w AS (PARTITION BY geo_name, drug_family ORDER BY data_year)
ORDER BY geo_name DESC, drug_family, data_year;
