WITH RECURSIVE campaign_tree AS (
    SELECT
        id AS campaign_id,
        id AS root_id
    FROM campaign
    WHERE parent_id IS NULL

    UNION ALL

    SELECT
        c.id AS campaign_id,
        ct.root_id
    FROM campaign c
    JOIN campaign_tree ct
        ON c.parent_id = ct.campaign_id
),

eligible_logs AS (
    SELECT
        cl.id,
        cl.customer_id,
        cl.communication_id,
        ct.root_id
    FROM communication_log cl
    JOIN campaign c
        ON cl.communication_id = c.id
    JOIN campaign_tree ct
        ON cl.communication_id = ct.campaign_id
    WHERE cl.merchant_id = 501
      AND cl.communication_type = 2
      AND cl.sent_time >= '2026-10-01'
      AND cl.sent_time < '2026-11-01'
      AND c.creation_status IN (
          'approved',
          'aborted',
          'resumed',
          'stopped'
      )
      AND c.processing_status = 'processed'
),

retry_roots AS (
    SELECT DISTINCT root_id
    FROM campaign_tree
    WHERE campaign_id != root_id
),

counts AS (
    SELECT
        el.root_id,
        COUNT(*) AS qualifying_count
    FROM eligible_logs el
    LEFT JOIN retry_roots rr
        ON el.root_id = rr.root_id
    WHERE rr.root_id IS NULL
    GROUP BY el.root_id

    UNION ALL

    SELECT
        el.root_id,
        COUNT(DISTINCT el.customer_id) AS qualifying_count
    FROM eligible_logs el
    JOIN retry_roots rr
        ON el.root_id = rr.root_id
    GROUP BY el.root_id
)

SELECT SUM(qualifying_count) AS target_base
FROM counts;
