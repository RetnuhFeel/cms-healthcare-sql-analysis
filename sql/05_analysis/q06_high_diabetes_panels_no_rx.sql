-- Q06. Care-gap screen: primary care clinicians whose Medicare panel is at least
--      40% diabetic, but who have NO diabetes-drug rows in Part D.
-- Skills: anti-join with NOT EXISTS, LEFT JOIN ... IS NULL, CASE
-- Note: CMS only publishes prescriber-drug rows with 11+ claims, so "no rows"
--       means "fewer than 11 claims of every diabetes drug", not literally zero.
WITH diabetic_panels AS (
    SELECT p.npi, p.specialty, p.geography, b.total_beneficiaries, b.pct_bene_diabetes
    FROM core.physician_utilization b
    JOIN core.provider p ON p.npi = b.npi
    WHERE b.pct_bene_diabetes >= 40
      AND mart.specialty_group(p.specialty) IN ('Primary care physician', 'NP / PA')
)
SELECT dp.specialty,
       COUNT(*)                                                     AS clinicians_40pct_diabetic,
       COUNT(*) FILTER (WHERE NOT EXISTS (
           SELECT 1 FROM core.partd_prescriber_drug x WHERE x.npi = dp.npi))  AS no_diabetes_rx_rows,
       COUNT(*) FILTER (WHERE pd.npi IS NULL)                        AS not_in_part_d_at_all,
       ROUND(100.0 * COUNT(*) FILTER (WHERE NOT EXISTS (
           SELECT 1 FROM core.partd_prescriber_drug x WHERE x.npi = dp.npi)) / COUNT(*), 1) AS pct_without_rx
FROM diabetic_panels dp
LEFT JOIN core.partd_prescriber pd ON pd.npi = dp.npi
GROUP BY dp.specialty
ORDER BY clinicians_40pct_diabetic DESC;
