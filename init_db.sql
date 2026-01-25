-- 1. Enable Required Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 2. Schema Setup
CREATE SCHEMA IF NOT EXISTS raw_data;

-- 3. Industry Standard: Clear old data to maintain idempotency
TRUNCATE raw_data.bronze_customers, raw_data.bronze_transactions CASCADE;

-- 4. Insert Real-World Seed Data (Based on your pgAdmin screenshots)
DO $$
DECLARE
    -- Using a real UUID pattern from your customer screenshot (image_552216.png)
    v_user_uuid UUID := '374bd3a9-c90c-4ab2-bd58-67df7bca31a9'; 
BEGIN
    -- Insert into Customers with real data points from your image
    INSERT INTO raw_data.bronze_customers (
        ingestion_id, user_uuid, full_name, email, home_country, age, registration_date, ingestion_timestamp, initial_deposit_eur
    )
    VALUES (
        1335001, v_user_uuid, 'User_374bd3a9', '374bd3a9@example.com', 'Norway', 33, '2024-04-17', '2026-01-23 12:44:28.980279', 9818.20
    );

    -- Insert into Transactions using matching user_uuid to pass 'relationships' test (image_551ece.png)
    INSERT INTO raw_data.bronze_transactions (
        ingestion_id, transaction_id, user_uuid, card_masked, card_token, amount_eur, transaction_time, country, mcc, device_id, ip_address, transaction_channel, ingestion_timestamp
    )
    VALUES (
        5113296, 'cc991a50-4196-4a60-a78d-e0e3b3240a5b', v_user_uuid, '402918******4416', 'a382e1c28331f25e7b6d21c9b6fadbabc88c3e4976936d0009403c87c264789d', 
        546.37, '2025-02-18 10:00:00', 'Germany', '5411', 'DEV-EB8C72', '127.0.0.1', 'POS', '2026-01-23 12:44:30.498995'
    );
END $$;