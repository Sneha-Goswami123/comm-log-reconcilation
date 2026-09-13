# Comm-Log Send Reconciliation

## Objective

Reconcile Finance's reported `target_base` of 22 for:

- Merchant: 501
- Period: October 2026
- Campaign scope: Diwali campaigns

## Investigation

I started with a naive count of communication-log rows and progressively
applied the reporting rules described in the data dictionary.

### Reconciliation Bridge

| Step | Description | Result | Reason |
|------|-------------|-------:|--------|
| 0 | All communication-log rows | 30 | Starting point |
| 1 | Restrict to merchant 501 | 30 | All rows belong to merchant 501 |
| 2 | Restrict to October 2026 and Campaign communication type | 30 | All 30 rows already satisfy these filters |
| 3 | Apply campaign reporting eligibility | 26 | Campaign 9004 is `approval_awaiting`, so its 4 sends are not officially reportable |
| 4 | Deduplicate customers within retry chain 9001 → 9002 → 9003 | 23 | 13 attempts represent 10 customers; retries count a customer once |
| 5 | Deduplicate customers within retry chain 9201 → 9202 | 22 | 6 attempts represent 5 customers; D1 was retried |
| 6 | Preserve standalone campaign 9101 events | 22 | Standalone sends are separate events, so both sends to C20 count |

## Final Result

The reconciled `target_base` is:

**22**

The final result consists of:

- Retry chain `9001 → 9002 → 9003`: 10 customers
- Standalone campaign `9101`: 7 send events
- Retry chain `9201 → 9202`: 5 customers

Total:

`10 + 7 + 5 = 22`

## Key Findings

The initial communication-log count was 30, but four rows belonged to campaign
9004, which was still `approval_awaiting`. These sends therefore did not qualify
for official reporting.

The remaining overcount came from retry campaigns. Campaigns 9002 and 9003
are retries of 9001, while 9202 is a retry of 9201. Within these chains, a
customer can appear in multiple attempts but contributes only once to the
underlying communication.

The standalone campaign 9101 required different treatment. Customer C20
appears twice on different dates, and both rows represent separate send events.
Therefore, applying `COUNT(DISTINCT customer_id)` globally would incorrectly
reduce the standalone count.

## SQL

The final reconciliation query is available in:

`sql/final_query.sql`

The investigation queries are available in:

`sql/exploration.sql`

## Reproducibility

Run the final query against the supplied SQLite database:

```bash
sqlite3 data/comm_log.db < sql/final_query.sql
