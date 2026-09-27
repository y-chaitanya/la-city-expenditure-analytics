# City of Los Angeles Expenditure Data Analytics
**Exception Testing & Substantive Drill-Down using SQLite**

> **Scope & Disclaimer Note:** This is an independent data analysis of published open-government expenditure data. It is **not** an audit, was not conducted under Generally Accepted Government Auditing Standards (GAGAS), and was not authorized, sponsored, or reviewed by any City of Los Angeles department. Conclusions are strictly limited to what the published metadata fields support.

---

## Executive Summary

Public expenditure datasets contain repeating line items and high-dollar totals that trigger automated exception flags. Without accounting context, those flags are easily mischaracterized. This project applies deterministic exception tests to the **City of Los Angeles Checkbook dataset** using SQLite, then drills into the largest exceptions to establish what the published metadata can and cannot explain.

The most consequential result was not an exception. It was the discovery that the first version of these tests **counted accounting lines as though they were payments**, and that correcting the unit of analysis removed roughly two-thirds of the exceptions the tests reported.

### Principal Conclusion

**The dataset contains 747,363 accounting lines representing 224,851 distinct payments — an average of 3.3 lines per payment. Counting at the payment level, three exception tests returned 18,973 duplicate-payment groups covering 63,853 payments (28.4%), 613 high-value groups covering 1,680 payments (0.75%), and 101 same-day sub-threshold clusters covering 268 payments (0.12%). The three largest exceptions by dollar exposure were examined against fund, account, purchase order and invoice metadata. Two proved to be single payments distributed across many budget lines; one proved to be 49 genuinely separate payments, explained by the fund and invoice metadata as bond debt service. No control weakness, overpayment, or non-compliance is asserted by this analysis.**

---

## Key Methodological Finding: Lines Are Not Payments

The City publishes each payment as **one row per accounting distribution line**. A single invoice charged against six funds appears as six rows with the same vendor, date and amount.

A duplicate-payment test that groups on vendor, date and amount therefore flags the City's own accounting structure as if it were duplicate spending.

The correction is to count distinct values of `TRANSACTION ID` rather than rows, and to flag a group only when the same vendor, date and amount appear under **two or more different transaction IDs**:

```sql
-- Original: counts accounting lines
HAVING COUNT(*) > 1

-- Corrected: counts payments
HAVING COUNT(DISTINCT "TRANSACTION ID") > 1
```

Effect of the correction on Test 1:

| Measure | Counting lines | Counting payments |
| :--- | ---: | ---: |
| Exception groups | 59,482 | 18,973 |
| Transactions involved | 230,675 | 63,853 |
| Share of population | 30.9% of 747,363 lines | 28.4% of 224,851 payments |

**68% of the groups the original test reported were artefacts of the data's structure**, not candidate duplicates. Every figure below is stated at the payment level.

---

## Dataset Scope & Population Scale

* **Published rows:** 747,363 accounting lines from the *Checkbook LA* open data table.
* **Distinct payments:** 224,851, identified by `TRANSACTION ID` — a ratio of 3.32 lines per payment.
* **Scope:** 100% of the publicly released expenditure records in the dataset. No sampling.
* **Key fields analyzed:** Transaction ID, Vendor Name, Transaction Date, Dollar Amount, Fund Name, Account Name, PO Number, Invoice Number, Detailed Item Description.

---

## Repository Structure

```text
la-city-expenditure-analytics/
├── assets/
│   ├── 01_duplicate_results.png       # Screenshot: Duplicate payment test output
│   ├── 02_high_value_results.png      # Screenshot: Materiality threshold test output
│   ├── 03_structuring_results.png     # Screenshot: Same-day sub-threshold test output
│   ├── 03b_rolling_window_results.png # Screenshot: 7-day rolling window test output
│   ├── 04_drilldown_konica.png        # Screenshot: Konica Minolta allocation metadata
│   ├── 04_drilldown_wellsfargo.png    # Screenshot: Wells Fargo debt service metadata
│   ├── 04_drilldown_results.png       # Screenshot: United Site Services CPO metadata
│   └── dashboard_overview.png         # Screenshot: Exception review interface
├── 01_duplicate_payment_test.sql      # Duplicate payment scanner (payment-level)
├── 02_high_value_anomaly_test.sql     # Materiality filter ($10k+ per payment)
├── 03_sub_materiality_structuring_test.sql # Same-day sub-threshold clusters
├── 03b_rolling_window_structuring.sql      # 7-day rolling window scanner
├── 04_substantive_drill_down.sql      # Metadata drill-downs for the three largest exceptions
├── app.py                             # Streamlit exception review interface
├── requirements.txt                   # Python dependencies
├── .gitignore                         # Excludes the local database and raw CSV
└── README.md                          # This file
```

