-- Q10. Semaglutide (Ozempic/Rybelsus/Wegovy) and tirzepatide (Mounjaro/Zepbound):
--      claims, cost per claim and YoY growth in Tennessee, using the stored function.
-- Skills: calling a set-returning SQL function, UNION ALL, string literals
SELECT 'semaglutide' AS generic_name, t.*
FROM mart.drug_trend('semaglutide', 'Tennessee') t
UNION ALL
SELECT 'tirzepatide', t.*
FROM mart.drug_trend('tirzepatide', 'Tennessee') t
ORDER BY generic_name, data_year;
