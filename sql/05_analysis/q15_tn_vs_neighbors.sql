-- Q15. Tennessee vs its neighbors: enrollment growth since Jan 2019 and Medicare
--      Advantage share in the latest month.
-- Skills: IN list, scalar subquery, ordering by a derived column, DENSE_RANK
WITH latest AS (SELECT MAX(month_start) AS m FROM core.monthly_enrollment),
snap AS (
    SELECT e.state_code,
           MAX(e.total_benes) FILTER (WHERE e.month_start = DATE '2019-01-01')   AS benes_2019,
           MAX(e.total_benes) FILTER (WHERE e.month_start = (SELECT m FROM latest)) AS benes_latest,
           MAX(ROUND(100.0 * e.medicare_advantage_benes / e.total_benes, 1))
               FILTER (WHERE e.month_start = (SELECT m FROM latest))             AS ma_share_latest
    FROM core.monthly_enrollment e
    WHERE e.state_code IN ('TN', 'KY', 'VA', 'NC', 'GA', 'AL', 'MS', 'AR', 'MO', 'US')
    GROUP BY e.state_code
)
SELECT state_code,
       benes_2019,
       benes_latest,
       ROUND(100.0 * (benes_latest - benes_2019) / benes_2019, 1)      AS growth_pct,
       ma_share_latest,
       DENSE_RANK() OVER (ORDER BY ma_share_latest DESC)               AS ma_share_rank
FROM snap
ORDER BY ma_share_latest DESC;
