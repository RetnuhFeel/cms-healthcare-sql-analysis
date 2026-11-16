-- Q13. Tennessee Medicare enrollment, month by month for the last 24 months of data:
--      month-over-month change, same-month-last-year change, and a 12-month average.
-- Skills: date functions (DATE_TRUNC, INTERVAL, TO_CHAR), LAG with offsets,
--         moving average with ROWS BETWEEN
WITH tn AS (
    SELECT month_start, total_benes, medicare_advantage_benes
    FROM core.monthly_enrollment
    WHERE state_code = 'TN'
),
calc AS (
    SELECT month_start,
           total_benes,
           total_benes - LAG(total_benes, 1)  OVER (ORDER BY month_start)  AS mom_change,
           ROUND(100.0 * (total_benes - LAG(total_benes, 12) OVER (ORDER BY month_start))
                 / LAG(total_benes, 12) OVER (ORDER BY month_start), 2)    AS yoy_change_pct,
           ROUND(AVG(total_benes) OVER (ORDER BY month_start
                 ROWS BETWEEN 11 PRECEDING AND CURRENT ROW))               AS rolling_12mo_avg
    FROM tn
)
SELECT TO_CHAR(month_start, 'YYYY-MM') AS month,
       total_benes, mom_change, yoy_change_pct, rolling_12mo_avg
FROM calc
WHERE month_start > (SELECT MAX(month_start) FROM tn) - INTERVAL '24 months'
ORDER BY month_start;
