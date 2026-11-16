-- Q14. Which states grew Medicare enrollment fastest from January 2019 to the
--      latest month available, and where does Tennessee rank?
-- Skills: subquery for the latest date, self-join on two snapshots,
--         RANK and PERCENT_RANK, ref-table join for names
WITH latest AS (
    SELECT MAX(month_start) AS m FROM core.monthly_enrollment
),
growth AS (
    SELECT s.state_code,
           st.state_name,
           b.total_benes                                         AS benes_jan_2019,
           e.total_benes                                         AS benes_latest,
           ROUND(100.0 * (e.total_benes - b.total_benes) / b.total_benes, 1) AS growth_pct
    FROM (SELECT DISTINCT state_code FROM core.monthly_enrollment) s
    JOIN ref.state st                ON st.state_code = s.state_code
    JOIN core.monthly_enrollment b   ON b.state_code = s.state_code AND b.month_start = DATE '2019-01-01'
    JOIN core.monthly_enrollment e   ON e.state_code = s.state_code
                                    AND e.month_start = (SELECT m FROM latest)
    WHERE s.state_code NOT IN ('PR', 'VI', 'GU', 'AS', 'MP')   -- 50 states + DC
),
ranked AS (
    SELECT RANK() OVER (ORDER BY growth_pct DESC)                       AS growth_rank,
           state_code, state_name, benes_jan_2019, benes_latest, growth_pct,
           ROUND(100 * PERCENT_RANK() OVER (ORDER BY growth_pct)::NUMERIC, 0) AS percentile,
           COUNT(*) OVER ()                                              AS states_ranked
    FROM growth
)
-- Top 10 plus Tennessee, wherever it lands
SELECT growth_rank, state_code, state_name, benes_jan_2019, benes_latest, growth_pct,
       percentile, states_ranked,
       TO_CHAR((SELECT m FROM latest), 'Mon YYYY')                      AS latest_month
FROM ranked
WHERE growth_rank <= 10 OR state_code = 'TN'
ORDER BY growth_rank;
