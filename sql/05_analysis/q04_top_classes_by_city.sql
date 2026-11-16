-- Q04. In Tennessee's five largest prescribing cities, what are the top 3 diabetes
--      drug classes by claims?
-- Skills: CTEs, RANK() OVER (PARTITION BY ...), filtering on a window result
WITH big_cities AS (
    SELECT city
    FROM mart.v_diabetes_prescribing
    GROUP BY city
    ORDER BY SUM(total_claims) DESC
    LIMIT 5
),
city_class AS (
    SELECT v.city,
           v.drug_class,
           SUM(v.total_claims) AS claims
    FROM mart.v_diabetes_prescribing v
    JOIN big_cities b ON b.city = v.city
    WHERE v.class_family <> 'Supplies'
    GROUP BY v.city, v.drug_class
),
ranked AS (
    SELECT city, drug_class, claims,
           RANK() OVER (PARTITION BY city ORDER BY claims DESC) AS class_rank,
           ROUND(100.0 * claims / SUM(claims) OVER (PARTITION BY city), 1) AS pct_of_city_claims
    FROM city_class
)
SELECT city, class_rank, drug_class, claims, pct_of_city_claims
FROM ranked
WHERE class_rank <= 3
ORDER BY city, class_rank;
