-- Q16. Do hospital star ratings differ by ownership type? Tennessee vs the U.S.
-- Skills: GROUP BY ROLLUP for a grand-total row, COALESCE on the rollup NULL,
--         AVG ignoring NULL ratings, COUNT ... FILTER, NULLIF
-- Scope: general acute care and critical access hospitals (the ones CMS star-rates).
SELECT COALESCE(ownership_group, 'All ownership types')                         AS ownership_group,
       COUNT(*) FILTER (WHERE state_code = 'TN')                                  AS tn_hospitals,
       COUNT(overall_rating) FILTER (WHERE state_code = 'TN')                     AS tn_rated,
       ROUND(AVG(overall_rating) FILTER (WHERE state_code = 'TN'), 2)             AS tn_avg_stars,
       COUNT(*)                                                                   AS us_hospitals,
       COUNT(overall_rating)                                                      AS us_rated,
       ROUND(AVG(overall_rating), 2)                                              AS us_avg_stars,
       ROUND(100.0 * COUNT(*) FILTER (WHERE overall_rating >= 4)
             / NULLIF(COUNT(overall_rating), 0), 1)                               AS us_pct_4_or_5_stars
FROM core.hospital
WHERE hospital_type IN ('Acute Care Hospitals', 'Critical Access Hospitals')
GROUP BY ROLLUP (ownership_group)
ORDER BY (ownership_group IS NULL) DESC, us_hospitals DESC;
