-- ANALYSIS 01
-- Three-Year Overview


-- Purpose:
-- Establish a high-level baseline across the finalized 2023, 2024, and 2025
-- portfolio datasets before beginning more detailed performance analysis.
--
-- Review dataset coverage first, then compare equivalent January 1 through
-- October 29 periods so the partial 2025 dataset is not compared directly
-- against complete calendar years.
--
-- The analysis focuses on transaction volume, unit movement, net sales, and
-- average transaction value.


-- ============================================================
-- Step 1: Review full available-period coverage
-- ============================================================
--
-- Confirm the scale, date coverage, transaction volume, units, and monetary
-- totals contained in each finalized portfolio table.
--
-- Because 2025 ends on October 29, these results are used primarily to
-- understand dataset coverage rather than for direct year-over-year
-- performance comparison.


WITH combined AS (

  SELECT
    2023 AS sale_year,
    sale_datetime,
    transaction_id,
    quantity,
    subtotal,
    sales_tax,
    discount,
    loyalty,
    total

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2023`

  UNION ALL

  SELECT
    2024 AS sale_year,
    sale_datetime,
    transaction_id,
    quantity,
    subtotal,
    sales_tax,
    discount,
    loyalty,
    total

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2024`

  UNION ALL

  SELECT
    2025 AS sale_year,
    sale_datetime,
    transaction_id,
    quantity,
    subtotal,
    sales_tax,
    discount,
    loyalty,
    total

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2025`
)


SELECT
  sale_year,

  COUNT(*) AS sale_line_rows,

  COUNT(DISTINCT transaction_id) AS transaction_events,

  MIN(sale_datetime) AS earliest_date,

  MAX(sale_datetime) AS latest_date,

  SUM(quantity) AS net_units,

  SUM(
    CASE
      WHEN subtotal != 0 THEN quantity
      ELSE 0
    END
  ) AS priced_net_units,

  ROUND(SUM(subtotal), 2) AS net_subtotal,

  ROUND(SUM(sales_tax), 2) AS net_sales_tax,

  ROUND(SUM(discount), 2) AS net_discount,

  ROUND(SUM(loyalty), 2) AS net_loyalty,

  ROUND(SUM(total), 2) AS net_sales,

  ROUND(
    SAFE_DIVIDE(
      SUM(total),
      COUNT(DISTINCT transaction_id)
    ),
    2
  ) AS avg_net_sales_per_transaction


FROM combined


GROUP BY sale_year


ORDER BY sale_year;



-- ============================================================
-- Step 2: Compare equivalent January 1 - October 29 periods
-- ============================================================
--
-- Restrict all three years to the same calendar window so the partial 2025
-- dataset can be compared fairly against the equivalent periods in 2023
-- and 2024.
--
-- Priced net units are used as the primary portfolio unit metric because
-- legitimate zero-value operational lines can carry quantity without
-- representing separately priced merchandise.


WITH combined AS (

  SELECT
    2023 AS sale_year,
    sale_datetime,
    transaction_id,
    quantity,
    subtotal,
    sales_tax,
    discount,
    loyalty,
    total

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2023`

  UNION ALL

  SELECT
    2024 AS sale_year,
    sale_datetime,
    transaction_id,
    quantity,
    subtotal,
    sales_tax,
    discount,
    loyalty,
    total

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2024`

  UNION ALL

  SELECT
    2025 AS sale_year,
    sale_datetime,
    transaction_id,
    quantity,
    subtotal,
    sales_tax,
    discount,
    loyalty,
    total

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2025`
)


