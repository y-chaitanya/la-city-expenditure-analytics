
---

# City of Los Angeles Expenditure Audit

**Forensic Data Analytics & Internal Control Review using SQLite**

## Executive Summary

When analyzing public financial datasets, high-dollar figures and recurring line items can easily trigger false alarms without accounting context. In this project, I performed an end-to-end audit of the **City of Los Angeles Checkbook dataset** (747,363 expenditure records) using SQLite to evaluate internal payment controls, detect potential split-purchasing, and investigate high-dollar ledger anomalies.

By pairing automated SQL exception scripts with substantive ledger drill-downs, I separated operational system noise and municipal debt service from genuine internal control risks.

### Key Audit Outcomes

* **$441M Debt Service Validated:** An initial flag showing 49 identical $9.0M payouts to Wells Fargo on a single day was investigated and cleared as authorized bond principal and interest redemptions funded by Water & Power Revenue accounts.
* **Master Contract Split Cleared:** Recurring $4,960 payouts to United Site Services were confirmed to be valid line-item route billings under an authorized Mayoral Special Project Contract Purchase Order (CPO), rather than employee P-Card limit evasion.
* **Automated ERP Noise Identified:** Hundreds of recurring $6.72 line items to Konica Minolta totaling $4,656.96 were traced to automated cross-departmental cost-allocation routines for shared printing infrastructure.
* **Targeted P-Card Risk Population Isolated:** Built an anti-structuring query that successfully isolated transactions sitting right below the $5,000 competitive bidding threshold ($4,800.00–$4,999.99) for targeted audit sampling.

---

## Repository Structure

```text
la-city-expenditure-audit/
├── assets/
│   ├── 01_duplicate_results.png       # Screenshot: Duplicate payment scanner query output
│   ├── 02_high_value_results.png      # Screenshot: Performance materiality query output
│   ├── 03_structuring_results.png     # Screenshot: Anti-structuring split purchase output
│   ├── 04_drilldown_konica.png        # Screenshot: Konica Minolta allocation evidence
│   ├── 04_drilldown_wellsfargo.png    # Screenshot: Wells Fargo debt service tranche evidence
│   └── 04_drilldown_results.png       # Screenshot: United Site Services contract evidence
├── 01_duplicate_payment_test.sql      # Schema definition & duplicate payment scanner
├── 02_high_value_anomaly_test.sql     # Performance materiality filter ($10k+ exposure)
├── 03_sub_materiality_structuring_test.sql # Anti-structuring P-Card split purchase detector
├── 04_substantive_drill_down.sql      # Root-cause case studies & metadata verification
├── .gitignore                         # Excludes local SQLite database binaries (>100MB)
└── README.md                          # Project documentation & audit findings

```

---

## Audit Methodology, SQL Tests & Evidence

### 1. System Logic & Duplicate Payment Testing (`01_duplicate_payment_test.sql`)

My baseline test queried exact duplicate payment entries matching on **Vendor Name**, **Transaction Date**, and **Dollar Amount**.

```sql
SELECT 
    "VENDOR NAME", 
    "TRANSACTION DATE", 
    "DOLLAR AMOUNT", 
    COUNT(*) AS payment_count
FROM Checkbook_LA
WHERE "VENDOR NAME" IS NOT NULL
GROUP BY "VENDOR NAME", "TRANSACTION DATE", "DOLLAR AMOUNT"
HAVING COUNT(*) > 1
ORDER BY payment_count DESC;

```

* **Visual Evidence:**


---

### 2. High-Value Materiality Filtering (`02_high_value_anomaly_test.sql`)

Because raw text currency strings (`"$9,000,000.00"`) mask numeric analysis, I built dynamic SQL queries using `CAST(REPLACE(REPLACE(...)))` to convert text to numeric values and isolate duplicate exposure exceeding **$10,000.00**.

```sql
SELECT 
    "VENDOR NAME",
    "TRANSACTION DATE",
    "DOLLAR AMOUNT",
    COUNT(*) AS duplicate_count,
    SUM(CAST(REPLACE(REPLACE("DOLLAR AMOUNT", '$', ''), ',', '') AS REAL)) AS total_exposure_amount
FROM Checkbook_LA
WHERE "VENDOR NAME" IS NOT NULL
  AND CAST(REPLACE(REPLACE("DOLLAR AMOUNT", '$', ''), ',', '') AS REAL) >= 10000.00
GROUP BY "VENDOR NAME", "TRANSACTION DATE", "DOLLAR AMOUNT"
HAVING COUNT(*) > 1
ORDER BY total_exposure_amount DESC;

```

