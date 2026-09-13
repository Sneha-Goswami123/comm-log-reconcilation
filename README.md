# Comm-Log Send Reconciliation

## Objective

Reconcile Finance's reported `target_base` of **22** for:

- **Merchant:** 501
- **Period:** October 2026
- **Campaign scope:** Diwali campaigns

The goal was to reproduce the reported number from the raw `campaign` and
`communication_log` data and explain the difference between a straightforward
send count and the official reporting metric.

---

## Data Overview

The dataset contains two main tables: `campaign` and `communication_log`.

### `campaign`

The `campaign` table contains one row per campaign.

Important columns:

| Column | Description |
|--------|-------------|
| `id` | Campaign ID |
| `merchant_id` | Merchant owning the campaign |
| `parent_id` | Parent campaign ID; identifies retry relationships |
| `name` | Campaign name |
| `creation_status` | Status of the campaign creation/approval workflow |
| `processing_status` | Status of the send-processing workflow |

A campaign is eligible for official reporting only when:

`creation_status IN ('approved', 'aborted', 'resumed', 'stopped')`

and:

`processing_status = 'processed'`

A campaign with `creation_status = 'approval_awaiting'` is not eligible
for official reporting, even if communication-log rows already exist.

### `communication_log`

The `communication_log` table contains one row per individual send attempt.

Important columns:

| Column | Description |
|--------|-------------|
| `id` | Send attempt ID |
| `merchant_id` | Merchant ID |
| `communication_id` | Campaign ID |
| `customer_id` | Customer targeted |
| `communication_type` | `2` represents Campaign |
| `delivery_status` | `900` = delivered, `1100` = failed |
| `sent_time` | Time the send occurred |

---

## Investigation Approach

I started with a straightforward count of communication-log rows and
progressively applied the reporting rules described in the data dictionary.

### Step 0 — Initial communication-log count

Query:

    SELECT COUNT(*) AS total_rows
    FROM communication_log;

Result:

**30**

This was the starting point.

---

### Step 1 — Restrict to merchant 501

Query:

    SELECT COUNT(*) AS merchant_rows
    FROM communication_log
    WHERE merchant_id = 501;

Result:

**30**

There was no change because all 30 communication-log rows belong to
merchant 501.

---

### Step 2 — Restrict to October 2026 and Campaign communication type

Query:

    SELECT COUNT(*) AS naive_count
    FROM communication_log
    WHERE merchant_id = 501
      AND sent_time >= '2026-10-01'
      AND sent_time < '2026-11-01'
      AND communication_type = 2;

Result:

**30**

Again, there was no change because all 30 rows are October 2026
Campaign communication records for merchant 501.

At this point:

**Naive count = 30**

Finance's reported value:

**target_base = 22**

This indicated that the remaining difference came from campaign eligibility
and retry handling.

---

## Campaign-Level Investigation

I then joined the campaign table with the communication log to understand
how the 30 sends were distributed across campaigns.

| Campaign | Parent | Creation Status | Processing Status | Send Count |
|----------|--------|-----------------|-------------------|-----------:|
| 9001 | NULL | approved | processed | 10 |
| 9002 | 9001 | approved | processed | 2 |
| 9003 | 9002 | approved | processed | 1 |
| 9004 | 9001 | approval_awaiting | processed | 4 |
| 9101 | NULL | approved | processed | 7 |
| 9201 | NULL | approved | processed | 5 |
| 9202 | 9201 | approved | processed | 1 |
| **Total** | | | | **30** |

This revealed one ineligible campaign and two retry chains.

---

## Campaign Eligibility Adjustment

Campaign `9004` is:

**Diwali Cart Recovery - Retry C (pending)**

Its statuses are:

- `creation_status = approval_awaiting`
- `processing_status = processed`

It contains **4 communication-log rows**.

Although its processing workflow is marked as processed, its creation
workflow has not cleared approval.

According to the reporting definition, a campaign must have a finalized
creation status as well as a completed processing status to be included
in official reporting.

Therefore, the four sends from campaign `9004` were excluded.

The running count becomes:

**30 → 26**

The eligibility condition used was:

    c.creation_status IN (
        'approved',
        'aborted',
        'resumed',
        'stopped'
    )
    AND c.processing_status = 'processed'

---

## Retry Chains

The `campaign.parent_id` column represents retry relationships.

The dataset contains two eligible retry chains:

**9001 → 9002 → 9003**

and:

**9201 → 9202**

A customer who appears multiple times within the same retry chain represents
multiple attempts of the same underlying communication. Therefore, the
customer should be counted only once within that retry chain.

---

### Retry Chain: 9001 → 9002 → 9003

Campaign `9001` contains 10 send attempts.

Campaign `9002` contains 2 retry attempts:

| Customer | Result |
|----------|--------|
| C2 | delivered |
| C3 | failed |

Campaign `9003` contains the final retry:

| Customer | Result |
|----------|--------|
| C3 | delivered |

The chain therefore contains:

**10 + 2 + 1 = 13 send attempts**

However, there are only **10 distinct customers** in the entire chain.

For example, customer C2 was:

**9001 → C2 → failed**

followed by:

**9002 → C2 → delivered**

Customer C3 was:

**9001 → C3 → failed**

followed by:

**9002 → C3 → failed**

followed by:

**9003 → C3 → delivered**

These are multiple attempts of the same underlying communication.

Therefore:

**13 attempts → 10 customers**

This reduces the running total:

**26 → 23**

---

### Retry Chain: 9201 → 9202

Campaign `9201` contains:

