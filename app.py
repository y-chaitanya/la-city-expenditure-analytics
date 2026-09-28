import sqlite3

import pandas as pd
import streamlit as st

DB_PATH = "ap_data.db"
EXPECTED_TABLE = "Checkbook_LA"

st.set_page_config(page_title="LA City Checkbook Exception Review", layout="wide")

st.title("City of Los Angeles Expenditure Analytics")
st.caption(
    "Independent analysis of published open-government checkbook data. "
    "Not an audit; not conducted under GAGAS; not authorized by any City department."
)
st.markdown("---")


@st.cache_data
def run_query(query: str, params: tuple = ()) -> pd.DataFrame:
    """Run a parameterized query against the local SQLite database."""
    with sqlite3.connect(DB_PATH) as conn:
        return pd.read_sql_query(query, conn, params=params)


@st.cache_data
def resolve_schema():
    """Find the data table and map expected fields onto the actual column names.

    The open-data import alters column casing and can leave trailing spaces,
    so columns are matched case- and whitespace-insensitively rather than
    hard-coded. Returns the table name, the column map, and any fields that
    could not be found.
    """
    tables = run_query("SELECT name FROM sqlite_master WHERE type='table';")
    names = tables["name"].tolist()
    if EXPECTED_TABLE in names:
        table = EXPECTED_TABLE
    elif names:
        table = names[0]
    else:
        raise RuntimeError(f"No tables found in {DB_PATH}.")

    columns = run_query(f'PRAGMA table_info("{table}");')["name"].tolist()
    lookup = {c.strip().upper(): c for c in columns}

    wanted = {
        "txid": ["TRANSACTION ID", "TRANSACTION_ID", "TXID"],
        "vendor": ["VENDOR NAME", "VENDOR", "VENDOR_NAME"],
        "date": ["TRANSACTION DATE", "DATE", "TRANSACTION_DATE"],
        "amount": ["DOLLAR AMOUNT", "AMOUNT", "DOLLAR_AMOUNT"],
        "department": ["DEPARTMENT NAME", "DEPARTMENT", "DEPARTMENT_NAME"],
        "fund": ["FUND NAME", "FUND", "FUND_NAME"],
        "invoice": ["INV NUM", "INVOICE NUMBER", "INVOICE", "INV_NUM"],
    }

    resolved, missing = {}, []
    for field, candidates in wanted.items():
        match = next((lookup[c.upper()] for c in candidates if c.upper() in lookup), None)
        if match:
            resolved[field] = match
        else:
            missing.append(field)

    return table, resolved, missing


try:
    TABLE, COLS, MISSING = resolve_schema()
except (sqlite3.Error, RuntimeError) as exc:
    st.error(f"Could not read the database at {DB_PATH}: {exc}")
    st.stop()

if MISSING:
    st.warning(
        "These fields could not be matched to a column and are unavailable: "
        + ", ".join(MISSING)
    )

if "txid" not in COLS:
    st.error(
        "No TRANSACTION ID column was found. Every measure below counts distinct "
        "payments, which cannot be done without it."
    )
    st.stop()

# The source stores currency as formatted text, so it is cast before comparison.
AMOUNT_NUM = (
    f'CAST(REPLACE(REPLACE("{COLS["amount"]}", \'$\', \'\'), \',\', \'\') AS REAL)'
)

# --- Population and exception measures, all computed from the data ---
st.subheader("Population and exception measures")

st.caption(
    "The dataset publishes one row per accounting distribution line, so a single "
    "payment can appear as several rows sharing one transaction ID. Every measure "
    "below counts distinct payments, not rows. Redacted payees, published as "
    "'PRIVACY-<DEPARTMENT>', and $0.00 entries are excluded from the exception "
    "measures: neither is a vendor payment."
)

