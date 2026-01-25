-- Enable industry standard extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp"; -- For UUID generation
CREATE EXTENSION IF NOT EXISTS "pgcrypto";  -- For SHA256 hashing functions

-- Create source schema as per dbt lineage graph
CREATE SCHEMA IF NOT EXISTS raw_data;

-- Define Bronze Customers table structure
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

-- Define Bronze Transactions table structure
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

-- Seed initial data for CI/CD pipeline validation
INSERT INTO raw_data.bronze_customers (user_uuid, full_name, email, ingestion_timestamp) 
VALUES (uuid_generate_v4(), 'CI System Auditor', 'audit@fintech.com', CURRENT_TIMESTAMP) 
ON CONFLICT DO NOTHING;

INSERT INTO raw_data.bronze_transactions (transaction_id, user_uuid, amount_eur, ingestion_timestamp) 
VALUES (uuid_generate_v4(), uuid_generate_v4(), 1000.00, CURRENT_TIMESTAMP) 
ON CONFLICT DO NOTHING;