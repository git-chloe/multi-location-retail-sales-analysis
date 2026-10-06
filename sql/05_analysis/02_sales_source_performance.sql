-- ANALYSIS 02
-- Sales Source Performance


-- Purpose:
-- Compare Store A-D and Online / Event across equivalent January 1 - October 29
-- periods for 2023, 2024, and 2025.
--
-- Evaluate how transaction volume, priced-unit movement, net sales,
-- transaction value, sales share, and recorded activity differ across sources.
--
-- Because the 2025 dataset ends October 29, all year-over-year comparisons
-- use the same January 1 - October 29 period.
--
-- Online / Event is a combined source category and should not be interpreted
-- as ecommerce-only activity.



-- ============================================================
-- Step 1: Comparable-period performance by sales source
-- ============================================================
--
-- Establish the overall performance of each source using transaction events
-- rather than Sale Line count. Multiple Sale Lines may belong to the same
-- transaction event.
--
-- Both total net units and priced net units are retained so zero-value
-- operational quantity remains visible, while priced net units are used as
-- the primary portfolio unit-volume metric.


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


source_performance AS (

  SELECT
    sale_year,
    sales_source,

    COUNT(*) AS sale_line_rows,

    COUNT(DISTINCT transaction_id)
      AS transaction_events,

    SUM(quantity)
      AS net_units,

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
    ) AS sales_per_transaction,

    ROUND(
      SAFE_DIVIDE(
        SUM(
          CASE
            WHEN subtotal != 0 THEN quantity
            ELSE 0
          END
        ),
        COUNT(DISTINCT transaction_id)
      ),
      2
    ) AS priced_units_per_transaction

  FROM comparable_period

  GROUP BY
    sale_year,
    sales_source
),


year_totals AS (

  SELECT
    sale_year,

    SUM(total)
      AS year_net_sales

  FROM comparable_period

  GROUP BY sale_year
)


SELECT
  s.sale_year,
  s.sales_source,
  s.sale_line_rows,
  s.transaction_events,
  s.net_units,
  s.priced_net_units,
  s.net_sales,
  s.sales_per_transaction,
  s.priced_units_per_transaction,

  ROUND(
    SAFE_DIVIDE(
      s.net_sales,
      y.year_net_sales
    ) * 100,
    2
  ) AS share_of_year_sales_pct

FROM source_performance AS s

JOIN year_totals AS y
  USING (sale_year)

ORDER BY
  s.sale_year,
  s.net_sales DESC;



-- ============================================================
-- Step 2: Year-over-year change by sales source
-- ============================================================
--
-- Compare each sales source only with its own prior-year performance.
--
-- This highlights whether changes are driven by transaction volume, priced
-- units, transaction value, or a combination of factors.
--
-- Priced net units are used for year-over-year unit comparisons so legitimate
-- zero-value operational lines do not distort the portfolio performance metric.
--
-- Per-transaction metrics are calculated at full precision before year-over-
-- year change is calculated. Rounding is applied only in the final output.


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


source_performance AS (

  SELECT
    sale_year,
    sales_source,

    COUNT(DISTINCT transaction_id)
      AS transaction_events,

    SUM(
      CASE
        WHEN subtotal != 0 THEN quantity
        ELSE 0
      END
    ) AS priced_net_units,

    SUM(total)
      AS net_sales,

    SAFE_DIVIDE(
      SUM(total),
      COUNT(DISTINCT transaction_id)
    ) AS sales_per_transaction,

    SAFE_DIVIDE(
      SUM(
        CASE
          WHEN subtotal != 0 THEN quantity
          ELSE 0
        END
      ),
      COUNT(DISTINCT transaction_id)
    ) AS priced_units_per_transaction

  FROM comparable_period

  GROUP BY
    sale_year,
    sales_source
),


with_prior_year AS (

  SELECT
    *,

    LAG(transaction_events) OVER (
      PARTITION BY sales_source
      ORDER BY sale_year
    ) AS prior_transaction_events,

    LAG(priced_net_units) OVER (
      PARTITION BY sales_source
      ORDER BY sale_year
    ) AS prior_priced_net_units,

    LAG(net_sales) OVER (
      PARTITION BY sales_source
      ORDER BY sale_year
    ) AS prior_net_sales,

    LAG(sales_per_transaction) OVER (
      PARTITION BY sales_source
      ORDER BY sale_year
    ) AS prior_sales_per_transaction,

    LAG(priced_units_per_transaction) OVER (
      PARTITION BY sales_source
      ORDER BY sale_year
    ) AS prior_priced_units_per_transaction

  FROM source_performance
)


