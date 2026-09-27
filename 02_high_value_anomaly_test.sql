-- =====================================================================
-- TEST 2: HIGH-VALUE DUPLICATE PAYMENT CANDIDATES
-- =====================================================================
-- Objective:  Isolate the subset of Test 1 exceptions at or above
--             $10,000, so that review effort is directed by exposure
--             rather than by count.
--
-- Note:       This is a filtered view of Test 1, not an independent
--             test. Every group returned here also appears there.
--
-- Unit of analysis: TRANSACTION ID (a payment). Each payment may be
--             published across multiple accounting distribution lines,
--             so COUNT(*) counts lines and COUNT(DISTINCT
--             "TRANSACTION ID") counts payments. Only the latter is
--             meaningful. Both are reported so the ratio is visible.
-- =====================================================================

SELECT
    "VENDOR NAME",
    "TRANSACTION DATE",
    "DOLLAR AMOUNT",
    COUNT(*)                          AS rows_found,
    COUNT(DISTINCT "TRANSACTION ID")  AS distinct_payments,
    COUNT(DISTINCT "TRANSACTION ID")
        * CAST(REPLACE(REPLACE("DOLLAR AMOUNT", '$', ''), ',', '') AS REAL)
                                      AS payment_level_exposure
FROM Checkbook_LA
WHERE "VENDOR NAME" IS NOT NULL

  -- Redacted payees ('PRIVACY-<DEPARTMENT>') are anonymized individuals,
  -- not vendors. Excluded here to match Test 1.
  AND "VENDOR NAME" NOT LIKE 'PRIVACY-%'

  -- Materiality filter.
  AND CAST(REPLACE(REPLACE("DOLLAR AMOUNT", '$', ''), ',', '') AS REAL) >= 10000.00

GROUP BY "VENDOR NAME", "TRANSACTION DATE", "DOLLAR AMOUNT"
HAVING COUNT(DISTINCT "TRANSACTION ID") > 1
ORDER BY payment_level_exposure DESC;
