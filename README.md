# Comm-Log Send Reconciliation

## Objective

The objective is to calculate the correct `target_base` for merchant 501 for October 2026.

The finance-provided true value is:

**target_base = 22**

## Scope

- Merchant: 501
- Month: October 2026
- Communication type: Campaign (`2`)

## Approach

I calculated the final number step by step:

1. Started with all communication log records.
2. Filtered for merchant 501.
3. Filtered for October 2026 and Campaign communication type.
4. Removed sends belonging to campaigns that were not officially reportable.
5. Identified retry chains using `parent_id`.
6. For retry chains, counted each customer only once across the complete chain.
7. For standalone campaigns, counted every send separately.

## Reconciliation

| Step | Count |
|------|------:|
| Initial communication log rows | 30 |
| Merchant 501 | 30 |
| October + Campaign type | 30 |
| After campaign eligibility | 26 |
| After collapsing retry chain 9001 → 9002 → 9003 | 23 |
| After collapsing retry chain 9201 → 9202 | 22 |

## Important Findings

Campaign `9004` had 4 communication records, but its `creation_status` was `approval_awaiting`, so these records were excluded from the reportable count.

The retry chain `9001 → 9002 → 9003` had 13 send attempts but only 10 distinct customers, so it contributes 10.

The retry chain `9201 → 9202` had 6 send attempts but only 5 distinct customers, so it contributes 5.

Campaign `9101` was a standalone campaign. Customer C20 appeared twice, but both sends were counted because standalone campaigns count every send event separately.

## Final Calculation

10 customers from retry chain `9001 → 9002 → 9003`

+ 7 sends from standalone campaign `9101`

+ 5 customers from retry chain `9201 → 9202`

= **22**

## Surprising Data

One surprising aspect of the data was that retry campaigns contained multiple attempts for the same customer, including failed and successful deliveries. I also noticed that campaign `9101` sent to customer C20 twice; since it was a standalone campaign, both sends were correctly counted. Additionally, campaign `9004` had communication records even though it was still `approval_awaiting`, so those records were not reportable.

## Files

- `sql/exploration.sql` - SQL queries used to investigate the data.
- `sql/final_query.sql` - Final SQL query used to calculate `target_base`.

## Result

**Final target_base = 22**
