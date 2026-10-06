-- ANALYSIS 05
-- Discount & Return Patterns


-- Purpose:
-- Examine recorded positive discount activity and net-negative return activity
-- across equivalent January 1 - October 29 periods in 2023, 2024, and 2025.
--
-- Discount and return behaviour are treated separately because the discount
-- field is signed and can contain negative values associated with transaction
-- structures that should not be interpreted as ordinary promotional discounting.
--
-- Positive discount activity is therefore measured only on positive-value
-- transaction events where the transaction-level recorded discount is greater
-- than zero.
--
-- Return activity is measured separately using net-negative transaction events.
--
-- A net-negative transaction event is used as the return definition because
-- mixed transactions whose overall value remains positive should not be
-- classified as full return events.
--
-- Recorded discount activity is not treated as a conventional discount-rate
-- KPI or as a direct measure of pricing strategy. Clearance activity,
-- event-based selling, and transaction-recording differences can affect the
-- field across periods.
--
-- Because the available 2025 dataset ends October 29, all three-year
-- comparisons use the same January 1 - October 29 period.



-- ============================================================
-- Step 1: Retailer-level positive discount activity
-- ============================================================
--
-- Aggregate Sale Lines to one row per transaction event before evaluating
-- discount activity.
--
-- Only positive-value transactions are included in the discount denominator.
--
-- A transaction is considered positively discounted when its summed recorded
-- discount value is greater than zero.
--
-- Negative recorded discount values are not interpreted as conventional
-- promotional discounting and are excluded from the positive-discount metric.
--
-- Transaction-level monetary values remain at full precision until the final
-- output is displayed.


WITH combined AS (

  SELECT
    2023 AS sale_year,
    sale_datetime,
    transaction_id,
    discount,
    total

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2023`

  UNION ALL

  SELECT
    2024 AS sale_year,
    sale_datetime,
    transaction_id,
    discount,
    total

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2024`

  UNION ALL

  SELECT
    2025 AS sale_year,
    sale_datetime,
    transaction_id,
    discount,
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

    SUM(discount)
      AS transaction_discount,

    SUM(total)
      AS transaction_total

  FROM comparable_period

  GROUP BY
    sale_year,
    transaction_id
),


positive_value AS (

  SELECT *
  FROM transaction_level

  WHERE transaction_total > 0
)


SELECT
  sale_year,

  COUNT(*)
    AS positive_value_transactions,

  COUNTIF(transaction_discount > 0)
    AS positively_discounted_transactions,

  ROUND(
    SAFE_DIVIDE(
      COUNTIF(transaction_discount > 0),
      COUNT(*)
    ) * 100,
    2
  ) AS pct_positive_value_transactions_discounted,

  ROUND(
    SUM(
      IF(
        transaction_discount > 0,
        transaction_discount,
        0
      )
    ),
    2
  ) AS positive_discount_total,

  ROUND(
    AVG(
      IF(
        transaction_discount > 0,
        transaction_discount,
        NULL
      )
    ),
    2
  ) AS avg_positive_discount,

  ROUND(
    APPROX_QUANTILES(
      IF(
        transaction_discount > 0,
        transaction_discount,
        NULL
      ),
      100
    )[OFFSET(50)],
    2
  ) AS median_positive_discount

FROM positive_value

GROUP BY sale_year

ORDER BY sale_year;



-- ============================================================
-- Step 2: Positive discount activity by sales source
-- ============================================================
--
-- Break positive recorded discount activity down by anonymized sales source
-- to identify whether changes are broad across the business or concentrated
-- in particular sources.
--
-- Online / Event is a combined source category and should not be interpreted
-- as ecommerce-only activity.
--
-- The same positive-value transaction denominator used in Step 1 is retained
-- so source-level results remain comparable.


WITH combined AS (

  SELECT
    2023 AS sale_year,
    sale_datetime,
    transaction_id,
    sales_source,
    discount,
    total

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2023`

  UNION ALL

  SELECT
    2024 AS sale_year,
    sale_datetime,
    transaction_id,
    sales_source,
    discount,
    total

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2024`

  UNION ALL

  SELECT
    2025 AS sale_year,
    sale_datetime,
    transaction_id,
    sales_source,
    discount,
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

    SUM(discount)
      AS transaction_discount,

    SUM(total)
      AS transaction_total

  FROM comparable_period

  GROUP BY
    sale_year,
    transaction_id,
    sales_source
),


