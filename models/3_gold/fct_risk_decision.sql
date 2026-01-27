{{
  config(
    materialized='incremental',
    unique_key='transaction_id',
    incremental_strategy='merge'
  )
}}

-- Step 1: Calculate global risk metrics to define dynamic boundaries
WITH risk_benchmarks AS (
    SELECT 
        AVG(final_risk_score) as avg_score,
        STDDEV(final_risk_score) as stddev_score
    FROM {{ ref('int_risk_scoring') }}
)

SELECT
    transaction_id,
    user_uuid,
    transaction_time,
    amount_eur,
    final_risk_score,
    
    -- Step 2: Dynamic Decision Engine (WARE v1.5 Standard)
    -- Instead of fixed 12, 5, 3, we use Multipliers of the system's average volatility
    CASE 
        WHEN final_risk_score >= (SELECT avg_score + (4.0 * stddev_score) FROM risk_benchmarks) THEN 'REJECT'
        WHEN final_risk_score >= (SELECT avg_score + (2.0 * stddev_score) FROM risk_benchmarks) THEN 'OTP_REQUIRED'
        WHEN final_risk_score >= (SELECT avg_score + (1.0 * stddev_score) FROM risk_benchmarks) THEN 'FLAG_FOR_REVIEW'
        ELSE 'APPROVE'
    END as final_action

FROM {{ ref('int_risk_scoring') }}
{% if is_incremental() %}
    WHERE transaction_time > (SELECT MAX(transaction_time) FROM {{ this }})
{% endif %}