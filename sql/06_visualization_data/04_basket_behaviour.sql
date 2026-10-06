-- VISUALIZATION DATA 04
-- Standard Retail Basket Behaviour by Source

-- Purpose:
-- Create an aggregated transaction-distribution dataset for visualizing
-- how standard retail basket behaviour differs across sales sources and years.
--
-- Use the comparable January 1 - October 29 period for all three years so
-- the visualization aligns with the analytical scope used elsewhere in the
-- portfolio.
--
-- Confirmed institutional / bulk transactions are excluded from this
-- basket-behaviour view only, consistent with ANALYSIS 03.
--
-- They remain included in portfolio tables and overall sales analyses.
--
-- priced_net_units counts quantity only from Sale Lines with non-zero
-- subtotal so bundled / zero-priced component lines do not artificially
-- inflate retail basket quantity.
--
-- Transaction-level monetary values remain at full precision until the
-- final displayed aggregates are rounded.


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
    sales_source,
    transaction_id,

    COUNT(*)
      AS sale_lines,

    COUNT(DISTINCT Sku)
      AS distinct_skus,

    SUM(quantity)
      AS recorded_net_units,

    SUM(
      CASE
        WHEN subtotal != 0 THEN quantity
        ELSE 0
      END
    ) AS priced_net_units,

    SUM(total)
      AS net_sales

  FROM comparable_period

  GROUP BY
    sale_year,
    sales_source,
    transaction_id
),


standard_retail AS (

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

  COUNT(*)
    AS transaction_events,

  ROUND(AVG(sale_lines), 2)
    AS avg_sale_lines,

  ROUND(AVG(distinct_skus), 2)
    AS avg_distinct_skus,

  ROUND(AVG(priced_net_units), 2)
    AS avg_priced_units,

  APPROX_QUANTILES(
    priced_net_units,
    100
  )[OFFSET(50)]
    AS median_priced_units,

  APPROX_QUANTILES(
    priced_net_units,
    100
  )[OFFSET(75)]
    AS p75_priced_units,

  APPROX_QUANTILES(
    priced_net_units,
    100
  )[OFFSET(90)]
    AS p90_priced_units,

  ROUND(AVG(net_sales), 2)
    AS avg_net_sales_per_transaction,

  ROUND(
    APPROX_QUANTILES(
      net_sales,
      100
    )[OFFSET(50)],
    2
  ) AS median_net_sales_per_transaction,

  ROUND(
    APPROX_QUANTILES(
      net_sales,
      100
    )[OFFSET(75)],
    2
  ) AS p75_net_sales_per_transaction,

  ROUND(
    APPROX_QUANTILES(
      net_sales,
      100
    )[OFFSET(90)],
    2
  ) AS p90_net_sales_per_transaction

FROM standard_retail

GROUP BY
  sale_year,
  sales_source

ORDER BY
  sales_source,
  sale_year;