positive_value AS (

  SELECT *
  FROM transaction_level

  WHERE transaction_total > 0
)


SELECT
  sale_year,
  sales_source,

  COUNT(*)
    AS positive_value_transactions,

  COUNTIF(transaction_discount > 0)
    AS positively_discounted_transactions,

  ROUND(
    SAFE_DIVIDE(
      COUNTIF(transaction_discount > 0),
      COUNT(*)
    ) * 100,
    2
  ) AS pct_positive_value_transactions_discounted,

  ROUND(
    SUM(
      IF(
        transaction_discount > 0,
        transaction_discount,
        0
      )
    ),
    2
  ) AS positive_discount_total,

  ROUND(
    AVG(
      IF(
        transaction_discount > 0,
        transaction_discount,
        NULL
      )
    ),
    2
  ) AS avg_positive_discount,

  ROUND(
    APPROX_QUANTILES(
      IF(
        transaction_discount > 0,
        transaction_discount,
        NULL
      ),
      100
    )[OFFSET(50)],
    2
  ) AS median_positive_discount

FROM positive_value

GROUP BY
  sale_year,
  sales_source

ORDER BY
  sale_year,
  sales_source;



-- ============================================================
-- Step 3: Return activity by sales source
-- ============================================================
--
-- Define a return event as a transaction whose summed net sales value is
-- negative.
--
-- This identifies net-negative transaction events rather than individual
-- negative Sale Lines.
--
-- Mixed transactions that include returned merchandise but remain net-positive
-- overall are therefore retained as positive transaction events rather than
-- being classified as full return events.
--
-- Return rate uses all transaction events within each sales source as the
-- denominator.


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

    SUM(total)
      AS transaction_total

  FROM comparable_period

  GROUP BY
    sale_year,
    transaction_id,
    sales_source
)


SELECT
  sale_year,
  sales_source,

  COUNT(*)
    AS transaction_events,

  COUNTIF(transaction_total < 0)
    AS return_transaction_events,

  ROUND(
    SAFE_DIVIDE(
      COUNTIF(transaction_total < 0),
      COUNT(*)
    ) * 100,
    2
  ) AS pct_transactions_returns,

  ROUND(
    SUM(
      IF(
        transaction_total < 0,
        transaction_total,
        0
      )
    ),
    2
  ) AS return_net_sales,

  ROUND(
    AVG(
      IF(
        transaction_total < 0,
        transaction_total,
        NULL
      )
    ),
    2
  ) AS avg_return_value,

  ROUND(
    APPROX_QUANTILES(
      IF(
        transaction_total < 0,
        transaction_total,
        NULL
      ),
      100
    )[OFFSET(50)],
    2
  ) AS median_return_value

FROM transaction_level

GROUP BY
  sale_year,
  sales_source

ORDER BY
  sale_year,
  sales_source;



-- ============================================================
-- Step 4: Monthly discount and return patterns
-- Comparable period: January 1 - October 29, 2023-2025
-- ============================================================
--
-- Examine whether positive recorded discount activity and net-negative return
-- events are distributed evenly through the year or concentrated in particular
-- months.
--
-- Discount frequency uses positive-value transactions as its denominator.
--
-- Return frequency uses all transaction events as its denominator.
--
-- Keeping these denominators separate prevents return activity from distorting
-- the positive-discount measure.


WITH combined AS (

  SELECT
    2023 AS sale_year,
    sale_datetime,
    transaction_id,
    discount,
    total

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2023`

  UNION ALL

  SELECT
    2024 AS sale_year,
    sale_datetime,
    transaction_id,
    discount,
    total

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2024`

  UNION ALL

  SELECT
    2025 AS sale_year,
    sale_datetime,
    transaction_id,
    discount,
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

    EXTRACT(MONTH FROM sale_datetime)
      AS sale_month,

    FORMAT_DATE(
      '%B',
      DATE(sale_year, EXTRACT(MONTH FROM sale_datetime), 1)
    ) AS month_name,

    transaction_id,

    SUM(discount)
      AS transaction_discount,

    SUM(total)
      AS transaction_total

  FROM comparable_period

  GROUP BY
    sale_year,
    sale_month,
    month_name,
    transaction_id
)


