{{
  config(
    materialized='incremental',
    unique_key='transaction_id',
    incremental_strategy='merge'
  )
}}

-- Shadow Layer: Testing Variant B with Experiment Tagging
SELECT 
    transaction_id,
    transaction_time,
    'variant_b_2_5sigma_geo_velocity' as experiment_id, 
    
    -- Feature Store for Regression Analysis
    CASE WHEN country != home_country THEN 1 ELSE 0 END as is_geo_mismatch,
    daily_velocity,
    
    -- Variant B (Challenger Model)
    CASE 
        WHEN amount_eur > (avg_user_amt + (2.5 * stddev_user_amt)) THEN 5
        WHEN daily_velocity > 5 THEN 4
        WHEN (country != home_country AND amount_eur > p95_amount_channel) THEN 4
        ELSE 0 
    END as score_variant_b
FROM {{ ref('int_risk_features') }}
{% if is_incremental() %}
    WHERE transaction_time > (SELECT MAX(transaction_time) FROM {{ this }})
{% endif %}