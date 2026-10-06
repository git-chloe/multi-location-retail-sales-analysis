-- VISUALIZATION DATA 02
-- Comparable Sales Performance by Source

-- Purpose:
-- Create the aggregated dataset used to compare sales performance across
-- anonymized stores and Online / Event.
--
-- All years use the same January 1 - October 29 period so 2025 can be
-- compared fairly with 2023 and 2024.

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
  sales_source

ORDER BY
  sales_source,
  sale_year;