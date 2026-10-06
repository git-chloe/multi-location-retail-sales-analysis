-- ANALYSIS 03
-- Transaction Composition & Basket Behaviour


-- Purpose:
-- Examine how standard retail transaction composition changed across
-- Store A-D and Online / Event during equivalent January 1 - October 29
-- periods in 2023, 2024, and 2025.
--
-- This analysis separates three related but different concepts:
--
--   1. Basket quantity
--      Measured using priced_net_units, which counts quantity only from
--      Sale Lines with a non-zero subtotal.
--
--   2. Transaction complexity
--      Measured using Sale Line count and distinct SKU count.
--
--   3. Overall business activity
--      Preserved in the underlying portfolio datasets, which retain all
--      legitimate Sale Lines including $0 operational/component lines.
--
-- This distinction is necessary because some valid transactions contain
-- $0 service, bundle, pickup, or operational components whose quantities
-- can inflate recorded unit counts without representing additional priced
-- items purchased by the customer.



-- ============================================================
-- Analytical scope: confirmed institutional / bulk transactions
-- ============================================================
--
-- High-quantity transaction events were manually reviewed against private
-- source records to distinguish normal retail activity from confirmed
-- institutional / bulk purchases.
--
-- These are legitimate business transactions and remain included in:
--   - the portfolio datasets
--   - retailer-level sales totals
--   - source-performance analysis
--   - revenue analysis
--
-- They are excluded ONLY from standard retail basket-behaviour analysis
-- because their purchasing purpose and quantities are materially different
-- from ordinary retail transactions.
--
-- This is an analytical-scope exclusion, not data cleaning or arbitrary
-- outlier removal.
--
-- The transaction-level thresholds were established through manual review
-- of private source records:
--
--   2023: recorded_net_units >= 72
--   2024: recorded_net_units >= 50
--   2025: recorded_net_units >= 97
--
-- Bulk classification is performed using all recorded units because those
-- thresholds were validated against the original transaction records.
--
-- After confirmed bulk transactions are removed from the basket-analysis
-- population, priced_net_units are used to measure standard retail basket
-- quantity.
--
-- Private customer names, notes, and other identifying source information
-- used to validate these thresholds are not included in public analysis.



-- ============================================================
-- Step 1: Transaction-level composition by sales source
-- ============================================================
--
-- Aggregate Sale Line data to one row per transaction event.
--
-- transaction_id values restart within each annual portfolio table, so
-- sale_year is retained alongside transaction_id when combining years.
--
-- recorded_net_units:
--   Quantity across all retained Sale Lines.
--
-- priced_net_units:
--   Quantity only where the Sale Line subtotal is non-zero.
--
-- COUNT(DISTINCT Sku) measures distinct recorded SKUs within a transaction.
-- NULL SKU values, if present, are not counted as a distinct SKU.


