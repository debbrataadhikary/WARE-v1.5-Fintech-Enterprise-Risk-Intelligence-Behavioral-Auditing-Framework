{{
  config(
    materialized='incremental',
    unique_key='transaction_id',
    incremental_strategy='merge'
  )
}}

SELECT 
    *,
    -- Dynamic Weighted Scoring 
    (
        -- Rule 1: User Behavior (2.5 Sigma is more realistic than 3 Sigma)
        CASE WHEN amount_eur > (avg_user_amt + (2.5 * stddev_user_amt)) THEN 7 ELSE 0 END +
        
        -- Rule 2: Channel Behavior (P95 captures top 5% anomalies)
        CASE WHEN amount_eur > p95_amount_channel THEN 5 ELSE 0 END +
        
        -- Rule 3: Velocity Check (More than 5 transactions/24h is suspicious)
        CASE WHEN daily_velocity > 5 THEN 5 ELSE 0 END +

        -- Rule 4: Absolute High Value (Lowered threshold for overlap)
        CASE WHEN amount_eur > 1500 THEN 3 ELSE 0 END
    ) as final_risk_score
FROM {{ ref('int_risk_features') }}
{% if is_incremental() %}
    WHERE transaction_time > (SELECT MAX(transaction_time) FROM {{ this }})
{% endif %}