SELECT
  sale_year,
  sale_month,
  month_name,

  COUNT(*)
    AS transaction_events,

  COUNTIF(transaction_total > 0)
    AS positive_value_transactions,

  COUNTIF(
    transaction_total > 0
    AND transaction_discount > 0
  ) AS positively_discounted_transactions,

  ROUND(
    SAFE_DIVIDE(
      COUNTIF(
        transaction_total > 0
        AND transaction_discount > 0
      ),
      COUNTIF(transaction_total > 0)
    ) * 100,
    2
  ) AS pct_positive_value_transactions_discounted,

  ROUND(
    SUM(
      IF(
        transaction_total > 0
        AND transaction_discount > 0,
        transaction_discount,
        0
      )
    ),
    2
  ) AS positive_discount_total,

  ROUND(
    AVG(
      IF(
        transaction_total > 0
        AND transaction_discount > 0,
        transaction_discount,
        NULL
      )
    ),
    2
  ) AS avg_positive_discount,

  COUNTIF(transaction_total < 0)
    AS return_transaction_events,

  ROUND(
    SAFE_DIVIDE(
      COUNTIF(transaction_total < 0),
      COUNT(*)
    ) * 100,
    2
  ) AS pct_transactions_returns,

  ROUND(
    SUM(
      IF(
        transaction_total < 0,
        transaction_total,
        0
      )
    ),
    2
  ) AS return_net_sales,

  ROUND(
    AVG(
      IF(
        transaction_total < 0,
        transaction_total,
        NULL
      )
    ),
    2
  ) AS avg_return_value,

  ROUND(
    APPROX_QUANTILES(
      IF(
        transaction_total < 0,
        transaction_total,
        NULL
      ),
      100
    )[OFFSET(50)],
    2
  ) AS median_return_value

FROM transaction_level

GROUP BY
  sale_year,
  sale_month,
  month_name

ORDER BY
  sale_year,
  sale_month;



-- ============================================================
-- Step 5: October positive discount activity by sales source
-- Comparable period: October 1 - October 29, 2023-2025
-- ============================================================
--
-- Measure how October positive recorded discount activity is distributed
-- across sales sources.
--
-- Private operational context indicates that October includes the retailer's
-- annual event period.
--
-- Online / Event combines ordinary online transactions with event-related
-- activity, so positive discount dollars within this source cannot be
-- attributed exclusively to the event.
--
-- The equivalent October 1 - October 29 period is used in all three years so
-- the partial 2025 dataset is compared consistently.


WITH combined AS (

  SELECT
    2023 AS sale_year,
    sale_datetime,
    transaction_id,
    sales_source,
    discount,
    total

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2023`

  UNION ALL

  SELECT
    2024 AS sale_year,
    sale_datetime,
    transaction_id,
    sales_source,
    discount,
    total

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2024`

  UNION ALL

  SELECT
    2025 AS sale_year,
    sale_datetime,
    transaction_id,
    sales_source,
    discount,
    total

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2025`
),


october_period AS (

  SELECT *
  FROM combined

  WHERE DATE(sale_datetime)
    BETWEEN DATE(sale_year, 10, 1)
        AND DATE(sale_year, 10, 29)
),


transaction_level AS (

  SELECT
    sale_year,
    transaction_id,
    sales_source,

    SUM(discount)
      AS transaction_discount,

    SUM(total)
      AS transaction_total

  FROM october_period

  GROUP BY
    sale_year,
    transaction_id,
    sales_source
),


positive_value AS (

  SELECT *
  FROM transaction_level

  WHERE transaction_total > 0
),


source_discount AS (

  SELECT
    sale_year,
    sales_source,

    COUNT(*)
      AS positive_value_transactions,

    COUNTIF(transaction_discount > 0)
      AS positively_discounted_transactions,

    SUM(
      IF(
        transaction_discount > 0,
        transaction_discount,
        0
      )
    ) AS positive_discount_total

  FROM positive_value

  GROUP BY
    sale_year,
    sales_source
),


october_totals AS (

  SELECT
    sale_year,

    SUM(positive_discount_total)
      AS october_positive_discount_total

  FROM source_discount

  GROUP BY sale_year
)


SELECT
  s.sale_year,
  s.sales_source,

  s.positive_value_transactions,

  s.positively_discounted_transactions,

  ROUND(s.positive_discount_total, 2)
    AS positive_discount_total,

  ROUND(
    SAFE_DIVIDE(
      s.positive_discount_total,
      o.october_positive_discount_total
    ) * 100,
    2
  ) AS pct_of_october_positive_discount

FROM source_discount AS s

JOIN october_totals AS o
  USING (sale_year)

ORDER BY
  s.sale_year,
  s.positive_discount_total DESC;



-- ============================================================
-- Step 6: January-September positive discount activity
-- ============================================================
--
-- Remove October from the positive-discount comparison to test whether the
-- higher annual recorded discount totals are broadly distributed across
-- routine selling months or concentrated around the October event period.
--
-- January through September is complete in all three years.
--
-- The same transaction-level positive-discount definition used in Steps 1
-- and 2 is retained.


WITH combined AS (

  SELECT
    2023 AS sale_year,
    sale_datetime,
    transaction_id,
    discount,
    total

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2023`

  UNION ALL

  SELECT
    2024 AS sale_year,
    sale_datetime,
    transaction_id,
    discount,
    total

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2024`

  UNION ALL

  SELECT
    2025 AS sale_year,
    sale_datetime,
    transaction_id,
    discount,
    total

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2025`
),


