SELECT 
    user_uuid,
    -- Mapping from 'full_name'
    ENCODE(DIGEST(full_name, 'sha256'), 'hex') AS masked_customer_name,
    
    -- Mapping from 'email'
    ENCODE(DIGEST(email, 'sha256'), 'hex') AS masked_email,
    
    home_country,
    age,
    registration_date,
    initial_deposit_eur,
    ingestion_timestamp
    
FROM {{ source('raw_data', 'bronze_customers') }}

{% if is_incremental() %}
    -- Industry standard incremental logic
    WHERE ingestion_timestamp > (SELECT MAX(t.ingestion_timestamp) FROM {{ this }} AS t)
{% endif %}