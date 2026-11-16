-- Q18. Which Tennessee hospitals (300+ completed surveys) have the highest and lowest
--      share of patients who would "definitely recommend" them?
-- Skills: ROW_NUMBER twice (ascending and descending), CTE, string concatenation
WITH eligible AS (
    SELECT hospital_name, city, ownership_group, overall_rating,
           pct_definitely_recommend, completed_surveys
    FROM mart.v_hospital_patient_experience
    WHERE state_code = 'TN'
      AND completed_surveys >= 300
      AND pct_definitely_recommend IS NOT NULL
),
ranked AS (
    SELECT e.*,
           ROW_NUMBER() OVER (ORDER BY pct_definitely_recommend DESC, completed_surveys DESC) AS best_rank,
           ROW_NUMBER() OVER (ORDER BY pct_definitely_recommend ASC,  completed_surveys DESC) AS worst_rank,
           COUNT(*) OVER ()                                                                   AS hospitals_compared
    FROM eligible e
)
SELECT CASE WHEN best_rank <= 5 THEN 'Top 5' ELSE 'Bottom 5' END   AS list,
       INITCAP(hospital_name) || ' (' || city || ')'               AS hospital,
       ownership_group,
       overall_rating,
       pct_definitely_recommend,
       completed_surveys,
       hospitals_compared
FROM ranked
WHERE best_rank <= 5 OR worst_rank <= 5
ORDER BY pct_definitely_recommend DESC;
