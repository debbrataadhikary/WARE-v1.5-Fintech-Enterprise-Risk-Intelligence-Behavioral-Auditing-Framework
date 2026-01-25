{{ config(materialized='table') }}

/* Calculating User-Specific Behavioral Metrics
   Using Standard Deviation to avoid heavy sorting overhead of Percentiles.
*/
SELECT 
    user_uuid,
    AVG(amount_eur) AS avg_spend,
    STDDEV(amount_eur) AS std_dev_spend,
    (AVG(amount_eur) + (3 * COALESCE(STDDEV(amount_eur), 0))) AS upper_risk_limit
FROM {{ ref('stg_transactions') }}
GROUP BY 1