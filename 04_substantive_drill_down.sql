-- ====================================================================
-- COMPONENT 4: SUBSTANTIVE METADATA DRILL-DOWNS
-- ====================================================================
-- OBJECTIVE: Examine the three largest exceptions by dollar exposure against
--            fund, account, purchase order and invoice metadata, and establish
--            whether each represents separate payments or one payment
--            distributed across accounting lines.
--
-- FINDINGS:
--   Konica Minolta   10/02/2025  $6.72      693 rows ->  11 payments
--   Wells Fargo      05/01/2026  $9,000,000  49 rows ->  49 payments
--   United Site Svc  10/30/2025  $4,960.00   15 rows ->   1 payment
--
--   Two of the three dissolved once payments were counted instead of rows.
--   The largest by dollar value, Wells Fargo, did not.
-- ====================================================================


-- --------------------------------------------------------------------
-- 4.1  Rows against payments for the three flagged vendors
-- --------------------------------------------------------------------
SELECT
    "VENDOR NAME",
    "TRANSACTION DATE",
    "DOLLAR AMOUNT",
    COUNT(*)                          AS rows_found,
    COUNT(DISTINCT "TRANSACTION ID")  AS distinct_payments,
    SUM(CAST(REPLACE(REPLACE("DOLLAR AMOUNT", '$', ''), ',', '') AS REAL)) AS row_total
FROM Checkbook_LA
WHERE "VENDOR NAME" LIKE '%KONICA%'
   OR "VENDOR NAME" LIKE '%WELLS FARGO%'
   OR "VENDOR NAME" LIKE '%UNITED SITE%'
GROUP BY "VENDOR NAME", "TRANSACTION DATE", "DOLLAR AMOUNT"
HAVING COUNT(*) > 1
ORDER BY row_total DESC;


-- --------------------------------------------------------------------
-- 4.2  Konica Minolta: 693 lines, 11 payments
--      Expectation: distribution lines across many departments, few invoices.
-- --------------------------------------------------------------------
SELECT
    "TRANSACTION ID",
    COUNT(*)                            AS distribution_lines,
    COUNT(DISTINCT "DEPARTMENT NAME")   AS departments,
    COUNT(DISTINCT "FUND NAME")         AS funds,
    MIN("INV NUM")                      AS invoice_number,
    MIN("DETAILED ITEM DESCRIPTION")    AS item_description
FROM Checkbook_LA
WHERE "VENDOR NAME" LIKE '%KONICA%'
  AND "TRANSACTION DATE" = '10/02/2025'
  AND "DOLLAR AMOUNT" = '$6.72'
GROUP BY "TRANSACTION ID"
ORDER BY distribution_lines DESC;


-- --------------------------------------------------------------------
-- 4.3  Wells Fargo: 49 lines, 49 payments
--      Expectation: separate payments, distinct invoice references,
--      assigned to revenue funds rather than operating budgets.
-- --------------------------------------------------------------------
SELECT
    "TRANSACTION ID",
    "FUND NAME",
    "ACCOUNT NAME",
    "INV NUM",
    "DOLLAR AMOUNT"
FROM Checkbook_LA
WHERE "VENDOR NAME" LIKE '%WELLS FARGO%'
  AND "TRANSACTION DATE" = '05/01/2026'
  AND "DOLLAR AMOUNT" = '$9,000,000.00'
ORDER BY "INV NUM";


-- --------------------------------------------------------------------
-- 4.4  United Site Services: 15 lines, 1 payment
--      Expectation: one invoice under a master contract purchase order,
--      distributed across service locations.
-- --------------------------------------------------------------------
SELECT
    "TRANSACTION ID",
    "PO NUM",
    "INV NUM",
    "SITE LOCATION",
    "DETAILED ITEM DESCRIPTION",
    "DOLLAR AMOUNT"
FROM Checkbook_LA
WHERE "VENDOR NAME" LIKE '%UNITED SITE%'
  AND "TRANSACTION DATE" = '10/30/2025'
  AND "DOLLAR AMOUNT" = '$4,960.00'
ORDER BY "SITE LOCATION";