SELECT
  sale_year,

  COUNT(*) AS sale_line_rows,

  COUNT(DISTINCT transaction_id) AS transaction_events,

  MIN(sale_datetime) AS earliest_date,

  MAX(sale_datetime) AS latest_date,

  SUM(quantity) AS net_units,

  SUM(
    CASE
      WHEN subtotal != 0 THEN quantity
      ELSE 0
    END
  ) AS priced_net_units,

  ROUND(SUM(subtotal), 2) AS net_subtotal,

  ROUND(SUM(sales_tax), 2) AS net_sales_tax,

  ROUND(SUM(discount), 2) AS net_discount,

  ROUND(SUM(loyalty), 2) AS net_loyalty,

  ROUND(SUM(total), 2) AS net_sales,

  ROUND(
    SAFE_DIVIDE(
      SUM(total),
      COUNT(DISTINCT transaction_id)
    ),
    2
  ) AS avg_net_sales_per_transaction


FROM combined


WHERE DATE(sale_datetime)
  BETWEEN DATE(sale_year, 1, 1)
      AND DATE(sale_year, 10, 29)


GROUP BY sale_year


ORDER BY sale_year;



-- ============================================================
-- Findings
-- ============================================================
--
-- The finalized portfolio datasets contain:
--
--   2023
--     88,627 Sale Line rows
--     44,512 transaction events
--     $8,944,625.71 net sales
--
--   2024
--     74,872 Sale Line rows
--     38,203 transaction events
--     $7,684,400.31 net sales
--
--   2025
--     57,492 Sale Line rows
--     27,233 transaction events
--     $5,088,845.54 net sales through October 29
--
-- The available 2025 dataset ends on October 29 and therefore represents a
-- partial year rather than a complete calendar year.
--
-- Because November and December represent meaningful seasonal selling months,
-- January 1 through October 29 is used as the common comparison period.
--
-- Comparable-period results:
--
--   2023
--     34,137 transaction events
--     66,999 priced net units
--     $6,253,286.44 net sales
--     $183.18 average net sales per transaction
--
--   2024
--     28,887 transaction events
--     54,646 priced net units
--     $5,120,006.96 net sales
--     $177.24 average net sales per transaction
--
--   2025
--     27,233 transaction events
--     53,896 priced net units
--     $5,088,845.54 net sales
--     $186.86 average net sales per transaction
--
-- The largest performance decline occurred between 2023 and 2024:
--
--   transaction events       -15.4%
--   priced net units         -18.4%
--   net sales                -18.1%
--   avg sales / transaction   -3.2%
--
-- Performance was considerably more stable between 2024 and 2025:
--
--   transaction events        -5.7%
--   priced net units          -1.4%
--   net sales                 -0.6%
--   avg sales / transaction   +5.4%
--
-- The 2025 pattern therefore cannot be explained by transaction count alone.
-- Fewer transaction events generated nearly the same net sales as 2024 while
-- average transaction value increased.
--
-- Total net units and priced net units also produce different interpretations:
--
--   2024 total net units:   55,861
--   2025 total net units:   61,097
--
--   2024 priced net units:  54,646
--   2025 priced net units:  53,896
--
-- Legitimate zero-value operational lines can carry quantity without
-- representing separately priced merchandise, so priced net units are used
-- as the headline portfolio unit-volume metric.
--
-- Recorded discount value across the comparable periods was:
--
--   2023: $550,682.78
--   2024: $749,917.03
--   2025: $765,125.27
--
-- Discount values are retained for targeted analysis but are not treated as a
-- standalone measure of pricing strategy because clearance activity,
-- event-based selling, and transaction-recording differences may influence
-- the field across years.
--
-- Loyalty value across the comparable periods was:
--
--   2023: $38,676.05
--   2024: $34,153.66
--   2025: $31,304.44
--
-- Loyalty is retained as operational metadata because its use may have
-- changed over time and therefore should not be interpreted directly as a
-- measure of customer engagement or retention.
--
-- The strongest initial pattern is that the major decline occurred between
-- 2023 and 2024, while 2025 showed relative stabilization.
--
-- Transaction volume continued to decline in 2025, but priced-unit volume and
-- net sales remained close to 2024 levels while average transaction value
-- increased.
--
-- Analysis decision:
-- Use the January 1 through October 29 comparable-period metrics as the
-- baseline for subsequent sales-source, transaction-composition, seasonal,
-- discount, and return analysis.