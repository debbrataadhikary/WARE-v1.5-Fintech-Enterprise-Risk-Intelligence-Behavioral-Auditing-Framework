{{
  config(
    materialized='incremental',
    unique_key='transaction_id',
    incremental_strategy='merge',
    on_schema_change='append_new_columns'
  )
}}

-- Step 1: Calculate benchmarks based on the LAST available date in the dataset, NOT current_date
-- This makes the model robust for historical backtesting and real-time.
WITH reference_time AS (
    SELECT MAX(transaction_time) as max_time FROM {{ ref('stg_transactions') }}
),

channel_stats AS (
    SELECT 
        transaction_channel,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY amount_eur) as p99_amount_channel,
        PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY amount_eur) as p95_amount_channel
    FROM {{ ref('stg_transactions') }}
    -- Filter relative to the max data available
    WHERE transaction_time >= (SELECT max_time FROM reference_time) - INTERVAL '90 days'
    GROUP BY 1
),

-- Step 2: Main Enrichment Logic
enriched_base AS (
    SELECT 
        t.*,
        c.home_country,
        s.p99_amount_channel,
        s.p95_amount_channel,
        -- Velocity Feature: Transactions in the last 24 hours per user
        COUNT(*) OVER (
            PARTITION BY t.user_uuid, t.country 
            ORDER BY t.transaction_time 
            RANGE BETWEEN INTERVAL '24 hours' PRECEDING AND CURRENT ROW
        ) as daily_velocity,
        -- Behavioral Profile: Avg and Stddev per user
        AVG(t.amount_eur) OVER (PARTITION BY t.user_uuid) as avg_user_amt,
        COALESCE(STDDEV(t.amount_eur) OVER (PARTITION BY t.user_uuid), 0) as stddev_user_amt
    FROM {{ ref('stg_transactions') }} t
    JOIN {{ ref('stg_customers') }} c ON t.user_uuid = c.user_uuid
    JOIN channel_stats s ON t.transaction_channel = s.transaction_channel
)

-- Step 3: Incremental Filter
SELECT * FROM enriched_base
{% if is_incremental() %}
    -- Only process records newer than the current max in this table
    WHERE transaction_time > (SELECT MAX(transaction_time) FROM {{ this }})
{% else %}
    -- On full refresh, take everything
    WHERE 1=1
{% endif %}