| Customer | Result |
|----------|--------|
| D1 | failed |
| D2 | delivered |
| D3 | delivered |
| D4 | delivered |
| D5 | delivered |

Campaign `9202` retries D1:

| Customer | Result |
|----------|--------|
| D1 | delivered |

Therefore:

**5 + 1 = 6 send attempts**

but only **5 customers** were involved.

Thus:

**6 attempts → 5 customers**

This reduces the running total:

**23 → 22**

---

## Standalone Campaign

Campaign `9101` is:

**Diwali Flash Sale - Standalone**

It has no parent campaign and no retry campaigns.

It contains 7 send events:

| Customer | Date |
|----------|------|
| C20 | 2026-10-10 |
| C20 | 2026-10-20 |
| C21 | 2026-10-10 |
| C22 | 2026-10-10 |
| C23 | 2026-10-10 |
| C24 | 2026-10-10 |
| C25 | 2026-10-10 |

Customer C20 appears twice, but these are two separate send events
on different dates.

Because `9101` is a standalone campaign, both sends count.

Therefore:

**9101 = 7 send events**

and not 6 distinct customers.

This is important because a global:

    COUNT(DISTINCT customer_id)

would incorrectly deduplicate C20 and produce the wrong result.

Distinct-customer counting is therefore applied only within retry chains,
while standalone campaigns retain their individual send events.

---

## Reconciliation Bridge

The complete reconciliation is:

| Step | Description | Result | Reason |
|------|-------------|-------:|--------|
| 0 | Initial communication-log count | **30** | Starting point |
| 1 | Restrict to merchant 501 | **30** | All rows belong to merchant 501 |
| 2 | Restrict to October 2026 and Campaign communication type | **30** | All rows already satisfy these filters |
| 3 | Apply campaign reporting eligibility | **26** | Campaign 9004 is `approval_awaiting`; its 4 sends are not reportable |
| 4 | Deduplicate customers within retry chain `9001 → 9002 → 9003` | **23** | 13 attempts represent 10 customers |
| 5 | Deduplicate customers within retry chain `9201 → 9202` | **22** | 6 attempts represent 5 customers |
| 6 | Validate standalone campaign `9101` counting | **22** | Its 7 sends remain separate events, including both C20 sends |

### Numerical Bridge

    30
     ↓
    30    Merchant filter — no change
     ↓
    30    October + Campaign type — no change
     ↓
    26    Exclude 4 sends from ineligible campaign 9004
     ↓
    23    9001 → 9002 → 9003: 13 attempts → 10 customers
     ↓
    22    9201 → 9202: 6 attempts → 5 customers

The final contributing counts are:

    9001 → 9002 → 9003 = 10
    9101                = 7
    9201 → 9202         = 5
    --------------------------------
    Total               = 22

Therefore:

**target_base = 22**

---

## Final SQL Approach

The final SQL uses a recursive Common Table Expression (CTE) to identify
the root campaign for every campaign in a retry chain.

This avoids hardcoding specific campaign IDs and allows retry chains with
multiple levels to be handled automatically.

The query performs the following steps:

1. Build the campaign hierarchy using `parent_id`.
2. Identify the root campaign for each campaign.
3. Filter communication-log rows by merchant, date, communication type,
   and campaign eligibility.
4. Identify root campaigns that have retries.
5. For standalone campaigns, count every send event.
6. For retry chains, count each customer once across the entire chain.
7. Sum the results.

The final query is stored in:

`sql/final_query.sql`

The investigation queries are stored in:

`sql/exploration.sql`

---

## Final Query Result

Running the final query against the supplied SQLite database produces:

    target_base
    -----------
    22

Therefore:

# target_base = 22

This matches Finance's reported value.

---

## Surprising Data Observations

One surprising aspect of the dataset was that communication-log rows
already existed for campaign `9004` even though its creation status was
still `approval_awaiting`. This demonstrates why simply counting
communication-log rows is not sufficient for official reporting.

Another important observation was that retry campaigns are represented
as separate campaign records. Multiple attempts for the same customer
can therefore appear across different campaign IDs even though they
belong to the same underlying communication.

Finally, the standalone campaign `9101` contains two separate sends to
customer C20 on different dates. This means that globally deduplicating
customers would incorrectly reduce the reported send count.

---

## Files in This Repository

    comm-log-reconciliation/
    │
    ├── README.md
    │
    └── sql/
        ├── exploration.sql
        └── final_query.sql

### `sql/exploration.sql`

Contains the SQL queries used during the investigation, including:

- Initial row count
- Merchant filtering
- Date and communication-type filtering
- Campaign-level investigation
- Campaign eligibility checks
- Retry-chain inspection
- Standalone campaign inspection

### `sql/final_query.sql`

Contains the final SQLite query used to calculate the reconciled
`target_base`.

---

## Reproducibility

The analysis was performed using SQLite against the supplied
`comm_log.db` database.

To run the final query:

    sqlite3 data/comm_log.db < sql/final_query.sql

Expected result:

    target_base
    -----------
    22

The raw dataset is not included in this public repository because it was
provided as part of the Xeno take-home assignment.

---

## Conclusion

The initial naive count was **30**, while Finance's reported
`target_base` was **22**.

The difference was explained by two factors:

1. **Four sends** belonged to campaign `9004`, which was still
   `approval_awaiting` and therefore not eligible for official reporting.

2. **Four additional attempts** were duplicate customer attempts within
   eligible retry chains and therefore had to be counted once per
   customer within each retry chain.

After applying the campaign eligibility rules and correctly handling
retry chains while preserving standalone send events, the final
reconciled value is:

# target_base = 22
