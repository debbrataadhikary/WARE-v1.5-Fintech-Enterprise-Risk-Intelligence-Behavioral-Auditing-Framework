{{
  config(
    materialized='incremental',
    unique_key='transaction_id',
    incremental_strategy='merge'
  )
}}

-- Shadow Layer: Testing Variant B (Challenger Model)
-- Goal: Validating if a more aggressive Geo-Velocity threshold catches more fraud
SELECT 
    transaction_id,
    transaction_time,
    user_uuid,
    amount_eur,
    'variant_b_2_5sigma_geo_velocity' as experiment_id, 
    
    -- Reusing Upstream Features (No Redundant Logic)
    is_geo_mismatch,
    daily_velocity,
    
    -- Variant B (Challenger Model Logic)
    -- This variant is more sensitive to Foreign transactions than the Main model
    CASE 
        -- Rule 1: Aggressive Sigma (2.5x)
        WHEN amount_eur > (avg_user_amt + (2.5 * stddev_user_amt)) THEN 5
        
        -- Rule 2: Geo-Sensitive Velocity 
        -- In this experiment, we trigger higher risk at lower velocity for foreign transactions
        WHEN is_geo_mismatch = 1 AND daily_velocity > 3 THEN 6
        WHEN daily_velocity > 5 THEN 4
        
        -- Rule 3: High Value Cross-Border
        WHEN (is_geo_mismatch = 1 AND amount_eur > p95_amount_channel) THEN 5
        
        ELSE 0 
    END as score_variant_b

FROM {{ ref('int_risk_features') }}
{% if is_incremental() %}
    WHERE transaction_time > (SELECT MAX(transaction_time) FROM {{ this }})
{% endif %}