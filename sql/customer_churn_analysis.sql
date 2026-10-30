
-- Customer Churn Analysis
-- SQL dialect: SQLite 3
-- Source: data/customers_raw.csv
-- Import the CSV into SQLite as a table named customers_raw before running.
-- The CTE below standardizes common raw-data inconsistencies and removes duplicate IDs.

DROP VIEW IF EXISTS churn_analysis;
CREATE TEMP VIEW churn_analysis AS
WITH normalized AS (
    SELECT
        TRIM(customer_id) AS customer_id,
        NULLIF(TRIM(signup_date), '') AS signup_date,
        CASE LOWER(TRIM(plan))
            WHEN 'basic' THEN 'Basic'
            WHEN 'standard' THEN 'Standard'
            WHEN 'premium' THEN 'Premium'
            ELSE TRIM(plan)
        END AS plan,
        CAST(REPLACE(REPLACE(TRIM(monthly_fee), '₹', ''), ' ', '') AS REAL) AS monthly_fee,
        CASE UPPER(TRIM(acquisition_channel))
            WHEN 'ORGANIC SEARCH' THEN 'Organic Search'
            WHEN 'PAID ADS' THEN 'Paid Ads'
            WHEN 'PARTNER' THEN 'Partner'
            WHEN 'REFERRAL' THEN 'Referral'
            WHEN 'SOCIAL' THEN 'Social'
            ELSE TRIM(acquisition_channel)
        END AS acquisition_channel,
        tenure_days,
        monthly_logins,
        support_tickets_90d,
        late_payments_90d,
        satisfaction_score,
        NULLIF(TRIM(last_active_date), '') AS last_active_date,
        CASE LOWER(TRIM(is_churned))
            WHEN '1' THEN 1
            WHEN 'yes' THEN 1
            WHEN 'true' THEN 1
            WHEN '0' THEN 0
            WHEN 'no' THEN 0
            WHEN 'false' THEN 0
            ELSE NULL
        END AS is_churned,
        ROW_NUMBER() OVER (
            PARTITION BY TRIM(customer_id)
            ORDER BY TRIM(customer_id)
        ) AS row_num
    FROM customers_raw
),
customers AS (
    SELECT *
    FROM normalized
    WHERE row_num = 1
      AND customer_id IS NOT NULL
      AND is_churned IS NOT NULL
),
segmented AS (
    SELECT *,
        CASE
            WHEN monthly_logins BETWEEN 0 AND 4 THEN '0-4'
            WHEN monthly_logins BETWEEN 5 AND 9 THEN '5-9'
            WHEN monthly_logins BETWEEN 10 AND 19 THEN '10-19'
            ELSE '20+'
        END AS monthly_logins_band,
        CASE
            WHEN tenure_days BETWEEN 0 AND 120 THEN '0-120 days'
            WHEN tenure_days BETWEEN 121 AND 365 THEN '121-365 days'
            WHEN tenure_days BETWEEN 366 AND 730 THEN '1-2 years'
            ELSE '2+ years'
        END AS tenure_band
    FROM customers
)
SELECT * FROM segmented;

-- 1. Overall customer and churn KPIs
SELECT
    COUNT(*) AS total_customers,
    SUM(is_churned) AS churned_customers,
    COUNT(*) - SUM(is_churned) AS active_customers,
    ROUND(100.0 * SUM(is_churned) / COUNT(*), 2) AS churn_rate_pct
FROM churn_analysis;

-- 2. Churn by subscription plan
SELECT
    plan,
    COUNT(*) AS customers,
    SUM(is_churned) AS churned_customers,
    ROUND(100.0 * SUM(is_churned) / COUNT(*), 2) AS churn_rate_pct
FROM churn_analysis
GROUP BY plan
ORDER BY churn_rate_pct DESC;

-- 3. Churn by acquisition channel
SELECT
    acquisition_channel,
    COUNT(*) AS customers,
    SUM(is_churned) AS churned_customers,
    ROUND(100.0 * SUM(is_churned) / COUNT(*), 2) AS churn_rate_pct
FROM churn_analysis
GROUP BY acquisition_channel
ORDER BY churn_rate_pct DESC;

-- 4. Churn by tenure band
SELECT
    tenure_band,
    COUNT(*) AS customers,
    SUM(is_churned) AS churned_customers,
    ROUND(100.0 * SUM(is_churned) / COUNT(*), 2) AS churn_rate_pct
FROM churn_analysis
GROUP BY tenure_band
ORDER BY
    CASE tenure_band
        WHEN '0-120 days' THEN 1
        WHEN '121-365 days' THEN 2
        WHEN '1-2 years' THEN 3
        ELSE 4
    END;

-- 5. Churn by monthly login frequency
SELECT
    monthly_logins_band,
    COUNT(*) AS customers,
    SUM(is_churned) AS churned_customers,
    ROUND(100.0 * SUM(is_churned) / COUNT(*), 2) AS churn_rate_pct
FROM churn_analysis
GROUP BY monthly_logins_band
ORDER BY
    CASE monthly_logins_band
        WHEN '0-4' THEN 1
        WHEN '5-9' THEN 2
        WHEN '10-19' THEN 3
        ELSE 4
    END;

-- 6. Churn by number of support tickets in the last 90 days
SELECT
    support_tickets_90d,
    COUNT(*) AS customers,
    SUM(is_churned) AS churned_customers,
    ROUND(100.0 * SUM(is_churned) / COUNT(*), 2) AS churn_rate_pct
FROM churn_analysis
GROUP BY support_tickets_90d
ORDER BY support_tickets_90d;

-- 7. Churn by number of late payments in the last 90 days
SELECT
    late_payments_90d,
    COUNT(*) AS customers,
    SUM(is_churned) AS churned_customers,
    ROUND(100.0 * SUM(is_churned) / COUNT(*), 2) AS churn_rate_pct
FROM churn_analysis
GROUP BY late_payments_90d
ORDER BY late_payments_90d;

-- 8. Churn by satisfaction score (individual score)
SELECT
    satisfaction_score,
    COUNT(*) AS customers,
    SUM(is_churned) AS churned_customers,
    ROUND(100.0 * SUM(is_churned) / COUNT(*), 2) AS churn_rate_pct
FROM churn_analysis
WHERE satisfaction_score IS NOT NULL
GROUP BY satisfaction_score
ORDER BY satisfaction_score;
