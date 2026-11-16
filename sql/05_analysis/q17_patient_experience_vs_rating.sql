-- Q17. In Tennessee, does patient experience (HCAHPS) line up with the CMS overall
--      star rating? And how many hospitals have no survey results at all?
-- Skills: LEFT JOIN to a view, CORR(), COUNT with CASE, grouping by a rating
SELECT COALESCE(overall_rating::TEXT, 'Not rated')                   AS cms_overall_rating,
       COUNT(*)                                                      AS hospitals,
       COUNT(hcahps_summary_stars)                                   AS with_hcahps_stars,
       ROUND(AVG(hcahps_summary_stars), 2)                           AS avg_hcahps_stars,
       ROUND(AVG(pct_definitely_recommend), 1)                       AS avg_pct_definitely_recommend,
       SUM(CASE WHEN completed_surveys IS NULL THEN 1 ELSE 0 END)    AS no_survey_data,
       (SELECT ROUND(CORR(overall_rating, hcahps_summary_stars)::NUMERIC, 2)
        FROM mart.v_hospital_patient_experience
        WHERE state_code = 'TN')                                     AS corr_rating_vs_hcahps_tn
FROM mart.v_hospital_patient_experience
WHERE state_code = 'TN'
GROUP BY overall_rating
ORDER BY overall_rating NULLS LAST;
