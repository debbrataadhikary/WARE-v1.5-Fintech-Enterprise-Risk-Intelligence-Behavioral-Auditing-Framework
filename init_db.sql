CREATE EXTENSION IF NOT EXISTS "uuid-ossp";


CREATE SCHEMA IF NOT EXISTS raw_data;


CREATE TABLE IF NOT EXISTS raw_data.bronze_customers (
    ingestion_id INTEGER,
    user_uuid UUID PRIMARY KEY,
    full_name VARCHAR(255),
    email VARCHAR(255),
    home_country VARCHAR(100),
    age INTEGER,
    registration_date DATE,
    ingestion_timestamp TIMESTAMP WITHOUT TIME ZONE,
    initial_deposit_eur NUMERIC(18,2)
);


CREATE TABLE IF NOT EXISTS raw_data.bronze_transactions (
    ingestion_id INTEGER,
    transaction_id UUID PRIMARY KEY,
    user_uuid UUID,
    card_masked VARCHAR(20),
    card_token VARCHAR(64),
    amount_eur NUMERIC(15,2),
    transaction_time TIMESTAMP WITHOUT TIME ZONE,
    country VARCHAR(100),
    mcc VARCHAR(10),
    device_id VARCHAR(100),
    ip_address VARCHAR(45),
    transaction_channel VARCHAR(20),
    ingestion_timestamp TIMESTAMP WITHOUT TIME ZONE
);


INSERT INTO raw_data.bronze_customers (user_uuid, full_name, email) 
VALUES (uuid_generate_v4(), 'CI Test User', 'test@example.com') 
ON CONFLICT DO NOTHING;