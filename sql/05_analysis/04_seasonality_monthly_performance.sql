-- ANALYSIS 04
-- Seasonality & Monthly Performance


-- Purpose:
-- Examine when performance changed across the year by comparing monthly
-- transaction activity, net sales, and supporting transaction metrics.
--
-- This analysis uses two complementary time scopes:
--
--   1. Comparable three-year period:
--      January 1 - October 29 for 2023, 2024, and 2025
--
--   2. Full-year seasonality:
--      January - December for 2023 and 2024 only
--
-- The comparable period allows clean year-over-year comparison including
-- partial-year 2025 data.
--
-- The full-year view preserves November and December, which are important
-- seasonal months for the business, without treating incomplete 2025 data
-- as though it represents a full year.
--
-- Primary measures:
--   - transaction events
--   - net sales
--
-- Supporting measures:
--   - average net sales per transaction
--   - priced net units
--
-- priced_net_units counts quantity only from Sale Lines with non-zero
-- subtotal. This is retained as a supporting measure, while net sales and
-- transaction volume remain the primary indicators of seasonal performance.
--
-- All legitimate transaction events remain included in this analysis,
-- including confirmed institutional / bulk transactions, because this section
-- measures overall business activity rather than standard retail basket
-- behaviour.



-- ============================================================
-- Step 1A: Comparable monthly performance
-- January 1 - October 29, 2023-2025
-- ============================================================
--
-- Compare equivalent calendar periods across all three years.
--
-- This establishes whether year-over-year differences were broad-based
-- across the year or concentrated in particular months.


WITH combined AS (

  SELECT
    2023 AS sale_year,
    sale_datetime,
    transaction_id,
    quantity,
    subtotal,
    total

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2023`

  UNION ALL

  SELECT
    2024 AS sale_year,
    sale_datetime,
    transaction_id,
    quantity,
    subtotal,
    total

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2024`

  UNION ALL

  SELECT
    2025 AS sale_year,
    sale_datetime,
    transaction_id,
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
)


SELECT
  sale_year,

  EXTRACT(MONTH FROM sale_datetime)
    AS sale_month,

  FORMAT_DATE(
    '%B',
    DATE(sale_year, EXTRACT(MONTH FROM sale_datetime), 1)
  ) AS month_name,

  COUNT(DISTINCT transaction_id)
    AS transaction_events,

  SUM(
    CASE
      WHEN subtotal != 0 THEN quantity
      ELSE 0
    END
  ) AS priced_net_units,

  ROUND(SUM(total), 2)
    AS net_sales,

  ROUND(
    SAFE_DIVIDE(
      SUM(total),
      COUNT(DISTINCT transaction_id)
    ),
    2
  ) AS avg_net_sales_per_transaction

FROM comparable_period

GROUP BY
  sale_year,
  sale_month,
  month_name

ORDER BY
  sale_year,
  sale_month;



-- ============================================================
-- Step 1B: Full-year seasonality
-- January - December, 2023-2024
-- ============================================================
--
-- Examine the complete annual sales cycle using the two years with full
-- January-December data.
--
-- 2025 is intentionally excluded because its source data ends October 29.
--
-- This preserves November and December in the seasonal analysis without
-- creating an incomplete full-year comparison.


WITH combined AS (

  SELECT
    2023 AS sale_year,
    sale_datetime,
    transaction_id,
    quantity,
    subtotal,
    total

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2023`

  UNION ALL

  SELECT
    2024 AS sale_year,
    sale_datetime,
    transaction_id,
    quantity,
    subtotal,
    total

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2024`
)