SELECT
  sale_year,
  sales_source,

  transaction_events,
  prior_transaction_events,

  ROUND(
    SAFE_DIVIDE(
      transaction_events - prior_transaction_events,
      prior_transaction_events
    ) * 100,
    2
  ) AS transaction_events_yoy_pct,

  priced_net_units,
  prior_priced_net_units,

  ROUND(
    SAFE_DIVIDE(
      priced_net_units - prior_priced_net_units,
      prior_priced_net_units
    ) * 100,
    2
  ) AS priced_net_units_yoy_pct,

  ROUND(net_sales, 2)
    AS net_sales,

  ROUND(prior_net_sales, 2)
    AS prior_net_sales,

  ROUND(
    SAFE_DIVIDE(
      net_sales - prior_net_sales,
      prior_net_sales
    ) * 100,
    2
  ) AS net_sales_yoy_pct,

  ROUND(sales_per_transaction, 2)
    AS sales_per_transaction,

  ROUND(prior_sales_per_transaction, 2)
    AS prior_sales_per_transaction,

  ROUND(
    SAFE_DIVIDE(
      sales_per_transaction - prior_sales_per_transaction,
      prior_sales_per_transaction
    ) * 100,
    2
  ) AS sales_per_transaction_yoy_pct,

  ROUND(priced_units_per_transaction, 2)
    AS priced_units_per_transaction,

  ROUND(prior_priced_units_per_transaction, 2)
    AS prior_priced_units_per_transaction,

  ROUND(
    SAFE_DIVIDE(
      priced_units_per_transaction - prior_priced_units_per_transaction,
      prior_priced_units_per_transaction
    ) * 100,
    2
  ) AS priced_units_per_transaction_yoy_pct

FROM with_prior_year

ORDER BY
  sales_source,
  sale_year;



-- ============================================================
-- Step 3A: Recorded activity days by physical store
-- ============================================================
--
-- Generate a complete calendar so dates with no recorded transactions remain
-- visible rather than disappearing from the sales data.
--
-- A day with no recorded transactions does not independently confirm that a
-- store was closed. It only indicates no transaction event was recorded.


WITH calendar AS (

  SELECT
    sale_year,
    sale_date

  FROM UNNEST([2023, 2024, 2025]) AS sale_year

  CROSS JOIN UNNEST(
    GENERATE_DATE_ARRAY(
      DATE(sale_year, 1, 1),
      DATE(sale_year, 10, 29)
    )
  ) AS sale_date
),


stores AS (

  SELECT sales_source

  FROM UNNEST([
    'Store A',
    'Store B',
    'Store C',
    'Store D'
  ]) AS sales_source
),


combined AS (

  SELECT
    2023 AS sale_year,
    DATE(sale_datetime) AS sale_date,
    transaction_id,
    sales_source

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2023`

  UNION ALL

  SELECT
    2024 AS sale_year,
    DATE(sale_datetime) AS sale_date,
    transaction_id,
    sales_source

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2024`

  UNION ALL

  SELECT
    2025 AS sale_year,
    DATE(sale_datetime) AS sale_date,
    transaction_id,
    sales_source

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2025`
),


daily_activity AS (

  SELECT
    c.sale_year,
    c.sale_date,
    s.sales_source,

    COUNT(DISTINCT d.transaction_id)
      AS transaction_events

  FROM calendar AS c

  CROSS JOIN stores AS s

  LEFT JOIN combined AS d
    ON c.sale_year = d.sale_year
   AND c.sale_date = d.sale_date
   AND s.sales_source = d.sales_source

  GROUP BY
    c.sale_year,
    c.sale_date,
    s.sales_source
)


SELECT
  sale_year,
  sales_source,

  COUNT(*)
    AS calendar_days,

  COUNTIF(transaction_events > 0)
    AS days_with_recorded_sales,

  COUNTIF(transaction_events = 0)
    AS days_without_recorded_sales,

  ROUND(
    SAFE_DIVIDE(
      COUNTIF(transaction_events > 0),
      COUNT(*)
    ) * 100,
    2
  ) AS pct_days_with_recorded_sales

FROM daily_activity

GROUP BY
  sale_year,
  sales_source

ORDER BY
  sale_year,
  sales_source;



-- ============================================================
-- Step 3B: Monthly recorded activity by physical store
-- ============================================================
--
-- Break recorded active days down by month to show whether differences in
-- store activity are persistent or concentrated in particular periods.
--
-- As in Step 3A, zero recorded transaction events indicate only that no
-- transaction was recorded on that date; they do not independently establish
-- whether a store was open or closed.


WITH calendar AS (

  SELECT
    sale_year,
    sale_date

  FROM UNNEST([2023, 2024, 2025]) AS sale_year

  CROSS JOIN UNNEST(
    GENERATE_DATE_ARRAY(
      DATE(sale_year, 1, 1),
      DATE(sale_year, 10, 29)
    )
  ) AS sale_date
),


stores AS (

  SELECT sales_source

  FROM UNNEST([
    'Store A',
    'Store B',
    'Store C',
    'Store D'
  ]) AS sales_source
),


combined AS (

  SELECT
    2023 AS sale_year,
    DATE(sale_datetime) AS sale_date,
    transaction_id,
    sales_source

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2023`

  UNION ALL

  SELECT
    2024 AS sale_year,
    DATE(sale_datetime) AS sale_date,
    transaction_id,
    sales_source

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2024`

  UNION ALL

  SELECT
    2025 AS sale_year,
    DATE(sale_datetime) AS sale_date,
    transaction_id,
    sales_source

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2025`
),


