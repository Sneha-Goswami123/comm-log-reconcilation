-- Step 0: Initial naive count
SELECT COUNT(*) AS total_rows
FROM communication_log;

-- Step 1: Merchant filter
SELECT COUNT(*) AS merchant_rows
FROM communication_log
WHERE merchant_id = 501;

-- Step 2: October + Campaign
SELECT COUNT(*) AS naive_count
FROM communication_log
WHERE merchant_id = 501
  AND sent_time >= '2026-10-01'
  AND sent_time < '2026-11-01'
  AND communication_type = 2;

-- Step 3: Campaign-level investigation
SELECT
    c.id AS campaign_id,
    c.parent_id,
    c.name,
    c.creation_status,
    c.processing_status,
    COUNT(cl.id) AS send_count
FROM campaign c
LEFT JOIN communication_log cl
    ON cl.communication_id = c.id
WHERE c.merchant_id = 501
GROUP BY
    c.id,
    c.parent_id,
    c.name,
    c.creation_status,
    c.processing_status
ORDER BY c.id;

-- Step 4: Apply reporting eligibility
SELECT COUNT(*) AS eligible_sends
FROM communication_log cl
JOIN campaign c
    ON cl.communication_id = c.id
WHERE cl.merchant_id = 501
  AND cl.sent_time >= '2026-10-01'
  AND cl.sent_time < '2026-11-01'
  AND cl.communication_type = 2
  AND c.creation_status IN (
      'approved',
      'aborted',
      'resumed',
      'stopped'
  )
  AND c.processing_status = 'processed';

-- Step 5: Inspect retry chains
SELECT
    cl.communication_id,
    cl.customer_id,
    cl.delivery_status,
    cl.sent_time
FROM communication_log cl
WHERE cl.communication_id IN (9001, 9002, 9003, 9201, 9202)
ORDER BY cl.communication_id, cl.id;

-- Step 6: Inspect standalone campaign
SELECT
    cl.communication_id,
    cl.customer_id,
    cl.delivery_status,
    cl.sent_time
FROM communication_log cl
WHERE cl.communication_id = 9101
ORDER BY cl.id;