WITH combined AS (

  SELECT
    2023 AS sale_year,
    sale_datetime,
    transaction_id,
    sales_source,
    quantity,
    subtotal,
    total,
    Sku

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2023`

  UNION ALL

  SELECT
    2024 AS sale_year,
    sale_datetime,
    transaction_id,
    sales_source,
    quantity,
    subtotal,
    total,
    Sku

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2024`

  UNION ALL

  SELECT
    2025 AS sale_year,
    sale_datetime,
    transaction_id,
    sales_source,
    quantity,
    subtotal,
    total,
    Sku

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2025`
),


comparable_period AS (

  SELECT *
  FROM combined

  WHERE DATE(sale_datetime)
    BETWEEN DATE(sale_year, 1, 1)
        AND DATE(sale_year, 10, 29)
),


transaction_level AS (

  SELECT
    sale_year,
    transaction_id,
    sales_source,

    COUNT(*) AS sale_line_rows,

    COUNT(DISTINCT Sku) AS distinct_skus,

    SUM(quantity) AS recorded_net_units,

    SUM(
      CASE
        WHEN subtotal != 0 THEN quantity
        ELSE 0
      END
    ) AS priced_net_units,

    SUM(total) AS net_sales

  FROM comparable_period

  GROUP BY
    sale_year,
    transaction_id,
    sales_source
),


analysis_scope AS (

  SELECT *
  FROM transaction_level

  WHERE NOT (
       (sale_year = 2023 AND recorded_net_units >= 72)
    OR (sale_year = 2024 AND recorded_net_units >= 50)
    OR (sale_year = 2025 AND recorded_net_units >= 97)
  )
)


SELECT
  sale_year,
  sales_source,

  COUNT(*) AS transaction_events,

  ROUND(AVG(sale_line_rows), 2)
    AS avg_sale_lines_per_transaction,

  APPROX_QUANTILES(
    sale_line_rows,
    100
  )[OFFSET(50)]
    AS median_sale_lines_per_transaction,

  ROUND(AVG(distinct_skus), 2)
    AS avg_distinct_skus_per_transaction,

  APPROX_QUANTILES(
    distinct_skus,
    100
  )[OFFSET(50)]
    AS median_distinct_skus_per_transaction,

  ROUND(AVG(priced_net_units), 2)
    AS avg_priced_net_units_per_transaction,

  APPROX_QUANTILES(
    priced_net_units,
    100
  )[OFFSET(50)]
    AS median_priced_net_units_per_transaction,

  ROUND(AVG(net_sales), 2)
    AS avg_net_sales_per_transaction,

  ROUND(
    APPROX_QUANTILES(
      net_sales,
      100
    )[OFFSET(50)],
    2
  ) AS median_net_sales_per_transaction

FROM analysis_scope

GROUP BY
  sale_year,
  sales_source

ORDER BY
  sale_year,
  sales_source;



-- ============================================================
-- Step 2: Transaction-size distribution
-- ============================================================
--
-- Compare the middle and upper ranges of transaction value and priced
-- basket quantity rather than relying only on averages.
--
-- The 25th, 50th, 75th, and 90th percentiles help show whether changes in
-- average transaction size reflect broad changes across transactions or are
-- concentrated among larger transactions.


WITH combined AS (

  SELECT
    2023 AS sale_year,
    sale_datetime,
    transaction_id,
    sales_source,
    quantity,
    subtotal,
    total

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2023`

  UNION ALL

  SELECT
    2024 AS sale_year,
    sale_datetime,
    transaction_id,
    sales_source,
    quantity,
    subtotal,
    total

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2024`

  UNION ALL

  SELECT
    2025 AS sale_year,
    sale_datetime,
    transaction_id,
    sales_source,
    quantity,
    subtotal,
    total

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2025`
),


comparable_period AS (

  SELECT *
  FROM combined

  WHERE DATE(sale_datetime)
    BETWEEN DATE(sale_year, 1, 1)
        AND DATE(sale_year, 10, 29)
),


transaction_level AS (

  SELECT
    sale_year,
    transaction_id,
    sales_source,

    SUM(quantity) AS recorded_net_units,

    SUM(
      CASE
        WHEN subtotal != 0 THEN quantity
        ELSE 0
      END
    ) AS priced_net_units,

    SUM(total) AS net_sales

  FROM comparable_period

  GROUP BY
    sale_year,
    transaction_id,
    sales_source
),


analysis_scope AS (

  SELECT *
  FROM transaction_level

  WHERE NOT (
       (sale_year = 2023 AND recorded_net_units >= 72)
    OR (sale_year = 2024 AND recorded_net_units >= 50)
    OR (sale_year = 2025 AND recorded_net_units >= 97)
  )
),


percentiles AS (

  SELECT
    sale_year,
    sales_source,

    APPROX_QUANTILES(net_sales, 100)
      AS sales_percentiles,

    APPROX_QUANTILES(priced_net_units, 100)
      AS unit_percentiles

  FROM analysis_scope

  GROUP BY
    sale_year,
    sales_source
)


SELECT
  sale_year,
  sales_source,

  ROUND(sales_percentiles[OFFSET(25)], 2)
    AS net_sales_p25,

  ROUND(sales_percentiles[OFFSET(50)], 2)
    AS net_sales_median,

  ROUND(sales_percentiles[OFFSET(75)], 2)
    AS net_sales_p75,

  ROUND(sales_percentiles[OFFSET(90)], 2)
    AS net_sales_p90,

  unit_percentiles[OFFSET(25)]
    AS priced_units_p25,

  unit_percentiles[OFFSET(50)]
    AS priced_units_median,

  unit_percentiles[OFFSET(75)]
    AS priced_units_p75,

  unit_percentiles[OFFSET(90)]
    AS priced_units_p90

FROM percentiles

