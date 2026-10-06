-- VISUALIZATION DATA 05
-- Monthly Recorded Discount Activity

-- Purpose:
-- Show how recorded positive discount activity changed by month
-- across the comparable January 1 - October 29 period.
--
-- Discount activity is calculated at transaction-event grain.
-- Only positive-value transactions are eligible for the discount metric.
-- A transaction is counted as having positive recorded discount activity
-- when its summed transaction_discount is greater than zero.
--
-- Returns are measured separately as net-negative transaction events.

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

    ROUND(SUM(total), 2)
      AS transaction_total,

    ROUND(SUM(discount), 2)
      AS transaction_discount

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

  COUNT(*) AS transaction_events,

  COUNTIF(transaction_total > 0)
    AS positive_value_transactions,

  COUNTIF(
    transaction_total > 0
    AND transaction_discount > 0
  ) AS positive_discount_transactions,

  ROUND(
    SAFE_DIVIDE(
      COUNTIF(
        transaction_total > 0
        AND transaction_discount > 0
      ),
      COUNTIF(transaction_total > 0)
    ) * 100,
    2
  ) AS positive_discount_rate_pct,

  ROUND(
    SUM(
      CASE
        WHEN transaction_total > 0
         AND transaction_discount > 0
        THEN transaction_discount
        ELSE 0
      END
    ),
    2
  ) AS positive_discount_total,

  ROUND(
    SAFE_DIVIDE(
      SUM(
        CASE
          WHEN transaction_total > 0
           AND transaction_discount > 0
          THEN transaction_discount
          ELSE 0
        END
      ),
      COUNTIF(
        transaction_total > 0
        AND transaction_discount > 0
      )
    ),
    2
  ) AS avg_positive_discount_per_discounted_transaction,

  COUNTIF(transaction_total < 0)
    AS return_events,

  ROUND(
    SAFE_DIVIDE(
      COUNTIF(transaction_total < 0),
      COUNT(*)
    ) * 100,
    2
  ) AS return_event_rate_pct

FROM transaction_level

GROUP BY
  sale_year,
  sale_month,
  month_name

ORDER BY
  sale_year,
  sale_month;