daily_activity AS (

  SELECT
    c.sale_year,
    c.sale_date,
    s.sales_source,

    COUNT(DISTINCT d.transaction_id)
      AS transaction_events

  FROM calendar AS c

  CROSS JOIN stores AS s

  LEFT JOIN combined AS d
    ON c.sale_year = d.sale_year
   AND c.sale_date = d.sale_date
   AND s.sales_source = d.sales_source

  GROUP BY
    c.sale_year,
    c.sale_date,
    s.sales_source
)


SELECT
  sale_year,

  EXTRACT(MONTH FROM sale_date)
    AS sale_month,

  FORMAT_DATE(
    '%B',
    MIN(sale_date)
  ) AS month_name,

  sales_source,

  COUNT(*)
    AS calendar_days,

  COUNTIF(transaction_events > 0)
    AS days_with_recorded_sales,

  COUNTIF(transaction_events = 0)
    AS days_without_recorded_sales,

  ROUND(
    SAFE_DIVIDE(
      COUNTIF(transaction_events > 0),
      COUNT(*)
    ) * 100,
    2
  ) AS pct_days_with_recorded_sales

FROM daily_activity

GROUP BY
  sale_year,
  sale_month,
  sales_source

ORDER BY
  sale_year,
  sale_month,
  sales_source;



-- ============================================================
-- Step 4: January performance per recorded active day
-- ============================================================
--
-- Use January as a consistently busy winter month while avoiding the
-- November/December promotional period.
--
-- Normalize performance by recorded active day to test whether lower annual
-- totals at Store C and Store D are explained primarily by fewer recorded
-- active days or also by lower daily transaction and sales volume.
--
-- Average, median, and maximum values are shown together so unusually strong
-- individual days do not distort the interpretation.


WITH combined AS (

  SELECT
    2023 AS sale_year,
    DATE(sale_datetime) AS sale_date,
    transaction_id,
    sales_source,
    total

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2023`

  UNION ALL

  SELECT
    2024 AS sale_year,
    DATE(sale_datetime) AS sale_date,
    transaction_id,
    sales_source,
    total

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2024`

  UNION ALL

  SELECT
    2025 AS sale_year,
    DATE(sale_datetime) AS sale_date,
    transaction_id,
    sales_source,
    total

  FROM `retail-sales-analytics-510318.retail_sales.portfolio_sales_2025`
),


daily_performance AS (

  SELECT
    sale_year,
    sale_date,
    sales_source,

    COUNT(DISTINCT transaction_id)
      AS transaction_events,

    ROUND(SUM(total), 2)
      AS net_sales

  FROM combined

  WHERE EXTRACT(MONTH FROM sale_date) = 1

    AND sales_source IN (
      'Store A',
      'Store B',
      'Store C',
      'Store D'
    )

  GROUP BY
    sale_year,
    sale_date,
    sales_source
)


SELECT
  sale_year,
  sales_source,

  COUNT(*)
    AS recorded_active_days,

  SUM(transaction_events)
    AS january_transaction_events,

  ROUND(SUM(net_sales), 2)
    AS january_net_sales,

  ROUND(AVG(transaction_events), 2)
    AS avg_transactions_per_active_day,

  APPROX_QUANTILES(
    transaction_events,
    100
  )[OFFSET(50)]
    AS median_transactions_per_active_day,

  MAX(transaction_events)
    AS highest_transactions_in_one_day,

  ROUND(AVG(net_sales), 2)
    AS avg_sales_per_active_day,

  ROUND(
    APPROX_QUANTILES(
      net_sales,
      100
    )[OFFSET(50)],
    2
  ) AS median_sales_per_active_day,

  ROUND(MAX(net_sales), 2)
    AS highest_sales_in_one_day

FROM daily_performance

GROUP BY
  sale_year,
  sales_source

ORDER BY
  sale_year,
  sales_source;



