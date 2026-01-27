{{ config(
    materialized='incremental',
    unique_key='transaction_id',
    incremental_strategy='merge',
    on_schema_change='fail'
) }}

/* RATIONALE:
    1. State Continuity: Uses a 3-day look-back window for Window Functions (LAG) consistency.
    2. Decoupled Logic: Separates Machine-readable codes from Human-readable labels.
    3. Cold-Start Handling: Gracefully handles users with no prior behavioral history (NULL limits).
*/

WITH user_metrics AS (
    SELECT 
        user_uuid,
        upper_risk_limit
    FROM {{ ref('int_user_behavior_metrics') }}
),

base_transactions AS (
    SELECT 
        t.transaction_id,
        t.user_uuid,
        t.amount_eur,
        t.transaction_time,
        t.country,
        t.ip_address,
        t.device_id,
        m.upper_risk_limit,
        -- Window functions for forensic reconstruction
        ROW_NUMBER() OVER (PARTITION BY t.user_uuid ORDER BY t.transaction_time ASC) as replay_sequence_step,
        LAG(t.country) OVER (PARTITION BY t.user_uuid ORDER BY t.transaction_time ASC) as prev_country,
        LAG(t.ip_address) OVER (PARTITION BY t.user_uuid ORDER BY t.transaction_time ASC) as prev_ip,
        (t.transaction_time - LAG(t.transaction_time) OVER (PARTITION BY t.user_uuid ORDER BY t.transaction_time ASC)) as time_gap
    FROM {{ ref('stg_transactions') }} t
    LEFT JOIN user_metrics m ON t.user_uuid = m.user_uuid

    {% if is_incremental() %}
    -- Context window for incremental processing
    WHERE t.transaction_time >= (SELECT MAX(transaction_time) - INTERVAL '3 days' FROM {{ this }})
    {% endif %}
),

forensic_logic AS (
    SELECT 
        *,
        -- Adaptive Detection Logic
        CASE 
            WHEN country <> prev_country AND time_gap < INTERVAL '1 hour' 
                THEN 'IMPOSSIBLE_TRAVEL'
            WHEN ip_address <> prev_ip AND time_gap < INTERVAL '5 minutes' 
                THEN 'RAPID_IP_SWITCH'
            WHEN upper_risk_limit IS NOT NULL AND amount_eur > upper_risk_limit 
                THEN 'OUTLIER_SPEND'
            ELSE 'VERIFIED'
        END as alert_code
    FROM base_transactions
)



SELECT 
    transaction_id,
    user_uuid,
    amount_eur,
    upper_risk_limit,
    transaction_time,
    country,
    ip_address,
    alert_code,
    -- Mapping codes to human-readable labels for BI tools
    CASE 
        WHEN alert_code = 'IMPOSSIBLE_TRAVEL' THEN '🚨 FLAG: Impossible Travel (Geo-Velocity Anomaly)'
        WHEN alert_code = 'RAPID_IP_SWITCH'   THEN '⚠️ FLAG: Rapid IP Switching (Bot Suspicion)'
        WHEN alert_code = 'OUTLIER_SPEND'     THEN '💰 FLAG: Outlier Spending (Dynamic Behavioral Deviation)'
        ELSE '✅ Verified'
    END as alert_label,
    time_gap,
    replay_sequence_step,
    CURRENT_TIMESTAMP AS alert_generated_at
FROM forensic_logic
WHERE alert_code <> 'VERIFIED'

{% if is_incremental() %}
  -- Deduplication: Ensures only new unique alerts are appended
  AND transaction_time > (SELECT MAX(transaction_time) FROM {{ this }})
{% endif %}