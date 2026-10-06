-- DATA CLEANING 03
-- Validate Negative Quantity Activity

-- Purpose:
-- Evaluate negative quantities in the cleaned product-level Sale Line tables
-- before treating them as data-quality problems or removing them.
--
-- Negative quantities can represent legitimate operational activity such as
-- returns, exchanges, reversals, or other multi-line transaction behaviour.
--
-- Validation therefore occurs at both:
--   1. the individual Sale Line level, and
--   2. the complete Receipt_Number + sale_datetime transaction-event level.
--
-- No records are removed solely because quantity is negative.


-- ============================================================
-- Step 1: Validate overall cleaned datasets
-- ============================================================
-- Confirm row and transaction coverage, date range, net units, net sales,
-- missing product fields, and the number of negative-quantity Sale Lines.

WITH combined AS (

  SELECT
    2023 AS sale_year,
    sale_datetime,
    Receipt_Number,
    quantity,
    total,
    Sku,
    Details

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2023`


  UNION ALL


  SELECT
    2024,
    sale_datetime,
    Receipt_Number,
    quantity,
    total,
    Sku,
    Details

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2024`


  UNION ALL


  SELECT
    2025,
    sale_datetime,
    Receipt_Number,
    quantity,
    total,
    Sku,
    Details

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2025`
)

SELECT
  sale_year,

  COUNT(*) AS total_rows,

  COUNT(DISTINCT Receipt_Number)
    AS distinct_receipt_numbers,

  COUNT(
    DISTINCT CONCAT(
      Receipt_Number,
      '|',
      CAST(sale_datetime AS STRING)
    )
  ) AS transaction_events,

  MIN(sale_datetime) AS earliest_date,

  MAX(sale_datetime) AS latest_date,

  SUM(quantity) AS net_units,

  ROUND(SUM(total), 2) AS net_sales,

  COUNTIF(quantity < 0)
    AS negative_quantity_rows,

  COUNTIF(Sku IS NULL)
    AS missing_sku,

  COUNTIF(Details IS NULL)
    AS missing_details

FROM combined

GROUP BY sale_year

ORDER BY sale_year;


-- ============================================================
-- Step 2: Profile negative quantity values
-- ============================================================
-- Review the distribution of negative quantities rather than assuming
-- that larger negative values are invalid.

WITH combined AS (

  SELECT
    2023 AS sale_year,
    quantity,
    total

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2023`


  UNION ALL


  SELECT
    2024,
    quantity,
    total

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2024`


  UNION ALL


  SELECT
    2025,
    quantity,
    total

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2025`
)

SELECT
  sale_year,

  quantity,

  COUNT(*) AS row_count,

  ROUND(SUM(total), 2)
    AS total_value

FROM combined

WHERE quantity < 0

GROUP BY
  sale_year,
  quantity

ORDER BY
  sale_year,
  quantity DESC;


-- ============================================================
-- Step 3: Identify unusually large negative quantities
-- ============================================================
-- Quantity below -2 is used as an investigative threshold only.
-- It is not an exclusion rule.

WITH combined AS (

  SELECT
    2023 AS sale_year,
    sale_datetime,
    Receipt_Number,
    quantity

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2023`


  UNION ALL


  SELECT
    2024,
    sale_datetime,
    Receipt_Number,
    quantity

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2024`


  UNION ALL


  SELECT
    2025,
    sale_datetime,
    Receipt_Number,
    quantity

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2025`
)

SELECT
  sale_year,

  COUNT(*) AS flagged_sale_lines,

  COUNT(
    DISTINCT CONCAT(
      Receipt_Number,
      '|',
      CAST(sale_datetime AS STRING)
    )
  ) AS flagged_transaction_events,

  MIN(quantity) AS largest_negative_quantity

FROM combined

WHERE quantity < -2

GROUP BY sale_year

ORDER BY sale_year;


-- ============================================================
-- Step 4: Review complete flagged transaction events
-- ============================================================
-- Summarize the complete transaction events containing unusually large
-- negative quantities.
--
-- Reviewing the full event helps distinguish corrupted values from
-- legitimate transactions containing returns, exchanges, reversals, or
-- offsetting positive Sale Lines.
--
-- Product descriptions and other private transaction details were reviewed
-- separately and are not reproduced in the public repository.

WITH combined AS (

  SELECT
    2023 AS sale_year,
    sale_datetime,
    Receipt_Number,
    quantity,
    total,
    Sku

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2023`


  UNION ALL


  SELECT
    2024,
    sale_datetime,
    Receipt_Number,
    quantity,
    total,
    Sku

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2024`


  UNION ALL


  SELECT
    2025,
    sale_datetime,
    Receipt_Number,
    quantity,
    total,
    Sku

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2025`
),

