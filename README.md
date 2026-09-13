# Comm-Log Send Reconciliation

## Objective

Reconcile Finance's reported `target_base` of **22** for:

- Merchant: **501**
- Period: **October 2026**
- Campaign scope: **Diwali campaigns**

The goal was to reproduce the reported number from the raw
`campaign` and `communication_log` data and explain the difference
between a naive send count and the official reporting metric.

---

## Investigation Approach

I started with a straightforward count of communication-log rows
and progressively applied the reporting rules from the data dictionary.

### Reconciliation Bridge

| Step | Description | Result | Reason |
|------|-------------|-------:|--------|
| 0 | Initial communication-log count | 30 | Starting point |
| 1 | Restrict to merchant 501 | 30 | All rows belong to merchant 501 |
| 2 | Restrict to October 2026 and Campaign communication type | 30 | All 30 rows already satisfy these filters |
| 3 | Apply campaign reporting eligibility | 26 | Campaign 9004 has `approval_awaiting`, so its 4 sends are not officially reportable |
| 4 | Deduplicate customers within retry chain 9001 → 9002 → 9003 | 23 | 13 attempts represent 10 customers; retries count a customer once |
| 5 | Deduplicate customers within retry chain 9201 → 9202 | 22 | 6 attempts represent 5 customers; D1 was retried |
| 6 | Validate standalone campaign 9101 counting | 22 | Standalone sends are separate events, so both sends to C20 count |

### Final Reconciliation

The final result is:

**22**

The contributing counts are:

- Retry chain `9001 → 9002 → 9003`: **10 customers**
- Standalone campaign `9101`: **7 send events**
- Retry chain `9201 → 9202`: **5 customers**

Therefore:

`10 + 7 + 5 = 22`

---

## Key Findings

### 1. Pending campaign sends

Campaign `9004` had four communication-log rows, but its
`creation_status` was `approval_awaiting`.

Although its `processing_status` was `processed`, the data dictionary
states that a campaign must have a finalized creation status as well
as a processed send workflow to be included in official reporting.

Therefore, the four sends from campaign `9004` were excluded.

### 2. Retry chains

Campaigns can represent retries of an earlier campaign through
`parent_id`.

The dataset contains two retry chains:

```text
9001 → 9002 → 9003
9201 → 9202
