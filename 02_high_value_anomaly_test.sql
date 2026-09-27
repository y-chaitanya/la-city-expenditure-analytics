-- ====================================================================
-- COMPONENT 2: HIGH-VALUE MATERIALITY FILTER (PAYMENT-LEVEL)
-- ====================================================================
-- OBJECTIVE: Restrict the duplicate payment test to payments of $10,000 or
--            more, producing a population small enough for substantive review.
--
-- UNIT OF ANALYSIS: Counts distinct TRANSACTION IDs, not rows. See Test 1.
--
-- DATA NOTE: "DOLLAR AMOUNT" is stored as formatted text ("$9,000,000.00"),
--            so it is stripped of currency symbols and separators and cast to
--            REAL before any numeric comparison.
--
-- RESULT: 613 groups covering 1,680 distinct payments (0.75% of the 224,851
--            payments in the population). This is a materiality-filtered
--            subset of Test 1, not an additional exception population.
-- ====================================================================

SELECT
    "VENDOR NAME",
    "TRANSACTION DATE",
    "DOLLAR AMOUNT",
    COUNT(*)                          AS rows_found,
    COUNT(DISTINCT "TRANSACTION ID")  AS distinct_payments,
    SUM(CAST(REPLACE(REPLACE("DOLLAR AMOUNT", '$', ''), ',', '') AS REAL)) AS total_exposure
FROM Checkbook_LA
WHERE "VENDOR NAME" IS NOT NULL
  AND CAST(REPLACE(REPLACE("DOLLAR AMOUNT", '$', ''), ',', '') AS REAL) >= 10000.00
GROUP BY "VENDOR NAME", "TRANSACTION DATE", "DOLLAR AMOUNT"
HAVING COUNT(DISTINCT "TRANSACTION ID") > 1
ORDER BY total_exposure DESC;
