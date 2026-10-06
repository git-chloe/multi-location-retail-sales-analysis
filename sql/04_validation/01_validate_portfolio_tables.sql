-- VALIDATE PORTFOLIO TABLE 01
-- Validate Final Portfolio Sales Datasets

-- Purpose:
-- Confirm that the anonymized portfolio tables preserve the validated
-- analytical population and numerical totals of the cleaned source tables
-- while exposing only the approved public structure.
--
-- Private source identifiers and mapping literals are intentionally omitted
-- from the public methodology.


-- ============================================================
-- Step 1: Validate annual portfolio populations
-- ============================================================

SELECT
  2023 AS sale_year,
  COUNT(*) AS total_rows,
  COUNT(DISTINCT transaction_id) AS transaction_events,
  COUNTIF(transaction_id IS NULL) AS missing_transaction_ids,
  COUNTIF(sales_source IS NULL) AS missing_sales_source

FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2023`

UNION ALL

SELECT
  2024,
  COUNT(*),
  COUNT(DISTINCT transaction_id),
  COUNTIF(transaction_id IS NULL),
  COUNTIF(sales_source IS NULL)

FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2024`

UNION ALL

SELECT
  2025,
  COUNT(*),
  COUNT(DISTINCT transaction_id),
  COUNTIF(transaction_id IS NULL),
  COUNTIF(sales_source IS NULL)

FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2025`

ORDER BY sale_year;


-- ============================================================
-- Step 2: Validate approved public sales-source values
-- ============================================================

WITH combined AS (

  SELECT
    2023 AS sale_year,
    sales_source,
    transaction_id
  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2023`

  UNION ALL

  SELECT
    2024,
    sales_source,
    transaction_id
  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2024`

  UNION ALL

  SELECT
    2025,
    sales_source,
    transaction_id
  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2025`
)

SELECT
  sale_year,
  sales_source,
  COUNT(*) AS sale_line_rows,
  COUNT(DISTINCT transaction_id) AS transaction_events

FROM combined

GROUP BY
  sale_year,
  sales_source

ORDER BY
  sale_year,
  sale_line_rows DESC;


-- ============================================================
-- Step 3: Validate public transaction-ID consistency
-- ============================================================
-- Successful result: zero rows.

WITH combined AS (

  SELECT
    2023 AS sale_year,
    transaction_id,
    sale_datetime,
    sales_source
  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2023`

  UNION ALL

  SELECT
    2024,
    transaction_id,
    sale_datetime,
    sales_source
  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2024`

  UNION ALL

  SELECT
    2025,
    transaction_id,
    sale_datetime,
    sales_source
  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2025`
)

SELECT
  sale_year,
  transaction_id,
  COUNT(DISTINCT sale_datetime) AS distinct_sale_datetimes,
  COUNT(DISTINCT sales_source) AS distinct_sales_sources

FROM combined

GROUP BY
  sale_year,
  transaction_id

HAVING
  COUNT(DISTINCT sale_datetime) != 1
  OR COUNT(DISTINCT sales_source) != 1;


-- ============================================================
-- Step 4: Validate exact public schema
-- ============================================================
-- Each annual table is required to contain exactly these 12 fields:
--
--   sale_datetime
--   transaction_id
--   sales_source
--   transaction_attribute
--   quantity
--   subtotal
--   sales_tax
--   discount
--   loyalty
--   total
--   Details
--   Sku
--
-- Private validation additionally confirms that no original receipt,
-- private source-code, or transformation-helper columns survive.


-- ============================================================
-- Final Results
-- ============================================================
--
-- 2023:
--   88,627 rows
--   44,512 transaction events
--
-- 2024:
--   74,872 rows
--   38,203 transaction events
--
-- 2025:
--   57,492 rows
--   27,233 transaction events
--
-- Direct private reconciliation returned zero differences across:
--
--   row counts
--   transaction-event counts
--   quantities
--   subtotal
--   sales tax
--   discount
--   loyalty
--   total sales
--
-- Final private privacy validation returned zero failures.
--
-- Transaction-ID consistency returned zero exceptions.
--
-- Exact-schema validation returned zero mismatches.
--
-- Conclusion:
-- The anonymized annual portfolio datasets preserve the validated analytical
-- structure and numerical results of the cleaned source data while exposing
-- only the approved public-facing schema.