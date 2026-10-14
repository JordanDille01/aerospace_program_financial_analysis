-- ============================================================
-- Aerospace Program Financial & Cost Analysis
-- ============================================================
-- Purpose:
-- Analyze aerospace program financial performance, identify
-- significant budget variances, investigate cost drivers,
-- evaluate monthly trends, and flag programs requiring
-- management attention.
--
-- Dataset:
-- Synthetic aerospace program-finance dataset modeled around
-- common program-control and Earned Value Management concepts.
-- ============================================================


-- ============================================================
-- 1. DATABASE SETUP
-- ============================================================

USE aerospace_program_financial_cost_analysis;


-- Raw financial data table
CREATE TABLE IF NOT EXISTS program_financials (
    program_id VARCHAR(10),
    program_name VARCHAR(50),
    customer_type VARCHAR(50),
    program_type VARCHAR(50),
    program_manager VARCHAR(100),
    reporting_month DATE,
    cost_category VARCHAR(50),
    budget_cost DECIMAL(12,2),
    actual_cost DECIMAL(12,2),
    earned_value DECIMAL(12,2),
    forecast_cost DECIMAL(12,2)
);


-- ============================================================
-- 2. DATA VALIDATION
-- ============================================================

-- Validate row count
SELECT
    COUNT(*) AS total_rows
FROM program_financials;


-- Validate reporting period
SELECT
    MIN(reporting_month) AS earliest_month,
    MAX(reporting_month) AS latest_month
FROM program_financials;


-- Validate programs
SELECT DISTINCT
    program_name
FROM program_financials
ORDER BY program_name;


-- Validate cost categories
SELECT DISTINCT
    cost_category
FROM program_financials
ORDER BY cost_category;


-- Check core financial fields for missing values
SELECT
    SUM(CASE WHEN budget_cost IS NULL THEN 1 ELSE 0 END)
        AS missing_budget,
    SUM(CASE WHEN actual_cost IS NULL THEN 1 ELSE 0 END)
        AS missing_actual,
    SUM(CASE WHEN earned_value IS NULL THEN 1 ELSE 0 END)
        AS missing_earned_value,
    SUM(CASE WHEN forecast_cost IS NULL THEN 1 ELSE 0 END)
        AS missing_forecast
FROM program_financials;


-- ============================================================
-- 3. FINANCIAL METRICS VIEW
-- ============================================================

-- Create analysis-ready view containing source fields
-- and calculated financial performance metrics
CREATE OR REPLACE VIEW vw_program_financial_metrics AS
SELECT
    program_id,
    program_name,
    customer_type,
    program_type,
    program_manager,
    reporting_month,
    cost_category,
    budget_cost,
    actual_cost,
    earned_value,
    forecast_cost,

    -- Positive = unfavorable
    actual_cost - budget_cost AS budget_variance,

    -- Positive = unfavorable
    (actual_cost - budget_cost) / NULLIF(budget_cost, 0)
        AS budget_variance_pct,

    -- Positive = favorable
    earned_value - actual_cost AS cost_variance,

    -- Above 1.00 = favorable
    earned_value / NULLIF(actual_cost, 0)
        AS cpi

FROM program_financials;


-- Validate financial metrics view
SELECT *
FROM vw_program_financial_metrics
LIMIT 10;


-- ============================================================
-- 4. PROGRAM PERFORMANCE ANALYSIS
-- ============================================================

-- Compare program-level financial performance
SELECT
    program_name,
    SUM(budget_cost) AS total_budget_cost,
    SUM(actual_cost) AS total_actual_cost,
    SUM(budget_variance) AS total_budget_variance,

    SUM(budget_variance) / NULLIF(SUM(budget_cost), 0)
        AS budget_variance_pct,

    SUM(cost_variance) AS total_cost_variance,

    SUM(earned_value) / NULLIF(SUM(actual_cost), 0)
        AS cpi

FROM vw_program_financial_metrics
GROUP BY program_name
ORDER BY total_budget_variance DESC;


-- ============================================================
-- 5. VARIANCE DRIVER ANALYSIS
-- ============================================================

-- Rank budget variance by program and cost category
SELECT
    program_name,
    cost_category,
    SUM(budget_cost) AS total_budget_cost,
    SUM(actual_cost) AS total_actual_cost,
    SUM(budget_variance) AS total_budget_variance
FROM vw_program_financial_metrics
GROUP BY
    program_name,
    cost_category
ORDER BY total_budget_variance DESC;


-- Orion variance drivers by cost category
SELECT
    cost_category,
    SUM(budget_cost) AS total_budget_cost,
    SUM(actual_cost) AS total_actual_cost,
    SUM(budget_variance) AS total_budget_variance
FROM vw_program_financial_metrics
WHERE program_name = 'Orion'
GROUP BY cost_category
ORDER BY total_budget_variance DESC;