january_september AS (

  SELECT *
  FROM combined

  WHERE DATE(sale_datetime)
    BETWEEN DATE(sale_year, 1, 1)
        AND DATE(sale_year, 9, 30)
),


transaction_level AS (

  SELECT
    sale_year,
    transaction_id,

    SUM(discount)
      AS transaction_discount,

    SUM(total)
      AS transaction_total

  FROM january_september

  GROUP BY
    sale_year,
    transaction_id
),


positive_value AS (

  SELECT *
  FROM transaction_level

  WHERE transaction_total > 0
)


SELECT
  sale_year,

  COUNT(*)
    AS positive_value_transactions,

  COUNTIF(transaction_discount > 0)
    AS positively_discounted_transactions,

  ROUND(
    SAFE_DIVIDE(
      COUNTIF(transaction_discount > 0),
      COUNT(*)
    ) * 100,
    2
  ) AS pct_positive_value_transactions_discounted,

  ROUND(
    SUM(
      IF(
        transaction_discount > 0,
        transaction_discount,
        0
      )
    ),
    2
  ) AS positive_discount_total,

  ROUND(
    AVG(
      IF(
        transaction_discount > 0,
        transaction_discount,
        NULL
      )
    ),
    2
  ) AS avg_positive_discount,

  ROUND(
    APPROX_QUANTILES(
      IF(
        transaction_discount > 0,
        transaction_discount,
        NULL
      ),
      100
    )[OFFSET(50)],
    2
  ) AS median_positive_discount

FROM positive_value

GROUP BY sale_year

ORDER BY sale_year;



