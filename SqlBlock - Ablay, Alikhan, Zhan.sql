-- Task 1: List of clients with continuous history for the year

-- This query selects clients who made transactions every month between 06/01/2015 and 06/01/2016,
-- calculates their average receipt for the year, average monthly purchases, and total transactions.

-- Step 1: Summarizing monthly transactions per client
WITH monthly_transactions AS (
    SELECT 
        Id_client,
        DATE_TRUNC('month', date_new::DATE) AS month,  -- Extracting the month
        SUM(Sum_payment) AS monthly_sum,  -- Total payment for each month
        COUNT(Id_check) AS monthly_transactions  -- Total transactions for each month
    FROM 
        transactions_info
    WHERE 
        date_new BETWEEN '2015-06-01' AND '2016-06-01'  -- Filtering date range to cover the full year
    GROUP BY 
        Id_client, DATE_TRUNC('month', date_new::DATE)  -- Group by client and month to get monthly sums
),

-- Step 2: Aggregating client transactions for the year
client_summary AS (
    SELECT 
        Id_client,
        COUNT(DISTINCT month) AS active_months,  -- Counting distinct months with activity for each client
        SUM(monthly_sum) / 12 AS avg_period_receipt,  -- Calculating average receipt for the entire period (06/01/2015 to 06/01/2016)
        AVG(monthly_transactions) AS avg_monthly_transactions,  -- Average number of transactions per month
        SUM(monthly_transactions) AS total_transactions -- Total number of transactions over the entire period
    FROM 
        monthly_transactions
    GROUP BY 
        Id_client
    HAVING 
        COUNT(DISTINCT month) = 12  -- Ensuring the client was active in every month of the period
)

-- Step 3: Final output with client details
SELECT 
    client_summary.Id_client,  -- Client ID
    client_summary.avg_period_receipt,  -- Average receipt for the period from 06/01/2015 to 06/01/2016
    client_summary.avg_monthly_transactions,  -- Average number of transactions per month
    client_summary.total_transactions  -- Total transactions for the client during the period
FROM 
    client_summary;




-- Task 2: Information by month

-- This query calculates the following metrics for each month:
-- 1. Average amount of the check per month.
-- 2. Average number of operations (transactions) per month.
-- 3. Average number of clients who performed transactions each month.
-- 4. Share of total transactions for the year and share per month of the total amount of transactions.
-- 5. Percentage ratio of M/F/NA (Male/Female/Non-Applicable) in each month with their share of costs.

-- Step 1: Summarizing monthly transactions and client demographics
WITH monthly_data AS (
    SELECT 
        DATE_TRUNC('month', ti.date_new::DATE) AS month,  -- Extracting the month
        SUM(ti.Sum_payment) AS total_sum,  -- Total payment for the month
        COUNT(ti.Id_check) AS total_transactions,  -- Total number of transactions in the month
        COUNT(DISTINCT ti.Id_client) AS num_clients,  -- Number of distinct clients who made transactions
        AVG(ti.Sum_payment) AS avg_check,  -- Average check (payment) per transaction in the month
        AVG(CASE WHEN ci.gender = 'M' THEN 1 ELSE 0 END) * 100 AS male_percentage,  -- % Male clients
        AVG(CASE WHEN ci.gender = 'F' THEN 1 ELSE 0 END) * 100 AS female_percentage,  -- % Female clients
        AVG(CASE WHEN ci.gender IS NULL THEN 1 ELSE 0 END) * 100 AS na_percentage  -- % Non-Applicable (NA) clients
    FROM 
        transactions_info ti
    LEFT JOIN 
        customer_info ci ON ti.Id_client = ci.Id_client  -- Joining with customer info for gender
    WHERE 
        ti.date_new BETWEEN '2015-06-01' AND '2016-06-01'  -- Filtering the date range for the year
    GROUP BY 
        DATE_TRUNC('month', ti.date_new::DATE)  -- Grouping by month to get monthly totals
),

-- Step 2: Summarizing yearly totals for the share calculations
yearly_totals AS (
    SELECT
        SUM(ti.Sum_payment) AS yearly_total_sum,  -- Total sum of all payments for the year
        COUNT(ti.Id_check) AS yearly_total_transactions  -- Total number of transactions for the year
    FROM 
        transactions_info ti
    WHERE 
        ti.date_new BETWEEN '2015-06-01' AND '2016-06-01'  -- Filtering for the year
)

-- Step 3: Final output with monthly statistics
SELECT 
    md.month,  -- The month
    AVG(md.avg_check) AS avg_check,  -- Average check per month (aggregated over months)
    AVG(md.total_transactions) AS avg_monthly_operations,  -- Average number of operations (transactions) per month
    AVG(md.num_clients) AS avg_monthly_clients,  -- Average number of clients per month
    AVG(md.total_transactions) / yt.yearly_total_transactions * 100 AS transaction_share,  -- Share of total transactions for the year per month
    AVG(md.total_sum) / yt.yearly_total_sum * 100 AS amount_share,  -- Share of total transaction amount for the year per month
    AVG(md.male_percentage) AS male_percentage,  -- Male percentage for the month
    AVG(md.female_percentage) AS female_percentage,  -- Female percentage for the month
    AVG(md.na_percentage) AS na_percentage  -- Non-Applicable (NA) percentage for the month
