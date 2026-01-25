/* Model: stg_transactions
    Layer: Silver (Staging)
    Strategy: Incremental (Merge)
    Primary Key: transaction_id
    Incremental Key: ingestion_timestamp
*/

{{ config(
    materialized='incremental',
    unique_key='transaction_id',
    incremental_strategy='merge',
    on_schema_change='append_new_columns'
) }}

WITH source_data AS (
    SELECT 
        ingestion_id,
        transaction_id,
        user_uuid,
        card_masked,
        card_token,
        amount_eur::numeric(18, 2) AS amount_eur,
        transaction_time,
        transaction_time::date AS transaction_date,
        country,
        mcc,
        device_id,
        ip_address, -- Re-introduced for Fraud Analytics
        transaction_channel,
        ingestion_timestamp -- Crucial for Audit & Incremental loading
    FROM {{ source('raw_data', 'bronze_transactions') }}
    
    {% if is_incremental() %}
    -- Use ingestion_timestamp to ensure late-arriving data is captured
    WHERE ingestion_timestamp >= (SELECT MAX(ingestion_timestamp) FROM {{ this }})
    {% endif %}
)

SELECT * FROM source_data