---

## Exception Tests

### Test 1: Duplicate Payment Scanner (`01_duplicate_payment_test.sql`)

Flags the same vendor, date and amount appearing under more than one transaction ID.

```sql
SELECT "VENDOR NAME", "TRANSACTION DATE", "DOLLAR AMOUNT",
       COUNT(*) AS rows_found,
       COUNT(DISTINCT "TRANSACTION ID") AS distinct_payments
FROM Checkbook_LA
WHERE "VENDOR NAME" IS NOT NULL
GROUP BY "VENDOR NAME", "TRANSACTION DATE", "DOLLAR AMOUNT"
HAVING COUNT(DISTINCT "TRANSACTION ID") > 1
ORDER BY distinct_payments DESC;
```

* **Result:** 18,973 exception groups covering **63,853 distinct payments** — 28.4% of the 224,851 payments in the population.
* **Interpretation:** At this scale the test is a screening filter, not a finding. Recurring obligations of identical value — rent, licences, per-unit service charges — are expected to repeat.

![Test 1 Query Results](./assets/01_duplicate_results.png)

---

### Test 2: High-Value Materiality Filter (`02_high_value_anomaly_test.sql`)

The same test restricted to payments of $10,000 or more. Currency is stored as formatted text and is cast to a numeric type.

```sql
SELECT "VENDOR NAME", "TRANSACTION DATE", "DOLLAR AMOUNT",
       COUNT(DISTINCT "TRANSACTION ID") AS distinct_payments,
       SUM(CAST(REPLACE(REPLACE("DOLLAR AMOUNT", '$', ''), ',', '') AS REAL)) AS total_exposure
FROM Checkbook_LA
WHERE "VENDOR NAME" IS NOT NULL
  AND CAST(REPLACE(REPLACE("DOLLAR AMOUNT", '$', ''), ',', '') AS REAL) >= 10000.00
GROUP BY "VENDOR NAME", "TRANSACTION DATE", "DOLLAR AMOUNT"
HAVING COUNT(DISTINCT "TRANSACTION ID") > 1
ORDER BY total_exposure DESC;
```

* **Result:** 613 exception groups covering **1,680 payments** — 0.75% of the population.
* **Relationship to Test 1:** A materiality-filtered subset of Test 1, not additional exceptions. Not additive.
* **Why this matters:** 1,680 payments is a population a reviewer could work through. That is the practical value of filtering by materiality after correcting the unit of analysis.

![Test 2 Query Results](./assets/02_high_value_results.png)

---

### Test 3: Same-Day Sub-Threshold Clusters (`03_sub_materiality_structuring_test.sql`)

Flags vendors paid more than once on the same day in the $4,800.00–$4,999.99 band, immediately below a commonly used $5,000 approval threshold.

```sql
SELECT "VENDOR NAME", "TRANSACTION DATE",
       COUNT(DISTINCT "TRANSACTION ID") AS distinct_payments,
       GROUP_CONCAT("DOLLAR AMOUNT") AS amounts
FROM Checkbook_LA
WHERE "VENDOR NAME" IS NOT NULL
  AND CAST(REPLACE(REPLACE("DOLLAR AMOUNT", '$', ''), ',', '') AS REAL) BETWEEN 4800.00 AND 4999.99
GROUP BY "VENDOR NAME", "TRANSACTION DATE"
HAVING COUNT(DISTINCT "TRANSACTION ID") > 1
ORDER BY distinct_payments DESC;
```

* **Result:** 101 exception groups covering **268 payments** — 0.12% of the population.
* **Threshold caveat:** $5,000 is a commonly used approval threshold and is used here as a working assumption. The applicable City threshold, and the rules on aggregating related purchases, would need to be confirmed against the Administrative Code before any conclusion about threshold evasion.
* **Limitation:** Same-day splits only. Test 3b extends the window.

![Test 3 Query Results](./assets/03_structuring_results.png)

---

### Test 3b: Multi-Day Rolling Window (`03b_rolling_window_structuring.sql`)