-- ============================================================
-- Findings
-- ============================================================
--
-- All year-over-year comparisons use the equivalent January 1 through
-- October 29 period because the available 2025 dataset ends October 29.
--
-- Store A and Store B remained the two largest physical-store sales sources
-- throughout the comparable periods.
--
-- Store A represented 33.71% of comparable-period net sales in 2023 and
-- 33.78% in 2024. In 2025, Store B became the largest source at 33.54%,
-- narrowly ahead of Store A at 32.60%.
--
-- Online / Event increased its share of comparable-period net sales from
-- 15.70% in 2023 to 19.63% in 2024 and 19.80% in 2025.
--
-- Online / Event also consistently generated the highest net sales per
-- transaction of any source.
--
-- From 2023 to 2024, Online / Event transaction events decreased 18.77% and
-- priced net units decreased 10.67%, while net sales increased 2.37% and
-- sales per transaction increased 26.02%.
--
-- From 2024 to 2025, Online / Event transaction events decreased another
-- 7.47%, while priced net units increased 24.62%, net sales remained nearly
-- flat at +0.26%, sales per transaction increased 8.35%, and priced units per
-- transaction increased 34.68%.
--
-- The combined Online / Event source therefore generated fewer but
-- progressively larger transaction events.
--
-- Store A declined materially between 2023 and 2024:
--
--   transaction events      -13.83%
--   priced net units        -22.36%
--   net sales               -17.97%
--
-- Between 2024 and 2025, Store A transaction events decreased 8.47%, priced
-- net units decreased 10.26%, and net sales decreased 4.09%.
--
-- Sales per transaction increased 4.78% in 2025, partially offsetting lower
-- transaction and priced-unit volume.
--
-- Store B declined substantially between 2023 and 2024, but showed the
-- clearest stabilization in 2025.
--
-- From 2024 to 2025, Store B transaction events increased 0.47%, priced net
-- units increased 0.96%, net sales increased 5.35%, and sales per transaction
-- increased 4.85%.
--
-- Store C remained a smaller-volume source. From 2024 to 2025, transaction
-- events decreased 4.78% and priced net units were nearly flat at -0.74%,
-- while net sales increased 3.12% and sales per transaction increased 8.29%.
--
-- Store D showed the largest sustained decline.
--
-- From 2023 to 2024:
--
--   transaction events      -30.01%
--   priced net units        -34.11%
--   net sales               -42.59%
--
-- From 2024 to 2025:
--
--   transaction events      -19.12%
--   priced net units         -8.63%
--   net sales               -20.13%
--
-- Store D's share of comparable-period net sales declined from 8.82% in 2023
-- to 6.18% in 2024 and 4.97% in 2025.
--
-- Recorded activity also differed across physical stores.
--
-- Store A and Store B recorded transaction activity on approximately 95-97%
-- of calendar days across the comparable periods.
--
-- Store C's recorded-activity rate remained comparatively stable at 80.79%
-- in 2023, 79.21% in 2024, and 79.47% in 2025.
--
-- Store D's recorded-activity rate declined from 94.04% in 2023 to 81.85%
-- in 2024 and 69.87% in 2025.
--
-- Monthly results show particularly low recorded activity for Store D in
-- later 2025, reaching 55.17% of calendar days in October.
--
-- Zero recorded transactions do not independently confirm that a store was
-- closed, so these results are interpreted as recorded-activity patterns
-- rather than verified operating schedules.
--
-- January performance was normalized by recorded active day to test whether
-- differences in annual sales totals could be explained primarily by the
-- number of days with recorded transactions.
--
-- In January 2025:
--
--   Store A averaged 78.03 transaction events and $13,949.75 in net sales
--   per recorded active day.
--
--   Store B averaged 81.47 transaction events and $13,741.64 in net sales
--   per recorded active day.
--
--   Store C averaged 35.50 transaction events and $5,303.35 in net sales
--   per recorded active day.
--
--   Store D averaged 17.27 transaction events and $2,795.27 in net sales
--   per recorded active day.
--
-- Median daily performance showed the same broad pattern, indicating that the
-- difference was not driven only by unusually strong individual days.
--
-- Recorded active-day exposure therefore does not fully explain the
-- performance differences between physical stores. Store C and Store D also
-- generated materially lower transaction and sales volume on days when
-- activity was recorded.
--
-- Overall, the retailer-wide trend masks substantially different source-level
-- patterns. Online / Event shifted toward fewer, larger transactions; Store A
-- retained more sales value than transaction and unit volume would suggest;
-- Store B stabilized in 2025; Store C showed modest improvement in transaction
-- value; and Store D continued to decline in transaction volume, sales, and
-- recorded activity.
--
-- Analysis decision:
-- Carry these source-level differences into transaction-composition and
-- seasonal analysis rather than treating retailer-wide change as a single
-- uniform trend.