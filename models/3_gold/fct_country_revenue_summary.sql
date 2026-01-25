{{
  config(
    materialized='incremental',
    unique_key='country_key'
  )
}}

SELECT
    {{ dbt_utils.generate_surrogate_key(['country', 'transaction_channel']) }} as country_key, 
    country,
    transaction_channel,
    COUNT(*) as total_transactions,
    SUM(amount_eur) as total_revenue_eur,
    AVG(amount_eur) as avg_transaction_value,
    CURRENT_TIMESTAMP as last_updated_at
FROM {{ ref('stg_transactions') }}
GROUP BY 1, 2, 3