* **Visual Evidence:**


---

### 3. Anti-Structuring Split Purchase Scanner (`03_sub_materiality_structuring_test.sql`)

Employees seeking to bypass $5,000 formal bidding requirements or P-Card purchase ceilings often split single invoices into multiple smaller purchases. I wrote a targeted scan for vendor transaction clusters falling between **$4,800.00 and $4,999.99**.

```sql
SELECT 
    "VENDOR NAME",
    "TRANSACTION DATE",
    COUNT(*) AS payment_count,
    GROUP_CONCAT("DOLLAR AMOUNT") AS amounts
FROM Checkbook_LA
WHERE "VENDOR NAME" IS NOT NULL
  AND CAST(REPLACE(REPLACE("DOLLAR AMOUNT", '$', ''), ',', '') AS REAL) BETWEEN 4800.00 AND 4999.99
GROUP BY "VENDOR NAME", "TRANSACTION DATE"
HAVING COUNT(*) > 1
ORDER BY payment_count DESC;

```

* **Visual Evidence:**


---

### 4. Substantive Ledger Drill-Down Case Studies (`04_substantive_drill_down.sql`)

#### Case Study A: Konica Minolta Cost Allocation Analysis

* **Initial Flag:** Test 1 caught $6.72 repeating 693 times on 10/02/2025 ($4,656.96 total exposure).
* **Audit Resolution:** Querying `TRANSACTION ID` and device serial numbers revealed unique sequential IDs (`EFT2626...`). This proves an automated ERP system routine splitting a centralized master invoice across individual departmental printers rather than an overpayment error.


#### Case Study B: Wells Fargo Municipal Debt Service Analysis

* **Initial Flag:** Test 2 caught $9,000,000.00 repeating 49 times on 05/01/2026 ($441,000,000 total exposure).
* **Audit Resolution:** Querying `FUND NAME`, `ACCOUNT NAME`, and `INV NUM` showed payments assigned to Water/Power Revenue funds matching sequential bond tranche redemptions (`RFP42326J`, `L`, `M`...). This confirms authorized bond principal and interest payouts executed through trustee accounts.


#### Case Study C: United Site Services Contract Analysis

* **Initial Flag:** Test 3 caught $4,960.00 repeating 15 times on 10/30/2025 ($74,400 total exposure).
* **Audit Resolution:** Querying `PO NUM` and `DETAILED ITEM DESCRIPTION` revealed a shared Master Contract Purchase Order (`CPO74260000423827`) for Mayoral Special Projects. The individual line items represented distinct weekly route servicing locations, clearing suspicion of intentional P-Card limit structuring.


---

## Summary of Audit Findings

| Vendor Name | Flagged Condition | Total Exposure | Audit Findings & Resolution |
| --- | --- | --- | --- |
| **Wells Fargo Bank** | 49 Same-Day $9M Transactions | $441,000,000.00 | **Cleared:** Authorized municipal debt service and revenue bond redemptions. |
| **United Site Services** | 15 Transactions between $4.8k–$5k | $74,400.00 | **Cleared:** Line-item route servicing under a master Contract Purchase Order (CPO). |
| **Konica Minolta** | 693 Duplicate $6.72 Entries | $4,656.96 | **Cleared:** Automated system-generated cost allocation across city departments. |

---

## How to Run This Audit Locally

### Prerequisites

* SQLite3 installed locally or a visual editor like **DB Browser for SQLite**.
* City of Los Angeles Checkbook dataset loaded as table `Checkbook_LA`.

### Execution

Execute the SQL scripts in numerical order:

```bash
sqlite3 Checkbook_LA.db < 01_duplicate_payment_test.sql
sqlite3 Checkbook_LA.db < 02_high_value_anomaly_test.sql
sqlite3 Checkbook_LA.db < 03_sub_materiality_structuring_test.sql
sqlite3 Checkbook_LA.db < 04_substantive_drill_down.sql

```

---

## Key Takeaways for Public Sector Auditing

1. **Full-Population Analytics:** Writing reproducible SQL exception scripts allows auditors to analyze 100% of municipal spend rather than relying on restrictive random sampling.
2. **Context Prevents False Alarms:** Automated exceptions are initial indicators, not proof of fraud. Understanding fund accounting and master contract structures is critical before escalating audit findings.

---