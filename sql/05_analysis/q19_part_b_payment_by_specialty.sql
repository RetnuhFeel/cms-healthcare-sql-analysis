-- Q19. Which specialties receive the most Medicare Part B payment in Tennessee,
--      and what does a typical (median) clinician in each specialty receive?
-- Skills: PERCENTILE_CONT (median) WITHIN GROUP, SUM vs median comparison,
--         payment per beneficiary with NULLIF, percent of total
SELECT p.specialty,
       COUNT(*)                                                             AS clinicians,
       ROUND(SUM(b.medicare_payment) / 1e6, 1)                              AS total_payment_millions,
       ROUND(100.0 * SUM(b.medicare_payment) / SUM(SUM(b.medicare_payment)) OVER (), 1) AS pct_of_state_part_b,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY b.medicare_payment)::NUMERIC, 0) AS median_payment_per_clinician,
       ROUND(SUM(b.medicare_payment) / NULLIF(SUM(b.total_beneficiaries), 0), 0) AS payment_per_beneficiary
FROM core.physician_utilization b
JOIN core.provider p ON p.npi = b.npi
WHERE p.entity_type = 'Individual'
GROUP BY p.specialty
ORDER BY total_payment_millions DESC
LIMIT 10;
