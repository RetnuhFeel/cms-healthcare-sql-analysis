-- Q12. How has the Medicare Advantage share changed in Tennessee vs the U.S.,
--      and in which year did each first pass 50%?
-- Skills: view over DATE data, EXTRACT, self-referencing CTE, MIN() with FILTER
WITH yearly AS (
    SELECT state_code, calendar_year, months_reported, ma_share_pct
    FROM mart.v_enrollment_annual
    WHERE state_code IN ('TN', 'US')
)
SELECT y.calendar_year,
       MAX(y.ma_share_pct) FILTER (WHERE y.state_code = 'TN') AS tn_ma_share_pct,
       MAX(y.ma_share_pct) FILTER (WHERE y.state_code = 'US') AS us_ma_share_pct,
       MAX(y.months_reported)                                 AS months_in_data,
       (SELECT MIN(calendar_year) FROM yearly WHERE state_code = 'TN' AND ma_share_pct > 50) AS tn_first_year_over_50,
       (SELECT MIN(calendar_year) FROM yearly WHERE state_code = 'US' AND ma_share_pct > 50) AS us_first_year_over_50
FROM yearly y
GROUP BY y.calendar_year
ORDER BY y.calendar_year;