FROM 
    monthly_data md, yearly_totals yt
GROUP BY 
    md.month, yt.yearly_total_transactions, yt.yearly_total_sum;



-- Task 3: Age groups of clients and their transaction details

-- This query calculates:
-- 1. Total amount and number of transactions for each client age group (increments of 10 years).
-- 2. Separate statistics for clients without age information.
-- 3. Quarterly averages and percentages of transactions.

-- Step 1: Categorizing clients by age and summarizing their transactions
WITH client_age_group AS (
    SELECT 
        CASE 
            WHEN ci.age IS NULL THEN 'Unknown'  -- Clients without age information
            WHEN ci.age BETWEEN 0 AND 9 THEN '0-9'
            WHEN ci.age BETWEEN 10 AND 19 THEN '10-19'
            WHEN ci.age BETWEEN 20 AND 29 THEN '20-29'
            WHEN ci.age BETWEEN 30 AND 39 THEN '30-39'
            WHEN ci.age BETWEEN 40 AND 49 THEN '40-49'
            WHEN ci.age BETWEEN 50 AND 59 THEN '50-59'
            WHEN ci.age BETWEEN 60 AND 69 THEN '60-69'
            WHEN ci.age BETWEEN 70 AND 79 THEN '70-79'
            ELSE '80+'  -- Clients 80 years old and older
        END AS age_group,
        ti.Id_client,
        SUM(ti.Sum_payment) AS total_amount,  -- Total amount for the client in the period
        COUNT(ti.Id_check) AS total_transactions  -- Total transactions for the client in the period
    FROM 
        transactions_info ti
    LEFT JOIN 
        customer_info ci ON ti.Id_client = ci.Id_client  -- Joining with customer info for age
    WHERE 
        ti.date_new BETWEEN '2015-06-01' AND '2016-06-01'  -- Filtering for the period
    GROUP BY 
        age_group, ti.Id_client
),

-- Step 2: Summarizing quarterly data for each age group
quarterly_data AS (
    SELECT 
        CASE 
            WHEN ci.age IS NULL THEN 'Unknown'  -- Clients without age information
            WHEN ci.age BETWEEN 0 AND 9 THEN '0-9'
            WHEN ci.age BETWEEN 10 AND 19 THEN '10-19'
            WHEN ci.age BETWEEN 20 AND 29 THEN '20-29'
            WHEN ci.age BETWEEN 30 AND 39 THEN '30-39'
            WHEN ci.age BETWEEN 40 AND 49 THEN '40-49'
            WHEN ci.age BETWEEN 50 AND 59 THEN '50-59'
            WHEN ci.age BETWEEN 60 AND 69 THEN '60-69'
            WHEN ci.age BETWEEN 70 AND 79 THEN '70-79'
            ELSE '80+'  -- Clients 80 years old and older
        END AS age_group,
        DATE_TRUNC('quarter', ti.date_new::DATE) AS quarter,  -- Extracting the quarter
        ti.Id_client,
        ti.Sum_payment,
        ti.Id_check  -- Include Id_check for counting transactions
    FROM 
        transactions_info ti
    LEFT JOIN 
        customer_info ci ON ti.Id_client = ci.Id_client  -- Joining with customer info for age
    WHERE 
        ti.date_new BETWEEN '2015-06-01' AND '2016-06-01'  -- Filtering for the period
),

-- Step 3: Aggregating quarterly statistics per age group
quarterly_aggregation AS (
    SELECT 
        age_group,
        quarter,
        COUNT(DISTINCT Id_client) AS num_clients,  -- Number of clients in the quarter
        AVG(SUM(Sum_payment)) OVER (PARTITION BY age_group, quarter) AS avg_transaction_amount,  -- Average transaction amount per quarter
        COUNT(Id_check) AS total_transactions_in_quarter  -- Total number of transactions per quarter
    FROM 
        quarterly_data
    GROUP BY 
        age_group, quarter
)

-- Step 4: Final output with aggregated data and percentages for age groups
SELECT 
    cag.age_group,  -- The age group
    SUM(cag.total_amount) AS total_amount,  -- Total amount for the entire period for each age group
    SUM(cag.total_transactions) AS total_transactions,  -- Total number of transactions for the entire period
    AVG(qd.avg_transaction_amount) AS avg_transaction_amount,  -- Average transaction amount per quarter
    AVG(qd.num_clients) AS avg_num_clients,  -- Average number of clients per quarter
    (SUM(qd.total_transactions_in_quarter) / SUM(cag.total_transactions) * 100) AS quarterly_transactions_percentage  -- % of total transactions per quarter
FROM 
    client_age_group cag
LEFT JOIN 
    quarterly_aggregation qd ON cag.age_group = qd.age_group  -- Joining with quarterly aggregation data
GROUP BY 
    cag.age_group;