ORDER BY
  sale_year,
  sales_source;



-- ============================================================
-- Step 3: Transaction distribution by priced unit volume
-- ============================================================
--
-- Group standard retail transaction events by priced unit volume to identify
-- whether changes in average basket quantity are concentrated among larger
-- transactions.
--
-- priced_net_units excludes quantities attached to $0 Sale Lines.
--
-- Negative and zero priced-net-unit transaction events are retained as
-- separate categories because legitimate returns and offsetting transaction
-- structures remain present in the portfolio data.


WITH combined AS (

  SELECT
    2023 AS sale_year,
    sale_datetime,
    transaction_id,
    sales_source,
    quantity,
    subtotal,
    total

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2023`

  UNION ALL

  SELECT
    2024 AS sale_year,
    sale_datetime,
    transaction_id,
    sales_source,
    quantity,
    subtotal,
    total

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2024`

  UNION ALL

  SELECT
    2025 AS sale_year,
    sale_datetime,
    transaction_id,
    sales_source,
    quantity,
    subtotal,
    total

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2025`
),


comparable_period AS (

  SELECT *
  FROM combined

  WHERE DATE(sale_datetime)
    BETWEEN DATE(sale_year, 1, 1)
        AND DATE(sale_year, 10, 29)
),


transaction_level AS (

  SELECT
    sale_year,
    transaction_id,
    sales_source,

    SUM(quantity) AS recorded_net_units,

    SUM(
      CASE
        WHEN subtotal != 0 THEN quantity
        ELSE 0
      END
    ) AS priced_net_units,

    SUM(total) AS net_sales

  FROM comparable_period

  GROUP BY
    sale_year,
    transaction_id,
    sales_source
),


analysis_scope AS (

  SELECT *
  FROM transaction_level

  WHERE NOT (
       (sale_year = 2023 AND recorded_net_units >= 72)
    OR (sale_year = 2024 AND recorded_net_units >= 50)
    OR (sale_year = 2025 AND recorded_net_units >= 97)
  )
),


bucketed AS (

  SELECT
    *,

    CASE
      WHEN priced_net_units < 0 THEN 'Net return (<0)'
      WHEN priced_net_units = 0 THEN 'Zero priced units'
      WHEN priced_net_units = 1 THEN '1 unit'
      WHEN priced_net_units = 2 THEN '2 units'
      WHEN priced_net_units BETWEEN 3 AND 4 THEN '3-4 units'
      WHEN priced_net_units >= 5 THEN '5+ units'
    END AS unit_bucket

  FROM analysis_scope
),


source_totals AS (

  SELECT
    sale_year,
    sales_source,

    COUNT(*) AS source_transaction_events

  FROM bucketed

  GROUP BY
    sale_year,
    sales_source
)


SELECT
  b.sale_year,
  b.sales_source,
  b.unit_bucket,

  COUNT(*) AS transaction_events,

  ROUND(
    SAFE_DIVIDE(
      COUNT(*),
      s.source_transaction_events
    ) * 100,
    2
  ) AS pct_of_source_transactions,

  ROUND(SUM(b.net_sales), 2)
    AS net_sales,

  ROUND(AVG(b.net_sales), 2)
    AS avg_net_sales_per_transaction

FROM bucketed AS b

JOIN source_totals AS s
  USING (
    sale_year,
    sales_source
  )

GROUP BY
  b.sale_year,
  b.sales_source,
  b.unit_bucket,
  s.source_transaction_events

ORDER BY
  b.sale_year,
  b.sales_source,

  CASE b.unit_bucket
    WHEN 'Net return (<0)' THEN 1
    WHEN 'Zero priced units' THEN 2
    WHEN '1 unit' THEN 3
    WHEN '2 units' THEN 4
    WHEN '3-4 units' THEN 5
    WHEN '5+ units' THEN 6
  END;



-- ============================================================
-- Step 4: Upper-tail standard retail basket size
-- ============================================================
--
-- Examine the upper portion of standard retail basket quantity in greater
-- detail.
--
-- Compare the 90th, 95th, and 99th percentiles and maximum priced-net-unit
-- values for each source and year.
--
-- Confirmed institutional / bulk transactions are excluded before these
-- calculations.
--
-- $0-line quantities are also excluded from priced_net_units so the upper
-- tail reflects priced basket quantity rather than operational/component
-- quantities recorded within service or bundled transactions.


WITH combined AS (

  SELECT
    2023 AS sale_year,
    sale_datetime,
    transaction_id,
    sales_source,
    quantity,
    subtotal,
    total

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2023`

  UNION ALL

  SELECT
    2024 AS sale_year,
    sale_datetime,
    transaction_id,
    sales_source,
    quantity,
    subtotal,
    total

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2024`

  UNION ALL

  SELECT
    2025 AS sale_year,
    sale_datetime,
    transaction_id,
    sales_source,
    quantity,
    subtotal,
    total

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2025`
),


