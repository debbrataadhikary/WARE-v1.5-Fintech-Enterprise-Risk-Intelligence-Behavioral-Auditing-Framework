{{
  config(
    materialized='incremental',
    unique_key='transaction_id',
    incremental_strategy='merge'
  )
}}

SELECT 
    *,
    -- 1. Deviation Score: Z-Score weight calculation
    -- We use ABS to ensure the weight is always positive for anomaly detection
    ABS((amount_eur - avg_user_amt) / NULLIF(stddev_user_amt, 0)) as z_score_weight,

    -- 2. Peer Ratio: Stress index compared to channel thresholds
    (amount_eur / NULLIF(p95_amount_channel, 0)) as channel_stress_index,

    -- 3. Adaptive Risk Calculation (The Engine)
    -- FIX: Wrapping the logic in GREATEST(..., 0) to prevent negative results
    GREATEST(
        (
            -- Rule A: Behavioral Divergence (Adaptive Weight)
            -- If the amount is below average, we don't want to subtract risk, so we cap it
            CASE 
                WHEN stddev_user_amt > 0 THEN 
                    ((amount_eur - avg_user_amt) / stddev_user_amt) * 2.0 
                ELSE 1.0 
            END +

            -- Rule B: Geographic Volatility (Adaptive Offset)
            (is_geo_mismatch * (amount_eur / NULLIF(avg_user_amt, 0)) * 3.0) +

            -- Rule C: Velocity Pressure
            (daily_velocity * (1.0 + is_geo_mismatch)) 
        ), 
        0
    ) as final_risk_score

FROM {{ ref('int_risk_features') }}
{% if is_incremental() %}
    WHERE transaction_time > (SELECT MAX(transaction_time) FROM {{ this }})
{% endif %}