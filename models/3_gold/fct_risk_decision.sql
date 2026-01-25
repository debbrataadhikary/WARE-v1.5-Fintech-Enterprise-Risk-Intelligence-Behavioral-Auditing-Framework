{{
  config(
    materialized='incremental',
    unique_key='transaction_id',
    incremental_strategy='merge'
  )
}}

SELECT
    transaction_id,
    user_uuid,
    transaction_time,
    amount_eur,
    final_risk_score,
    CASE 
        WHEN final_risk_score >= 12 THEN 'REJECT'            -- At least 2 major rules broken
        WHEN final_risk_score BETWEEN 5 AND 11 THEN 'OTP_REQUIRED' -- Suspicious behavior
        WHEN final_risk_score >= 3 THEN 'FLAG_FOR_REVIEW'    -- Minor anomaly
        ELSE 'APPROVE'
    END as final_action
FROM {{ ref('int_risk_scoring') }}
{% if is_incremental() %}
    WHERE transaction_time > (SELECT MAX(transaction_time) FROM {{ this }})
{% endif %}