comparable_period AS (

  SELECT *
  FROM combined

  WHERE DATE(sale_datetime)
    BETWEEN DATE(sale_year, 1, 1)
        AND DATE(sale_year, 10, 29)
),


transaction_level AS (

  SELECT
    sale_year,
    transaction_id,
    sales_source,

    SUM(quantity) AS recorded_net_units,

    SUM(
      CASE
        WHEN subtotal != 0 THEN quantity
        ELSE 0
      END
    ) AS priced_net_units,

    SUM(total) AS net_sales

  FROM comparable_period

  GROUP BY
    sale_year,
    transaction_id,
    sales_source
),


analysis_scope AS (

  SELECT *
  FROM transaction_level

  WHERE NOT (
       (sale_year = 2023 AND recorded_net_units >= 72)
    OR (sale_year = 2024 AND recorded_net_units >= 50)
    OR (sale_year = 2025 AND recorded_net_units >= 97)
  )
),


percentiles AS (

  SELECT
    sale_year,
    sales_source,

    APPROX_QUANTILES(priced_net_units, 100)
      AS unit_percentiles,

    APPROX_QUANTILES(net_sales, 100)
      AS sales_percentiles,

    MAX(priced_net_units)
      AS max_priced_net_units,

    MAX(net_sales)
      AS max_net_sales

  FROM analysis_scope

  GROUP BY
    sale_year,
    sales_source
)


SELECT
  sale_year,
  sales_source,

  unit_percentiles[OFFSET(90)]
    AS priced_units_p90,

  unit_percentiles[OFFSET(95)]
    AS priced_units_p95,

  unit_percentiles[OFFSET(99)]
    AS priced_units_p99,

  max_priced_net_units,

  ROUND(sales_percentiles[OFFSET(90)], 2)
    AS net_sales_p90,

  ROUND(sales_percentiles[OFFSET(95)], 2)
    AS net_sales_p95,

  ROUND(sales_percentiles[OFFSET(99)], 2)
    AS net_sales_p99,

  ROUND(max_net_sales, 2)
    AS max_net_sales

FROM percentiles

ORDER BY
  sale_year,
  sales_source;