The same band, paired across a 7-day window for the same vendor. Dates are reconstructed into ISO format so `JULIANDAY` arithmetic works.

```sql
WITH tx AS (
  SELECT DISTINCT
    "TRANSACTION ID" AS txid,
    "VENDOR NAME" AS vendor,
    SUBSTR("TRANSACTION DATE", 7, 4) || '-' ||
    SUBSTR("TRANSACTION DATE", 1, 2) || '-' ||
    SUBSTR("TRANSACTION DATE", 4, 2) AS iso_date
  FROM Checkbook_LA
  WHERE "VENDOR NAME" IS NOT NULL
    AND CAST(REPLACE(REPLACE("DOLLAR AMOUNT", '$', ''), ',', '') AS REAL) BETWEEN 4800.00 AND 4999.99
)
SELECT a.vendor, a.iso_date AS first_date, b.iso_date AS second_date,
       CAST(JULIANDAY(b.iso_date) - JULIANDAY(a.iso_date) AS INT) AS days_between
FROM tx a
JOIN tx b ON a.vendor = b.vendor
         AND a.txid <> b.txid
         AND JULIANDAY(b.iso_date) - JULIANDAY(a.iso_date) BETWEEN 1 AND 7
ORDER BY a.vendor, a.iso_date;
```

* **Result:** 569 payment pairs, involving **553 distinct payments** — 0.25% of the population. A payment can pair with several others, so the pair count exceeds the number of payments involved.

![Test 3b Query Results](./assets/03b_rolling_window_results.png)

---

## Technical Notes: Two Failures Worth Recording

### 1. A query that silently returned nothing

The first run of the rolling-window query returned **0 rows** after 5,254 ms. `JULIANDAY()` requires ISO dates (`YYYY-MM-DD`); the dataset stores US-format text (`MM/DD/YYYY`). `JULIANDAY('10/28/2025')` returns `NULL`, so every date comparison evaluated to `NULL` and no rows matched — with no error raised.

A test that cannot detect what it is designed to detect looks identical to a test that found nothing. The fix reconstructs the date inside a CTE:

```sql
SUBSTR("TRANSACTION DATE", 7, 4) || '-' ||
SUBSTR("TRANSACTION DATE", 1, 2) || '-' ||
SUBSTR("TRANSACTION DATE", 4, 2) AS iso_date
```

The query was also refactored to filter the amount band inside the CTE before the self-join, rather than joining the full population first.

### 2. The wrong unit of analysis

The first version of every test counted rows. As set out above, rows are accounting lines, not payments. The error was found by tracing a published figure back to the database and getting a different answer — the totals in an earlier draft of this README did not reconcile to the data they claimed to describe.

Both failures share a property: **neither produced an error message.** One returned zero rows that looked like a clean result; the other returned inflated counts that looked plausible. Reconciling every reported figure to a re-run query is what surfaced them.

---

## Substantive Metadata Drill-Downs

### Case Study 1: Konica Minolta — cost allocation across departments

* **Flagged:** $6.72 appearing on 693 rows dated 10/02/2025, totalling $4,656.96.
* **Resolved:** those 693 rows carry only **11 distinct transaction IDs**. This is 11 invoices distributed across hundreds of departmental budget lines, not 693 payments. The metadata is consistent with an automated cost-allocation routine for shared printing infrastructure. The same pattern repeats at other per-unit rates on the same date ($5.24 across 539 lines, $6.74 across 315 lines).
* *Not verified against master invoices or device logs, which published data does not contain.*

![Konica Minolta Evidence](./assets/04_drilldown_konica.png)

### Case Study 2: Wells Fargo — municipal debt service

* **Flagged:** $9,000,000.00 appearing 49 times on 05/01/2026, totalling $441,000,000.
* **Resolved:** 49 rows carrying **49 distinct transaction IDs** — genuinely separate payments, and the only one of the three cases that survived the payment-level correction unchanged. `FUND NAME`, `ACCOUNT NAME` and `INV NUM` assign them to Water and Power Revenue funds against distinct institutional treasury references. The metadata is consistent with authorized bond principal and interest redemptions through a trustee.
* *Not verified against trustee indentures or wire confirmations, which published data does not contain.*

![Wells Fargo Evidence](./assets/04_drilldown_wellsfargo.png)

### Case Study 3: United Site Services — one invoice, fifteen locations