flagged_transactions AS (

  SELECT DISTINCT
    sale_year,
    Receipt_Number,
    sale_datetime

  FROM combined

  WHERE quantity < -2
)

SELECT
  sales.sale_year,

  sales.Receipt_Number,

  sales.sale_datetime,

  COUNT(*) AS sale_lines,

  COUNTIF(sales.quantity < 0)
    AS negative_quantity_lines,

  COUNTIF(sales.quantity > 0)
    AS positive_quantity_lines,

  SUM(sales.quantity)
    AS transaction_net_units,

  ROUND(SUM(sales.total), 2)
    AS transaction_net_sales,

  COUNT(DISTINCT sales.Sku)
    AS distinct_skus

FROM combined AS sales

JOIN flagged_transactions AS flagged
  ON sales.sale_year = flagged.sale_year
 AND sales.Receipt_Number = flagged.Receipt_Number
 AND sales.sale_datetime = flagged.sale_datetime

GROUP BY
  sales.sale_year,
  sales.Receipt_Number,
  sales.sale_datetime

ORDER BY
  sales.sale_year,
  sales.sale_datetime,
  sales.Receipt_Number;


-- ============================================================
-- Findings
-- ============================================================
--
-- Negative quantities occur in all three cleaned source years and were
-- investigated before any exclusion rule was considered.
--
-- Negative-quantity Sale Line counts were:
--   - 2023: 3,572 rows
--   - 2024: 4,191 rows
--   - 2025: 2,242 rows
--
-- Most negative quantities were small:
--
--   2023:
--     - 3,510 rows had quantity = -1
--     - 51 rows had quantity = -2
--     - 11 rows had quantities below -2
--
--   2024:
--     - 4,130 rows had quantity = -1
--     - 45 rows had quantity = -2
--     - 16 rows had quantities below -2
--
--   2025:
--     - 2,180 rows had quantity = -1
--     - 51 rows had quantity = -2
--     - 11 rows had quantities below -2
--
-- Unusually large negative quantities occurred across:
--   - 9 transaction events in 2023, ranging as low as -24
--   - 14 transaction events in 2024, ranging as low as -15
--   - 7 transaction events in 2025, ranging as low as -13
--
-- These records were reviewed at the complete Receipt_Number +
-- sale_datetime transaction-event level rather than as isolated Sale Lines.
--
-- Private transaction review identified patterns consistent with legitimate
-- business activity, including returns, exchanges, reversals, replacements,
-- and other multi-unit operational transactions.
--
-- Several flagged transaction events contain both positive and negative
-- Sale Lines, supporting interpretation as exchange or reversal activity
-- rather than systematic duplication or corrupted quantity values.
--
-- Quantity, monetary values, and surrounding transaction activity were
-- internally consistent with legitimate operational behaviour.
--
-- No evidence was identified that unusually large negative quantities were
-- caused by parsing, type conversion, duplication, or a systematic
-- data-quality defect.
--
-- Cleaning decision:
-- Retain negative-quantity Sale Lines as legitimate transaction activity.
--
-- No rows are removed solely because quantity is negative.