SELECT
  sale_year,

  EXTRACT(MONTH FROM sale_datetime)
    AS sale_month,

  FORMAT_DATE(
    '%B',
    DATE(sale_year, EXTRACT(MONTH FROM sale_datetime), 1)
  ) AS month_name,

  COUNT(DISTINCT transaction_id)
    AS transaction_events,

  SUM(
    CASE
      WHEN subtotal != 0 THEN quantity
      ELSE 0
    END
  ) AS priced_net_units,

  ROUND(SUM(total), 2)
    AS net_sales,

  ROUND(
    SAFE_DIVIDE(
      SUM(total),
      COUNT(DISTINCT transaction_id)
    ),
    2
  ) AS avg_net_sales_per_transaction

FROM combined

GROUP BY
  sale_year,
  sale_month,
  month_name

ORDER BY
  sale_year,
  sale_month;



-- ============================================================
-- Step 2: Monthly performance by sales source
-- Comparable period: January 1 - October 29, 2023-2025
-- ============================================================
--
-- Break the retailer-level monthly pattern down by sales source to identify
-- whether seasonal changes were shared across the business or concentrated
-- in particular stores / Online / Event.
--
-- Online / Event is a combined source category and should not be interpreted
-- as ecommerce-only activity.


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
)


SELECT
  sale_year,

  EXTRACT(MONTH FROM sale_datetime)
    AS sale_month,

  FORMAT_DATE(
    '%B',
    DATE(sale_year, EXTRACT(MONTH FROM sale_datetime), 1)
  ) AS month_name,

  sales_source,

  COUNT(DISTINCT transaction_id)
    AS transaction_events,

  SUM(
    CASE
      WHEN subtotal != 0 THEN quantity
      ELSE 0
    END
  ) AS priced_net_units,

  ROUND(SUM(total), 2)
    AS net_sales,

  ROUND(
    SAFE_DIVIDE(
      SUM(total),
      COUNT(DISTINCT transaction_id)
    ),
    2
  ) AS avg_net_sales_per_transaction

FROM comparable_period

GROUP BY
  sale_year,
  sale_month,
  month_name,
  sales_source

ORDER BY
  sale_year,
  sale_month,
  sales_source;



-- ============================================================
-- Step 3: Year-over-year monthly change
-- Comparable period: January 1 - October 29, 2023-2025
-- ============================================================
--
-- Measure how each month's performance changed relative to the same month
-- in the previous year.
--
-- LAG() is partitioned by calendar month so January is compared with January,
-- February with February, etc.
--
-- Monthly net sales are retained at full precision through the year-over-year
-- calculation. Rounding is applied only in the final output.
--
-- This helps distinguish months that contributed most strongly to annual
-- growth or decline.


