-- ====================================================================
-- COMPONENT 3b: MULTI-DAY ROLLING WINDOW (PAYMENT-LEVEL)
-- ====================================================================
-- OBJECTIVE: Extend Test 3 beyond same-day splits by pairing sub-threshold
--            payments to the same vendor within a 7-day window.
--
-- UNIT OF ANALYSIS: The CTE selects DISTINCT transaction IDs, so a payment
--            split across several accounting lines enters the join once.
--            An earlier version joined on ROWID and therefore paired
--            accounting lines rather than payments.
--
-- DATE HANDLING: JULIANDAY() requires ISO dates (YYYY-MM-DD). This dataset
--            stores US-format text (MM/DD/YYYY), and JULIANDAY('10/28/2025')
--            returns NULL. An earlier version of this query returned 0 rows
--            for that reason, with no error raised. Dates are reconstructed
--            with SUBSTR inside the CTE.
--
-- PERFORMANCE: The amount band is filtered inside the CTE before the
--            self-join, rather than joining the full population first.
--
-- RESULT: 569 payment pairs involving 553 distinct payments (0.25% of the
--            224,851 payments in the population). A payment can pair with
--            several others, so the pair count exceeds the number of
--            payments involved.
-- ====================================================================

WITH tx AS (
    SELECT
        "TRANSACTION ID" AS txid,
        "VENDOR NAME"    AS vendor,
        SUBSTR("TRANSACTION DATE", 7, 4) || '-' ||
        SUBSTR("TRANSACTION DATE", 1, 2) || '-' ||
        SUBSTR("TRANSACTION DATE", 4, 2) AS iso_date,
        COUNT(*) AS band_lines,
        SUM(CAST(REPLACE(REPLACE("DOLLAR AMOUNT", '$', ''), ',', '') AS REAL)) AS band_total
    FROM Checkbook_LA
    WHERE "VENDOR NAME" IS NOT NULL
      AND CAST(REPLACE(REPLACE("DOLLAR AMOUNT", '$', ''), ',', '') AS REAL) BETWEEN 4800.00 AND 4999.99
    GROUP BY "TRANSACTION ID", "VENDOR NAME", "TRANSACTION DATE"
)
SELECT
    a.vendor,
    a.iso_date AS first_date,
    b.iso_date AS second_date,
    CAST(JULIANDAY(b.iso_date) - JULIANDAY(a.iso_date) AS INT) AS days_between,
    a.band_total AS first_amount,
    b.band_total AS second_amount,
    a.txid       AS first_payment_id,
    b.txid       AS second_payment_id
FROM tx a
JOIN tx b
    ON  a.vendor = b.vendor
    AND a.txid <> b.txid
    AND JULIANDAY(b.iso_date) - JULIANDAY(a.iso_date) BETWEEN 1 AND 7
ORDER BY a.vendor, a.iso_date;