* **Flagged:** $4,960.00 appearing 15 times on 10/30/2025, totalling $74,400 — flagged by the sub-threshold structuring test.
* **Resolved:** all 15 rows share **a single transaction ID**. This is one payment of $74,400 distributed across 15 service locations under Master Contract Purchase Order `CPO74260000423827`, not fifteen payments engineered below a $5,000 threshold. The vendor's invoices split consistently: other payments to the same vendor appear as six lines each.
* *Not verified against service delivery receipts or the contract file, which published data does not contain.*

![United Site Services Evidence](./assets/04_drilldown_results.png)

---

## Summary of Analytical Findings

| Vendor | Flagged as | Rows | Distinct payments | Exposure | Resolution |
| :--- | :--- | ---: | ---: | ---: | :--- |
| **Wells Fargo Bank** | 49 same-day $9M transactions | 49 | **49** | $441,000,000.00 | **Explained by data:** metadata consistent with authorized debt service and bond redemptions. Genuinely separate payments. |
| **United Site Services** | 15 same-day $4,960 transactions | 15 | **1** | $74,400.00 | **Artefact of line-level counting:** a single payment across 15 service locations under a master CPO. |
| **Konica Minolta** | 693 duplicate $6.72 entries | 693 | **11** | $4,656.96 | **Artefact of line-level counting:** 11 invoices allocated across departmental budget lines. |

Two of the three largest exceptions dissolved once payments were counted instead of lines. The third, and by far the largest in dollar terms, did not.

---

## Interactive Exception Review Interface

A Streamlit application connecting to the local SQLite database (`ap_data.db`). It allows a reviewer to search vendor lines and cross-reference account, fund and invoice metadata without writing SQL. All displayed measures are computed from the database at page load.

### Handling schema drift and date parsing

Two problems surfaced during local deployment, both common in raw open data.

**Schema drift.** The import altered the casing of table and column names and left trailing spaces in some headers (`"VENDOR NAME "` rather than `"VENDOR NAME"`), so hard-coded references failed. The app runs `PRAGMA table_info` at startup and matches column names case- and whitespace-insensitively.

**Date parsing.** Dates are reconstructed into ISO format with `SUBSTR` inside a CTE at query time, for the reason described above.

![Exception Review Interface](./assets/dashboard_overview.png)

---

## What This Open Dataset Cannot Show

1. **Approval workflows** — no sign-off timestamps, secondary approval logs, or delegated authority thresholds.
2. **Source documents** — no invoices, receipts, or cancelled check images.
3. **Contract files** — no contract language, bidding specifications, or amendment histories.
4. **Accounting timestamps** — no distinction between posting date and payment execution date.
5. **Applicable thresholds** — the approval and competitive-bidding limits in force, and the rules for aggregating related purchases.

Any conclusion about whether a control failed would require all five.

---

## How to Execute Locally

### Prerequisites
* SQLite3, or a visual editor such as **DB Browser for SQLite**.
* The City of Los Angeles Checkbook dataset loaded as table `Checkbook_LA` inside `ap_data.db`.

### SQL exception tests
```bash
sqlite3 ap_data.db < 01_duplicate_payment_test.sql
sqlite3 ap_data.db < 02_high_value_anomaly_test.sql
sqlite3 ap_data.db < 03_sub_materiality_structuring_test.sql
sqlite3 ap_data.db < 03b_rolling_window_structuring.sql
sqlite3 ap_data.db < 04_substantive_drill_down.sql
```

### Review interface
Requires Python 3.9 or later:
```bash
pip install -r requirements.txt
streamlit run app.py
```

The database and raw CSV are excluded by `.gitignore` because of their size. Download the source data from the City's open data portal and load it locally first.

---

## Key Takeaways

1. **Establish the unit of analysis before writing the test.** A duplicate-payment test that counts accounting lines reports the publisher's file structure as a control weakness. Correcting this removed 68% of the exceptions.
2. **Silent failures are the real risk.** A query returning zero rows because of a type mismatch is indistinguishable from a clean result. Both failures recorded here raised no error.
3. **Reconcile every published figure to a re-run query.** The unit-of-analysis error was found by tracing a number in a draft of this document back to the database and getting a different answer.
4. **Exceptions are screening output, not findings.** 63,853 payments is a filter. 1,680 is a workload. Neither is evidence of anything until the metadata is examined.
5. **State the boundaries.** Every drill-down here records what was not verified, and why the published data could not verify it.
