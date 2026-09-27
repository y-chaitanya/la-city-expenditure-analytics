-- ====================================================================
-- COMPONENT 1: DUPLICATE PAYMENT TEST (PAYMENT-LEVEL)
-- ====================================================================
-- OBJECTIVE: Identify the same vendor, date and amount appearing under two or
--            more distinct payments.
--
-- UNIT OF ANALYSIS: The dataset publishes one row per accounting distribution
--            line (see "INV LINE" and "INVOICE DISTRIBUTION LINE" below), so a
--            single payment can appear as several rows sharing one TRANSACTION
--            ID. Counting rows therefore flags the City's accounting structure
--            as duplicate spend. This test counts distinct TRANSACTION IDs.
--
-- RESULT: 18,973 groups covering 63,853 distinct payments (28.4% of the
--            224,851 payments in the population). Counting rows instead
--            returned 59,482 groups covering 230,675 rows.
--
-- SCHEMA REFERENCE (Checkbook_LA):
-- CREATE TABLE "Checkbook_LA" ( 
--     "FISCAL YEAR" INTEGER, "DEPARTMENT NAME" TEXT, "VENDOR NAME" TEXT, 
--     "TRANSACTION DATE" TEXT, "DOLLAR AMOUNT" TEXT, "AUTHORITY" TEXT, 
--     "BUSINESS TAX REGISTRATION CERTIFICATE" INTEGER, "GOVERNMENT ACTIVITY" TEXT, 
--     "FUND GROUP NAME" TEXT, "FUND TYPE" TEXT, "FUND NAME" TEXT, "FUND" TEXT, 
--     "ACCOUNT NAME" TEXT, "ACCOUNT CODE" TEXT, "TRANSACTION ID" TEXT, 
--     "EXPENDITURE TYPE" TEXT, "SETTLEMENT/JUDGMENT" TEXT, "FISCAL MONTH NUMBER" INTEGER, 
--     "FISCAL YEAR-MONTH" TEXT, "FISCAL YEAR-QUARTER" TEXT, "CALENDAR MONTH NUMBER" INTEGER, 
--     "CALENDAR MONTH/YEAR" TEXT, "CALENDAR MONTH" TEXT, "DATA SOURCE" TEXT, 
--     "AUTHORITY NAME" TEXT, "AUTHORITY LINK" TEXT, "DEPARTMENT NUMBER" INTEGER, 
--     "PROGRAM" TEXT, "VENDOR ID" TEXT, "ZIP" TEXT, "PAYMENT METHOD" TEXT, 
--     "PAYMENT STATUS" TEXT, "INV NUM" TEXT, "INVOICE DUE DATE" TEXT, 
--     "INVOICE DISCOUNT DUE DATE" TEXT, "INV DATE" TEXT, "INV LINE" INTEGER, 
--     "INVOICE DISTRIBUTION LINE" INTEGER, "PO NUM" TEXT, "DESCRIPTION" TEXT, 
--     "DETAILED ITEM DESCRIPTION" TEXT, "UNIT PRICE" TEXT, "UNIT OF MEASURE" TEXT, 
--     "QUANTITY" INTEGER, "SALES TAX PERCENT" INTEGER, "SALES TAX" TEXT, 
--     "DISCOUNT" TEXT, "RECEIVER ID" TEXT, "PO DATE" TEXT, "PO LINE NUMBER" INTEGER, 
--     "PROCUREMENT ORGANIZATION" TEXT, "BUYER NAME" TEXT, "SUPPLIER CITY" TEXT, 
--     "SUPPLIER COUNTRY" TEXT, "BU NAME" TEXT, "SITE LOCATION" TEXT, 
--     "ITEM CODE" TEXT, "ITEM CODE NAME" TEXT, "CURRENCY" TEXT, "VALUE OF SPEND" TEXT, 
--     "VENDOR NUM" TEXT 
-- );
-- ====================================================================

SELECT
    "VENDOR NAME",
    "TRANSACTION DATE",
    "DOLLAR AMOUNT",
    COUNT(*)                          AS rows_found,
    COUNT(DISTINCT "TRANSACTION ID")  AS distinct_payments
FROM Checkbook_LA
WHERE "VENDOR NAME" IS NOT NULL
GROUP BY "VENDOR NAME", "TRANSACTION DATE", "DOLLAR AMOUNT"
HAVING COUNT(DISTINCT "TRANSACTION ID") > 1
ORDER BY distinct_payments DESC;