-- Orion Materials share of total budget variance
SELECT
    SUM(
        CASE
            WHEN cost_category = 'Materials'
                THEN budget_variance
            ELSE 0
        END
    ) AS materials_variance,

    SUM(budget_variance) AS total_program_variance,

    SUM(
        CASE
            WHEN cost_category = 'Materials'
                THEN budget_variance
            ELSE 0
        END
    ) / NULLIF(SUM(budget_variance), 0) * 100
        AS materials_variance_pct

FROM vw_program_financial_metrics
WHERE program_name = 'Orion';


-- Sentinel variance drivers by cost category
SELECT
    cost_category,
    SUM(budget_cost) AS total_budget_cost,
    SUM(actual_cost) AS total_actual_cost,
    SUM(budget_variance) AS total_budget_variance
FROM vw_program_financial_metrics
WHERE program_name = 'Sentinel'
GROUP BY cost_category
ORDER BY total_budget_variance DESC;


-- Sentinel Labor share of total budget variance
SELECT
    SUM(
        CASE
            WHEN cost_category = 'Labor'
                THEN budget_variance
            ELSE 0
        END
    ) AS labor_variance,

    SUM(budget_variance) AS total_program_variance,

    SUM(
        CASE
            WHEN cost_category = 'Labor'
                THEN budget_variance
            ELSE 0
        END
    ) / NULLIF(SUM(budget_variance), 0) * 100
        AS labor_variance_pct

FROM vw_program_financial_metrics
WHERE program_name = 'Sentinel';


-- ============================================================
-- 6. MONTHLY TREND ANALYSIS
-- ============================================================

-- Orion Materials monthly budget variance
SELECT
    reporting_month,
    SUM(budget_cost) AS monthly_budget_cost,
    SUM(actual_cost) AS monthly_actual_cost,
    SUM(budget_variance) AS monthly_budget_variance
FROM vw_program_financial_metrics
WHERE program_name = 'Orion'
    AND cost_category = 'Materials'
GROUP BY reporting_month
ORDER BY reporting_month;


-- Sentinel Labor monthly budget variance
SELECT
    reporting_month,
    SUM(budget_cost) AS monthly_budget_cost,
    SUM(actual_cost) AS monthly_actual_cost,
    SUM(budget_variance) AS monthly_budget_variance
FROM vw_program_financial_metrics
WHERE program_name = 'Sentinel'
    AND cost_category = 'Labor'
GROUP BY reporting_month
ORDER BY reporting_month;


-- ============================================================
-- 7. MANAGEMENT ATTENTION ANALYSIS
-- ============================================================

-- Project-defined thresholds:
-- High Attention = >= 2.5% over budget
-- Monitor        = >= 1.0% and < 2.5% over budget
-- On Track       = < 1.0% over budget
--
-- Thresholds are illustrative analytical rules created for
-- this portfolio project and are not presented as aerospace
-- industry standards.

SELECT
    program_name,
    SUM(budget_cost) AS total_budget_cost,
    SUM(actual_cost) AS total_actual_cost,
    SUM(budget_variance) AS total_budget_variance,

    SUM(budget_variance) / NULLIF(SUM(budget_cost), 0)
        AS budget_variance_pct,

    CASE
        WHEN SUM(budget_variance) / NULLIF(SUM(budget_cost), 0) >= 0.025
            THEN 'High Attention'

        WHEN SUM(budget_variance) / NULLIF(SUM(budget_cost), 0) >= 0.01
            THEN 'Monitor'

        ELSE 'On Track'
    END AS management_status

FROM vw_program_financial_metrics
GROUP BY program_name
ORDER BY total_budget_variance DESC;


-- ============================================================
-- 8. ANALYTICAL FINDINGS
-- ============================================================

-- 1. Portfolio Performance
-- The six-program portfolio recorded approximately $2.62M
-- in unfavorable budget variance across the reporting period.

-- 2. Primary Programs Requiring Attention
-- Orion recorded approximately $1.56M in unfavorable budget
-- variance, while Sentinel recorded approximately $888K.

-- 3. Orion Variance Driver
-- Materials generated approximately $1.07M in unfavorable
-- variance, accounting for approximately 68.6% of Orion's
-- total budget variance.
-- The sustained Materials overrun began in June 2024.

-- 4. Sentinel Variance Driver
-- Labor generated approximately $845K in unfavorable variance,
-- accounting for approximately 95.2% of Sentinel's total
-- budget variance.
-- The sustained Labor overrun began in August 2024.

-- 5. Management Attention
-- Using project-defined management thresholds, Orion and
-- Sentinel are classified as High Attention based on their
-- program-level budget variance percentages.
--
-- High Attention: >= 2.5% over budget
-- Monitor:        >= 1.0% and < 2.5% over budget
-- On Track:       < 1.0% over budget