try:
    population = run_query(
        f'''
        SELECT COUNT(*) AS rows_total,
               COUNT(DISTINCT "{COLS['txid']}") AS payments_total
        FROM "{TABLE}";
        '''
    )
    rows_total = int(population["rows_total"].iloc[0])
    payments_total = int(population["payments_total"].iloc[0])

    duplicates = run_query(
        f'''
        SELECT COUNT(*) AS groups_found, COALESCE(SUM(t), 0) AS payments_involved
        FROM (
            SELECT COUNT(DISTINCT "{COLS['txid']}") AS t
            FROM "{TABLE}"
            WHERE "{COLS['vendor']}" IS NOT NULL
              -- Redacted payees ('PRIVACY-<DEPARTMENT>') are anonymized
              -- individuals, not vendors; grouping on the label manufactures
              -- false clusters. $0.00 entries are accounting adjustments.
              AND "{COLS['vendor']}" NOT LIKE 'PRIVACY-%'
              AND {AMOUNT_NUM} <> 0
            GROUP BY "{COLS['vendor']}", "{COLS['date']}", "{COLS['amount']}"
            HAVING COUNT(DISTINCT "{COLS['txid']}") > 1
        );
        '''
    )

    band_payments = run_query(
        f'''
        SELECT COUNT(DISTINCT "{COLS['txid']}") AS n
        FROM "{TABLE}"
        WHERE "{COLS['vendor']}" IS NOT NULL
          AND "{COLS['vendor']}" NOT LIKE 'PRIVACY-%'
          AND {AMOUNT_NUM} BETWEEN ? AND ?;
        ''',
        (4800.00, 4999.99),
    )["n"].iloc[0]
except sqlite3.Error as exc:
    st.error(f"Measure query failed: {exc}")
    st.stop()

k1, k2, k3 = st.columns(3)

k1.metric(
    "Payments in population",
    f"{payments_total:,}",
    help=f"Published as {rows_total:,} accounting lines "
         f"({rows_total / payments_total:.2f} lines per payment)",
)
k2.metric(
    "Payments in duplicate groups",
    f"{int(duplicates['payments_involved'].iloc[0]):,}",
    help=f"{int(duplicates['groups_found'].iloc[0]):,} groups matching on vendor, "
         "date and amount under two or more transaction IDs",
)
k3.metric(
    "Payments in the 4,800 to 4,999.99 band",
    f"{int(band_payments):,}",
    help="All payments in the band, not only those in same-day clusters",
)

st.caption(
    "Every figure above is computed from the loaded database at page load. "
    "Exceptions are patterns requiring follow-up, not findings."
)

st.markdown("---")

# --- Vendor drill-down ---
st.subheader("Vendor metadata drill-down")

vendor_search = st.text_input(
    "Vendor name contains (for example: KONICA, WELLS FARGO, UNITED SITE)", ""
).strip()

if vendor_search:
    display_fields = [f for f in ("txid", "vendor", "date", "amount", "department", "fund", "invoice") if f in COLS]
    fields = ", ".join(f'"{COLS[f]}"' for f in display_fields)
    try:
        summary = run_query(
            f'''
            SELECT COUNT(*) AS rows_found,
                   COUNT(DISTINCT "{COLS['txid']}") AS distinct_payments
            FROM "{TABLE}"
            WHERE UPPER("{COLS['vendor']}") LIKE ?;
            ''',
            (f"%{vendor_search.upper()}%",),
        )
        rows_found = int(summary["rows_found"].iloc[0])
        payments_found = int(summary["distinct_payments"].iloc[0])

        if rows_found == 0:
            st.info(f"No transactions found for a vendor name containing '{vendor_search}'.")
        else:
            st.caption(
                f"{rows_found:,} accounting lines across {payments_found:,} distinct payments. "
                "Showing up to 200 lines, highest amount first."
            )
            results = run_query(
                f'''
                SELECT {fields}
                FROM "{TABLE}"
                WHERE UPPER("{COLS['vendor']}") LIKE ?
                ORDER BY {AMOUNT_NUM} DESC
                LIMIT 200;
                ''',
                (f"%{vendor_search.upper()}%",),
            )
            st.dataframe(results, use_container_width=True)
    except sqlite3.Error as exc:
        st.error(f"Query failed: {exc}")