-- ============================================================
-- Findings
-- ============================================================
--
-- Analytical scope:
-- Confirmed institutional / bulk transactions remain included in the portfolio
-- datasets and overall business-performance analysis but are excluded from this
-- standard retail basket analysis.
--
-- This analytical-scope exclusion means transaction counts and averages in
-- this section are not expected to reconcile exactly to the all-activity
-- source-performance results in ANALYSIS 02.
--
-- Basket quantity is measured using priced_net_units rather than all recorded
-- quantities because legitimate $0 operational/component Sale Lines can carry
-- quantity without representing additional priced merchandise.
--
-- Sale Line count and distinct SKU count are retained separately as measures
-- of recorded transaction structure.
--
-- Typical physical-store transactions remained small across all three years.
--
-- For Store A-D, the median transaction consistently contained:
--
--   1 Sale Line
--   1 distinct SKU
--   1 priced net unit
--
-- Median transaction value also remained comparatively stable for most
-- physical stores, generally between approximately $56 and $75.
--
-- This indicates that changes in annual averages were generally concentrated
-- in subsets of transactions rather than reflecting a broad shift in the
-- typical physical-store transaction.
--
-- Online / Event displayed a different transaction profile from the physical
-- stores, although the combined source should not be interpreted as
-- ecommerce-only activity.
--
-- Average Online / Event transaction value increased from:
--
--   2023: $265.85
--   2024: $332.16
--   2025: $356.38
--
-- Median transaction value increased from $164.72 in 2023 to $225.99 in 2024
-- and remained elevated at $217.26 in 2025.
--
-- Priced basket quantity did not increase proportionally with transaction
-- value. Average priced units were:
--
--   2023: 1.82
--   2024: 1.95
--   2025: 1.81
--
-- The median also declined from 2 priced units in 2023 and 2024 to 1 in 2025.
--
-- Online / Event therefore shifted toward higher-value transactions without a
-- corresponding broad increase in priced basket quantity.
--
-- The transaction-value distribution reinforces this distinction.
--
-- Online / Event net-sales percentiles increased from 2023 to 2025:
--
--   p75: $386.43 -> $451.99
--   p90: $709.95 -> $819.22
--
-- At the same time, the 90th percentile of priced basket quantity remained
-- 4 units in every year, while the 95th percentile remained 5 units.
--
-- Higher Online / Event transaction values therefore appear to reflect
-- higher-value transaction composition rather than simply more priced units.
--
-- Store A showed a notable change in recorded transaction structure in 2025.
--
-- Average Sale Lines per transaction increased from:
--
--   2024: 1.90
--   2025: 2.28
--
-- Average distinct SKUs increased from:
--
--   2024: 1.65
--   2025: 1.98
--
-- However, average priced units declined slightly from 1.87 to 1.84, while
-- the priced-unit distribution remained modest:
--
--   2024 p90 / p95 / p99: 4 / 5 / 10
--   2025 p90 / p95 / p99: 4 / 5 / 9
--
-- Store A therefore became more complex in its recorded transaction structure
-- without becoming materially larger in priced basket quantity.
--
-- Store B showed comparatively stable basket composition.
--
-- Average priced units remained tightly grouped:
--
--   2023: 1.85
--   2024: 1.85
--   2025: 1.86
--
-- Median priced units remained 1, the 90th percentile remained 4 units, and
-- the share of 5+ unit transactions remained close to 6% across the period.
--
-- Average transaction value declined from $185.46 in 2023 to $174.09 in 2024
-- before recovering to $182.48 in 2025.
--
-- Store B therefore showed relatively stable basket structure despite the
-- changes in transaction volume identified in source-performance analysis.
--
-- Store C showed the clearest movement toward larger priced baskets among the
-- physical stores.
--
-- Average priced units increased from 1.94 in 2024 to 2.02 in 2025.
--
-- The share of transactions containing 5+ priced units increased from 8.25%
-- to 9.10%, while the upper distribution increased from:
--
--   2024 p95 / p99: 6 / 12
--   2025 p95 / p99: 7 / 14
--
-- Store D also showed a shift toward somewhat larger priced baskets among its
-- remaining transactions.
--
-- Average priced units increased from 1.84 in 2024 to 2.07 in 2025.
--
-- The share of 5+ priced-unit transactions increased from 7.10% to 8.78%,
-- while the upper distribution increased from:
--
--   2024 p95 / p99: 6 / 10
--   2025 p95 / p99: 7 / 13
--
-- These basket changes do not offset the substantially lower transaction
-- volume identified for Store D in ANALYSIS 02. They describe the composition
-- of the remaining standard retail transaction population.
--
-- Across all sources, the 90th percentile of priced basket quantity remained
-- 4 units in every year.
--
-- Larger baskets generally produced higher average transaction values, but
-- 5+ priced-unit transactions remained a minority of transaction events.
--
-- This demonstrates why averages alone are insufficient for interpreting
-- basket behaviour: changes may occur in particular sources or in the upper
-- portion of the distribution while the typical transaction remains stable.
--
-- Net-return and zero-priced-unit transactions are retained as separate
-- distribution categories so legitimate transaction structures are not
-- silently removed. Detailed return-pattern interpretation is reserved for
-- ANALYSIS 05.
--
-- Overall, the three-year change in transaction behaviour was not a uniform
-- movement toward larger baskets.
--
-- Typical physical-store transactions remained small and stable. Online /
-- Event generated progressively higher-value transactions without a broad
-- increase in priced-unit quantity. Store A became more complex in recorded
-- Sale Lines and distinct SKUs, Store B remained comparatively stable, and
-- Stores C and D showed more movement in the upper end of priced basket size.
--
-- Analysis decision:
-- Treat basket quantity, recorded transaction complexity, and transaction
-- value as separate measures rather than relying on a single average basket
-- metric to explain changes in transaction behaviour.