WITH combined AS (

  SELECT
    2023 AS sale_year,
    sale_datetime,
    transaction_id,
    total

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2023`

  UNION ALL

  SELECT
    2024 AS sale_year,
    sale_datetime,
    transaction_id,
    total

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2024`

  UNION ALL

  SELECT
    2025 AS sale_year,
    sale_datetime,
    transaction_id,
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


monthly AS (

  SELECT
    sale_year,

    EXTRACT(MONTH FROM sale_datetime)
      AS sale_month,

    FORMAT_DATE(
      '%B',
      DATE(sale_year, EXTRACT(MONTH FROM sale_datetime), 1)
    ) AS month_name,

    COUNT(DISTINCT transaction_id)
      AS transaction_events,

    SUM(total)
      AS net_sales

  FROM comparable_period

  GROUP BY
    sale_year,
    sale_month,
    month_name
),


with_previous_year AS (

  SELECT
    *,

    LAG(transaction_events)
      OVER (
        PARTITION BY sale_month
        ORDER BY sale_year
      ) AS previous_year_transaction_events,

    LAG(net_sales)
      OVER (
        PARTITION BY sale_month
        ORDER BY sale_year
      ) AS previous_year_net_sales

  FROM monthly
)


SELECT
  sale_year,
  sale_month,
  month_name,

  transaction_events,

  previous_year_transaction_events,

  ROUND(
    SAFE_DIVIDE(
      transaction_events - previous_year_transaction_events,
      previous_year_transaction_events
    ) * 100,
    2
  ) AS transaction_events_yoy_pct,

  ROUND(net_sales, 2)
    AS net_sales,

  ROUND(previous_year_net_sales, 2)
    AS previous_year_net_sales,

  ROUND(
    SAFE_DIVIDE(
      net_sales - previous_year_net_sales,
      previous_year_net_sales
    ) * 100,
    2
  ) AS net_sales_yoy_pct

FROM with_previous_year

ORDER BY
  sale_year,
  sale_month;



-- ============================================================
-- Step 4: Full-year monthly performance by sales source
-- 2023-2024
-- ============================================================
--
-- Preserve the complete seasonal cycle, including November and December,
-- while examining whether different sales sources follow different seasonal
-- patterns.
--
-- 2025 is excluded because it is not a complete calendar year.


WITH combined AS (

  SELECT
    2023 AS sale_year,
    sale_datetime,
    transaction_id,
    sales_source,
    total

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2023`

  UNION ALL

  SELECT
    2024 AS sale_year,
    sale_datetime,
    transaction_id,
    sales_source,
    total

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2024`
)


SELECT
  sale_year,

  EXTRACT(MONTH FROM sale_datetime)
    AS sale_month,

  FORMAT_DATE(
    '%B',
    DATE(sale_year, EXTRACT(MONTH FROM sale_datetime), 1)
  ) AS month_name,

  sales_source,

  COUNT(DISTINCT transaction_id)
    AS transaction_events,

  ROUND(SUM(total), 2)
    AS net_sales,

  ROUND(
    SAFE_DIVIDE(
      SUM(total),
      COUNT(DISTINCT transaction_id)
    ),
    2
  ) AS avg_net_sales_per_transaction

FROM combined

GROUP BY
  sale_year,
  sale_month,
  month_name,
  sales_source

ORDER BY
  sale_year,
  sale_month,
  sales_source;



-- ============================================================
-- Step 5: October Online / Event concentration
-- Comparable period: October 1 - October 29, 2023-2025
-- ============================================================
--
-- Measure how concentrated Online / Event activity is within the two
-- highest-volume dates during the same October 1 - October 29 period
-- in each year.
--
-- Private operational context indicates that these dates align with the
-- annual event period. However, the Online / Event category also includes
-- ordinary online transactions, and online activity remains present within
-- the combined source.
--
-- The results therefore measure concentration within Online / Event rather
-- than attributing all activity exclusively to the annual event period.
--
-- Daily net sales are retained at full precision through the concentration
-- calculations. Rounding is applied only in the final output.


WITH combined AS (

  SELECT
    2023 AS sale_year,
    sale_datetime,
    transaction_id,
    sales_source,
    total

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2023`

  UNION ALL

  SELECT
    2024 AS sale_year,
    sale_datetime,
    transaction_id,
    sales_source,
    total

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2024`

  UNION ALL

  SELECT
    2025 AS sale_year,
    sale_datetime,
    transaction_id,
    sales_source,
    total

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2025`
),


october_daily AS (

  SELECT
    sale_year,

    DATE(sale_datetime)
      AS sale_date,

    COUNT(DISTINCT transaction_id)
      AS transaction_events,

    SUM(total)
      AS net_sales

  FROM combined

  WHERE sales_source = 'Online / Event'

    AND DATE(sale_datetime)
      BETWEEN DATE(sale_year, 10, 1)
          AND DATE(sale_year, 10, 29)

  GROUP BY
    sale_year,
    sale_date
),


ranked_days AS (

  SELECT
    *,

    ROW_NUMBER() OVER (
      PARTITION BY sale_year
      ORDER BY
        transaction_events DESC,
        net_sales DESC,
        sale_date ASC
    ) AS activity_rank

  FROM october_daily
),


year_totals AS (

  SELECT
    sale_year,

    SUM(transaction_events)
      AS october_transaction_events,

    SUM(net_sales)
      AS october_net_sales

  FROM october_daily

  GROUP BY sale_year
),


top_two_days AS (

  SELECT
    sale_year,

    SUM(transaction_events)
      AS top_two_day_transaction_events,

    SUM(net_sales)
      AS top_two_day_net_sales

  FROM ranked_days

  WHERE activity_rank <= 2

  GROUP BY sale_year
)


SELECT
  y.sale_year,

  y.october_transaction_events,

  t.top_two_day_transaction_events,

  ROUND(
    SAFE_DIVIDE(
      t.top_two_day_transaction_events,
      y.october_transaction_events
    ) * 100,
    2
  ) AS pct_transactions_top_two_days,

  ROUND(y.october_net_sales, 2)
    AS october_net_sales,

  ROUND(t.top_two_day_net_sales, 2)
    AS top_two_day_net_sales,

  ROUND(
    SAFE_DIVIDE(
      t.top_two_day_net_sales,
      y.october_net_sales
    ) * 100,
    2
  ) AS pct_sales_top_two_days

FROM year_totals AS y

JOIN top_two_days AS t
  USING (sale_year)

ORDER BY
  y.sale_year;



-- ============================================================
-- Findings
-- ============================================================
--
-- Analytical scope:
-- Seasonality is examined using two complementary time periods.
--
-- January 1 through October 29 is used for direct three-year comparisons
-- because the available 2025 dataset ends October 29.
--
-- Full-year 2023 and 2024 data are examined separately so November and
-- December remain visible when describing the retailer's complete seasonal
-- cycle.
--
-- All legitimate business activity remains included because this analysis
-- measures overall performance rather than standard retail basket behaviour.
--
--
-- 1. The business shows a strong seasonal sales cycle.
--
-- Full-year 2023 and 2024 results show high winter activity, lower performance
-- through much of spring and summer, and substantial acceleration during the
-- final months of the year.
--
-- December was the highest-sales month in both complete years:
--
--   2023: $1,502,299.10
--   2024: $1,612,013.11
--
-- January was also a major sales month:
--
--   2023: $1,343,056.82
--   2024: $1,113,938.45
--
-- Preserving November and December separately from the three-year comparable
-- period is therefore important for representing the full seasonal cycle.
--
--
-- 2. The 2024 January-October decline was broad-based rather than being driven
-- by one unusually weak month.
--
-- Every comparable month in 2024 recorded both fewer transaction events and
-- lower net sales than the same month in 2023.
--
-- Some of the largest year-over-year net-sales declines occurred in:
--
--   June:  -38.74%
--   May:   -29.71%
--   March: -21.03%
--
-- June transaction events also declined 25.00%.
--
-- The weaker 2024 comparable-period performance therefore reflected a broad
-- reduction across the year rather than a single isolated month.
--
--
-- 3. The 2025 pattern was substantially more mixed.
--
-- Several months produced similar or higher net sales despite lower
-- transaction volume.
--
-- Examples include:
--
--   May:
--     transaction events -12.02%
--     net sales           +9.35%
--
--   June:
--     transaction events  -1.39%
--     net sales           +1.64%
--
--   July:
--     transaction events -11.01%
--     net sales           -0.27%
--
--   September:
--     transaction events  -3.65%
--     net sales           +2.76%
--
-- October strengthened on both measures:
--
--     transaction events  +2.07%
--     net sales           +11.59%
--
-- March showed the strongest positive year-over-year sales movement:
--
--     transaction events  +7.51%
--     net sales           +40.95%
--
-- Other periods remained materially weaker, including February, April, and
-- August.
--
-- The 2025 performance pattern was therefore not a uniform recovery. Higher
-- transaction values in some periods offset lower transaction counts, while
-- other months continued to decline.
--
--
-- 4. The broad 2024 decline did not continue uniformly through year-end.
--
-- November 2024 remained below November 2023, but December transaction volume
-- returned to almost exactly the prior-year level:
--
--   December 2023: 6,432 transaction events
--   December 2024: 6,428 transaction events
--
-- December net sales increased from:
--
--   $1,502,299.10 in 2023
--   to
--   $1,612,013.11 in 2024
--
-- Average net sales per transaction also increased from $233.57 to $250.78.
--
-- December therefore represented a substantial year-end improvement despite
-- the weaker January-October performance seen across 2024.
--
--
-- 5. December improvement was not distributed uniformly across sales sources.
--
-- From December 2023 to December 2024, net sales changed from:
--
--   Store A:
--     $590,737.62 -> $662,598.33
--
--   Store B:
--     $540,255.65 -> $554,122.28
--
--   Store C:
--     $131,151.74 -> $196,943.71
--
-- while:
--
--   Store D:
--     $100,901.01 -> $68,022.67
--
--   Online / Event:
--     $139,253.08 -> $130,326.12
--
-- The retailer-wide December improvement therefore reflected different
-- source-level patterns rather than uniform growth across the business.
--
--
-- 6. Spring and summer represent a materially weaker portion of the annual
-- sales cycle.
--
-- Retailer-level monthly sales fell substantially after the winter period in
-- both complete years and remained comparatively low through much of spring
-- and summer before accelerating again later in the year.
--
-- April was one of the weaker periods, particularly in 2024 and 2025.
--
-- The transaction data supports the presence of a seasonal slowdown during
-- this part of the year, but it does not independently establish the
-- operational or product-level causes of that pattern.
--
--
-- 7. Online / Event follows a distinctive seasonal pattern and should not be
-- interpreted as ecommerce-only activity.
--
-- The combined source includes ordinary online transactions as well as
-- event-related activity.
--
-- Some periods contain relatively few transaction events but unusually high
-- average transaction values. For example, September 2024 recorded only
-- 59 Online / Event transaction events but averaged $889.96 in net sales per
-- transaction.
--
-- October then shows a substantial increase in both Online / Event transaction
-- volume and net sales.
--
-- These patterns reinforce the need to interpret the source as a combined
-- channel rather than conventional ecommerce activity.
--
--
-- 8. October Online / Event performance is extremely concentrated in a small
-- number of dates, consistent with the known annual event period.
--
-- Using the equivalent October 1 through October 29 period in each year, the
-- two highest-volume dates represented:
--
--   2023:
--     96.21% of Online / Event transaction events
--     97.90% of Online / Event net sales
--
--   2024:
--     95.15% of transaction events
--     95.72% of net sales
--
--   2025:
--     98.17% of transaction events
--     98.43% of net sales
--
-- Private operational context confirms that these dates align with the
-- retailer's annual event period.
--
-- However, Online / Event is a combined source and ordinary online activity
-- remains present within it. The portfolio data therefore cannot attribute
-- every transaction on those dates exclusively to the event.
--
-- The defensible conclusion is that October Online / Event performance is
-- strongly concentrated around the annual event period rather than being
-- distributed evenly across the month.
--
--
-- Overall:
--
-- The retailer's performance is strongly seasonal, but the year-over-year
-- changes within that seasonal cycle were not uniform.
--
-- The 2024 decline was broad across the comparable January-October period,
-- while December recovered to near-prior-year transaction volume and exceeded
-- prior-year sales.
--
-- In 2025, monthly performance became more mixed: several months generated
-- comparable or higher sales despite fewer transactions, while other periods
-- remained materially weaker.
--
-- Source-level analysis further shows that seasonal movement cannot be treated
-- as a single retailer-wide pattern. Individual physical stores contributed
-- differently to year-end performance, while Online / Event contains a highly
-- concentrated annual event period.
--
-- Analysis decision:
-- Use both comparable-period and full-year views when interpreting seasonality,
-- and separate retailer-level trends from source-specific seasonal behaviour
-- rather than relying on annual totals alone.