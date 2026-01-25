{{ config(
    materialized='incremental',
    unique_key='transaction_id',
    incremental_strategy='merge'
) }}

/* High-Performance Gold Layer Model: Fraud Adaptive Scoring
   Goal: A/B Sensitivity Testing with 2.5 Sigma vs 3.0 Sigma
*/

SELECT 
    t.*,
    c.home_country,
    
    -- Geography Risk Logic
    CASE 
        WHEN c.home_country = t.country THEN 'LOCAL'
        ELSE 'FOREIGN'
    END AS transaction_origin,
    
    -- Explainability: Deviation from historical mean
    ROUND(t.amount_eur / NULLIF(m.avg_spend, 0), 2) AS increase_factor,
    
    -- Variant A: Conservative Threshold (3.0 Sigma)
    CASE 
        WHEN t.amount_eur > m.upper_risk_limit THEN TRUE 
        ELSE FALSE 
    END AS is_fraud_3sigma,

    -- Variant B: Aggressive Threshold (2.5 Sigma)
    CASE 
        WHEN t.amount_eur > (m.avg_spend + (2.5 * m.std_dev_spend)) THEN TRUE 
        ELSE FALSE 
    END AS is_fraud_2_5sigma,

    -- Risk Level Tagging
    CASE 
        WHEN t.amount_eur > m.upper_risk_limit THEN 'SUSPICIOUS'
        WHEN t.amount_eur > (m.avg_spend + (2.5 * m.std_dev_spend)) THEN 'REVIEW_REQUIRED'
        ELSE 'SAFE'
    END AS adaptive_risk_level

FROM {{ ref('stg_transactions') }} AS t
LEFT JOIN {{ ref('int_user_behavior_metrics') }} AS m 
    ON t.user_uuid = m.user_uuid
LEFT JOIN {{ ref('stg_customers') }} AS c 
    ON t.user_uuid = c.user_uuid

{% if is_incremental() %}
    WHERE t.transaction_time > (SELECT MAX(f.transaction_time) FROM {{ this }} AS f)
{% endif %}