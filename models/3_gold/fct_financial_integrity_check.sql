{{ config(
    materialized='table'
) }}

/* Section 3: Financial Integrity & Reconciliation
   Goal: Detect balance mismatch where spending exceeds initial deposit.
   Constraint: All code comments and logic labels must be in English.
*/

WITH customer_deposits AS (
    -- Get initial deposit for each customer
    SELECT 
        user_uuid,
        initial_deposit_eur
    FROM {{ ref('stg_customers') }}
),

transaction_summary AS (
    -- Calculate total spending per customer
    SELECT 
        user_uuid,
        SUM(amount_eur) as total_spent_eur,
        COUNT(transaction_id) as transaction_count
    FROM {{ ref('stg_transactions') }}
    GROUP BY 1
)

SELECT 
    c.user_uuid,
    c.initial_deposit_eur,
    COALESCE(t.total_spent_eur, 0) as total_spent_eur,
    -- Calculate remaining balance
    (c.initial_deposit_eur - COALESCE(t.total_spent_eur, 0)) as remaining_balance,
    
    -- Integrity Check Logic
    CASE 
        WHEN (c.initial_deposit_eur - COALESCE(t.total_spent_eur, 0)) < 0 THEN 'INTEGRITY_BREACH'
        ELSE 'VALID'
    END as integrity_status

FROM customer_deposits c
LEFT JOIN transaction_summary t ON c.user_uuid = t.user_uuid