-- ============================================================
-- Findings
-- ============================================================
--
-- Analytical scope:
-- Positive recorded discount activity and return activity are analyzed
-- separately because they represent different transaction behaviours.
--
-- Positive discount activity is measured only on positive-value transaction
-- events with a transaction-level recorded discount greater than zero.
--
-- Return activity is measured using net-negative transaction events.
--
-- Recorded discount values are not treated as a conventional discount-rate
-- KPI or as a direct measure of pricing strategy because clearance activity,
-- event-based selling, and transaction-recording differences may influence
-- the field across periods.
--
--
-- 1. The frequency of positive discount activity remained relatively stable
-- across the three comparable periods.
--
-- The share of positive-value transactions with a positive recorded discount
-- was:
--
--   2023: 25.79%
--   2024: 24.43%
--   2025: 25.92%
--
-- Positive discount frequency therefore did not change dramatically at the
-- retailer level despite larger differences in recorded discount dollars.
--
--
-- 2. Positive recorded discount value increased substantially in 2024 before
-- easing slightly in 2025.
--
-- Total positive recorded discount activity was:
--
--   2023: $910,056.43
--   2024: $1,033,063.06
--   2025: $1,004,644.29
--
-- Average positive discount per discounted transaction increased from
-- $110.54 in 2023 to $157.72 in 2024 and remained elevated at $153.12 in 2025.
--
-- Median positive discount was:
--
--   2023: $57.00
--   2024: $70.00
--   2025: $64.00
--
-- The change in discount dollars therefore reflects larger recorded discount
-- amounts on some transactions rather than simply a higher proportion of
-- transactions receiving discounts.
--
--
-- 3. Online / Event accounts for a disproportionate share of positive
-- recorded discount activity.
--
-- Positive discount frequency within Online / Event increased from:
--
--   2023: 44.75%
--   2024: 52.91%
--   2025: 54.15%
--
-- Positive recorded discount totals were:
--
--   2023: $277,909.27
--   2024: $433,740.27
--   2025: $389,431.38
--
-- Average and median positive discount amounts were also consistently higher
-- in Online / Event than in the physical-store sources.
--
-- Because Online / Event combines ordinary online transactions with
-- event-related activity, these values should not be interpreted as
-- ecommerce-only discount behaviour.
--
--
-- 4. October is the dominant source of the apparent increase in recorded
-- discount activity.
--
-- October positive discount totals were:
--
--   2023: $323,685.89
--   2024: $452,764.54
--   2025: $438,497.63
--
-- Positive discount frequency in October was also unusually high:
--
--   2023: 55.91%
--   2024: 59.30%
--   2025: 61.97%
--
-- Online / Event accounted for the majority of October positive discount
-- dollars:
--
--   2023: 84.13%
--   2024: 91.60%
--   2025: 88.01%
--
-- Private operational context indicates that October includes the annual
-- event period.
--
-- However, because Online / Event is a combined source, the portfolio data
-- cannot attribute every recorded discount dollar exclusively to the event.
--
--
-- 5. Removing October produces a much more stable discount pattern.
--
-- January-September positive recorded discount totals were:
--
--   2023: $586,370.54
--   2024: $580,298.52
--   2025: $566,146.66
--
-- Positive discount frequency over January-September was:
--
--   2023: 22.57%
--   2024: 20.53%
--   2025: 21.49%
--
-- The large increase in total positive discount activity from 2023 to 2024
-- was therefore not driven by a broad increase across routine selling months.
--
-- In fact, January-September positive discount dollars declined slightly,
-- while October alone increased by more than the retailer-wide annual change.
--
-- This indicates that event-period concentration materially affects the
-- interpretation of year-over-year recorded discount totals.
--
--
-- 6. Return behaviour followed a different pattern from discount activity.
--
-- Across all sources, the overall net-negative transaction-event rate was
-- approximately:
--
--   2023: 4.20%
--   2024: 4.87%
--   2025: 4.88%
--
-- The retailer-level rate therefore increased between 2023 and 2024 and then
-- remained broadly stable in 2025.
--
-- Source-level patterns differed materially.
--
--
-- 7. Online / Event return activity declined consistently.
--
-- Net-negative transaction-event rates were:
--
--   2023: 9.80%
--   2024: 7.30%
--   2025: 4.83%
--
-- This represents a substantial reduction in the share of Online / Event
-- transactions ending with a negative net value.
--
--
-- 8. Store C moved in the opposite direction.
--
-- Store C return-event rates increased from:
--
--   2023: 2.83%
--   2024: 7.35%
--   2025: 9.70%
--
-- This is the clearest sustained increase in return activity among the
-- physical-store sources.
--
-- The transaction data identifies the pattern but does not establish its
-- operational, customer, or product-level cause.
--
--
-- 9. Store A and Store B were comparatively stable, while Store D increased
-- in 2024 before partially declining in 2025.
--
-- Return-event rates were:
--
--   Store A:
--     3.70% -> 4.30% -> 4.14%
--
--   Store B:
--     3.78% -> 3.28% -> 3.62%
--
--   Store D:
--     2.81% -> 6.42% -> 5.13%
--
-- These differences reinforce that retailer-wide return rates should not be
-- interpreted as a uniform source-level pattern.
--
--
-- 10. Return activity also shows a clear monthly pattern.
--
-- March return-event rates were:
--
--   2023: 7.29%
--   2024: 9.92%
--   2025: 9.34%
--
-- April showed an even stronger increase:
--
--   2023: 4.04%
--   2024: 12.69%
--   2025: 14.38%
--
-- By contrast, October return-event rates were comparatively low:
--
--   2023: 2.58%
--   2024: 1.92%
--   2025: 1.05%
--
-- The spring return pattern therefore differs substantially from the October
-- discount pattern and should be treated as a separate operational behaviour.
--
--
-- Overall:
--
-- Recorded discount and return activity cannot be explained by a single
-- retailer-wide trend.
--
-- Positive discount frequency remained relatively stable, while recorded
-- discount dollars were strongly influenced by October and the concentrated
-- Online / Event activity associated with the annual event period.
--
-- Once October is removed, January-September positive discount activity is
-- much more stable across the three years.
--
-- Return behaviour shows a different structure: Online / Event return activity
-- declined, Store C increased substantially, and spring months showed the
-- strongest retailer-level return rates.
--
-- Analysis decision:
-- Treat positive discount activity and returns as distinct transaction
-- behaviours, separate routine-period discount activity from the October
-- event-period effect, and avoid interpreting recorded discount values as a
-- conventional pricing-strategy KPI.