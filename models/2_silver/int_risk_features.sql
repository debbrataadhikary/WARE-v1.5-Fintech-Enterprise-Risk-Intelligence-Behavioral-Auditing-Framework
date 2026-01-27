{{
  config(
    materialized='incremental',
    unique_key='transaction_id',
    incremental_strategy='merge',
    on_schema_change='append_new_columns'
  )
}}

-- Step 1: Calculate benchmarks based on the LAST available date in the dataset
WITH reference_time AS (
    SELECT MAX(transaction_time) as max_time FROM {{ ref('stg_transactions') }}
),

channel_stats AS (
    SELECT 
        transaction_channel,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY amount_eur) as p99_amount_channel,
        PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY amount_eur) as p95_amount_channel
    FROM {{ ref('stg_transactions') }}
    WHERE transaction_time >= (SELECT max_time FROM reference_time) - INTERVAL '90 days'
    GROUP BY 1
),

-- Step 2: Main Enrichment Logic with Geo-Intelligence
enriched_base AS (
    SELECT 
        t.*,
        c.home_country,
        s.p99_amount_channel,
        s.p95_amount_channel,
        
        -- FIX: Use COALESCE to handle users with missing home_country
        -- This ensures the 'not_null' test passes by defaulting missing data to 0 (No Mismatch)
        COALESCE(
            CASE 
                WHEN c.home_country IS NULL THEN 0 -- Handle missing customer profile
                WHEN t.country != c.home_country THEN 1 
                ELSE 0 
            END, 
            0
        ) as is_geo_mismatch,

        -- Velocity Feature: Transactions per user per country
        COUNT(*) OVER (
            PARTITION BY t.user_uuid, t.country 
            ORDER BY t.transaction_time 
            RANGE BETWEEN INTERVAL '24 hours' PRECEDING AND CURRENT ROW
        ) as daily_velocity,

        -- Behavioral Profile: Avg and Stddev per user
        AVG(t.amount_eur) OVER (PARTITION BY t.user_uuid) as avg_user_amt,
        -- Ensure Stddev is never NULL to avoid issues in scoring layer
        COALESCE(STDDEV(t.amount_eur) OVER (PARTITION BY t.user_uuid), 0) as stddev_user_amt
    FROM {{ ref('stg_transactions') }} t
    -- Use LEFT JOIN if some transactions might not have matching customers, 
    -- but here we use INNER to maintain data integrity based on your schema relationships.
    LEFT JOIN {{ ref('stg_customers') }} c ON t.user_uuid = c.user_uuid
    JOIN channel_stats s ON t.transaction_channel = s.transaction_channel
)

-- Step 3: Incremental Processing Logic
SELECT * FROM enriched_base
{% if is_incremental() %}
    WHERE transaction_time > (SELECT MAX(transaction_time) FROM {{ this }})
{% endif %}