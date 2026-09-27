-- ====================================================================
-- COMPONENT 3: SAME-DAY SUB-THRESHOLD CLUSTERS (PAYMENT-LEVEL)
-- ====================================================================
-- OBJECTIVE: Identify vendors paid more than once on the same day in the
--            $4,800.00-$4,999.99 band, immediately below a commonly used
--            $5,000 approval threshold.
--
-- UNIT OF ANALYSIS: Counts distinct TRANSACTION IDs, not rows. Counting rows
--            here flagged a single $74,400 payment distributed across 15
--            service locations as though it were 15 separate payments.
--
-- THRESHOLD CAVEAT: $5,000 is a working assumption, not a verified figure.
--            The applicable City threshold, and the rules on aggregating
--            related purchases, would need to be confirmed against the
--            Administrative Code before any conclusion about threshold
--            evasion could be drawn.
--
-- RESULT: 101 groups covering 268 distinct payments (0.12% of the 224,851
--            payments in the population).
--
-- LIMITATION: Detects same-day splits only. See 03b for the 7-day window.
-- ====================================================================

SELECT
    "VENDOR NAME",
    "TRANSACTION DATE",
    COUNT(*)                          AS rows_found,
    COUNT(DISTINCT "TRANSACTION ID")  AS distinct_payments,
    GROUP_CONCAT(DISTINCT "DOLLAR AMOUNT") AS amounts
FROM Checkbook_LA
WHERE "VENDOR NAME" IS NOT NULL
  -- Redacted payees ('PRIVACY-<DEPARTMENT>') are anonymized individuals,
  -- not vendors. Excluded here to match Tests 1 and 2.
  AND "VENDOR NAME" NOT LIKE 'PRIVACY-%'
  AND CAST(REPLACE(REPLACE("DOLLAR AMOUNT", '$', ''), ',', '') AS REAL) BETWEEN 4800.00 AND 4999.99
GROUP BY "VENDOR NAME", "TRANSACTION DATE"
HAVING COUNT(DISTINCT "TRANSACTION ID") > 1
ORDER BY distinct_payments DESC;
