-- VISUALIZATION DATA 01
-- Comparable Three-Year Performance Overview

-- Purpose:
-- Create the aggregated dataset used for the portfolio's opening
-- performance overview.
--
-- All three years use the same January 1 - October 29 period so partial-year
-- 2025 can be compared fairly with 2023 and 2024.

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
),

annual AS (

  SELECT
    sale_year,

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

  GROUP BY sale_year
),

with_previous_year AS (

  SELECT
    *,

    LAG(net_sales)
      OVER (ORDER BY sale_year)
      AS previous_year_net_sales,

    LAG(transaction_events)
      OVER (ORDER BY sale_year)
      AS previous_year_transactions,

    LAG(priced_net_units)
      OVER (ORDER BY sale_year)
      AS previous_year_priced_units

  FROM annual
)

SELECT
  sale_year,
  transaction_events,
  priced_net_units,
  net_sales,
  avg_net_sales_per_transaction,

  ROUND(
    SAFE_DIVIDE(
      net_sales - previous_year_net_sales,
      previous_year_net_sales
    ) * 100,
    1
  ) AS net_sales_yoy_pct,

  ROUND(
    SAFE_DIVIDE(
      transaction_events - previous_year_transactions,
      previous_year_transactions
    ) * 100,
    1
  ) AS transactions_yoy_pct,

  ROUND(
    SAFE_DIVIDE(
      priced_net_units - previous_year_priced_units,
      previous_year_priced_units
    ) * 100,
    1
  ) AS priced_units_yoy_pct

FROM with_previous_year

ORDER BY sale_year;