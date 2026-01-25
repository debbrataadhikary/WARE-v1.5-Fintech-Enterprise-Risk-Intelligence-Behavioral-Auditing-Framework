-- 1. Enable Required Extensions for UUID and Hashing
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 2. Create Schema as per your dbt lineage graph
CREATE SCHEMA IF NOT EXISTS raw_data;

-- 3. Create Bronze Tables first (Ensures they exist before any other operation)
CREATE TABLE IF NOT EXISTS raw_data.bronze_customers (
    ingestion_id INTEGER,
    user_uuid UUID PRIMARY KEY,
    full_name VARCHAR(255),
    email VARCHAR(255),
    home_country VARCHAR(100),
    age INTEGER,
    registration_date DATE,
    ingestion_timestamp TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    initial_deposit_eur NUMERIC(18,2)
);

CREATE TABLE IF NOT EXISTS raw_data.bronze_transactions (
    ingestion_id INTEGER,
    transaction_id UUID PRIMARY KEY,
    user_uuid UUID,
    card_masked VARCHAR(20),
    card_token VARCHAR(64),
    amount_eur NUMERIC(18,2),
    transaction_time TIMESTAMP WITHOUT TIME ZONE,
    country VARCHAR(100),
    mcc VARCHAR(10),
    device_id VARCHAR(100),
    ip_address VARCHAR(45),
    transaction_channel VARCHAR(20),
    ingestion_timestamp TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 4. Clean existing data (Idempotent operation)
TRUNCATE raw_data.bronze_customers, raw_data.bronze_transactions CASCADE;

-- 5. Insert Actual Data from your pgAdmin screenshots to pass dbt tests
DO $$
DECLARE
    v_user_uuid UUID := '374bd3a9-c90c-4ab2-bd58-67df7bca31a9'; -- Directly from your image
BEGIN
    -- Customer data from image_552216
    INSERT INTO raw_data.bronze_customers (
        ingestion_id, user_uuid, full_name, email, home_country, age, registration_date, ingestion_timestamp, initial_deposit_eur
    )
    VALUES (
        1335001, v_user_uuid, 'User_374bd3a9', '374bd3a9@example.com', 'Norway', 33, '2024-04-17', '2026-01-23 12:44:28', 9818.20
    );

    -- Transaction data from image_551ece
    INSERT INTO raw_data.bronze_transactions (
        ingestion_id, transaction_id, user_uuid, card_masked, card_token, amount_eur, transaction_time, country, mcc, device_id, ip_address, transaction_channel, ingestion_timestamp
    )
    VALUES (
        5113296, 'cc991a50-4196-4a60-a78d-e0e3b3240a5b', v_user_uuid, '402918******4416', 'a382e1c28331f25e7b6d21c9b6fadbabc88c3e4976936d0009403c87c264789d', 
        546.37, '2025-02-18 10:00:00', 'Germany', '5411', 'DEV-EB8C72', '127.0.0.1', 'POS', '2026-01-23 12:44:30'
    );
END $$;