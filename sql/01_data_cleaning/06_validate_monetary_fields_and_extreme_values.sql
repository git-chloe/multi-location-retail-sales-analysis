-- DATA CLEANING 06
-- Validate Monetary Fields and Extreme Values

-- Purpose:
-- Validate monetary relationships and investigate unusually large positive
-- and negative values before analysis.
--
-- Monetary extremes are evaluated at both the Sale Line and transaction-event
-- level rather than automatically treated as outliers.
--
-- Specific transaction IDs, product descriptions, operational notes, payment
-- references, and other proprietary evidence used during private validation
-- are not reproduced in this public version.


-- ============================================================
-- Step 1: Profile monetary ranges across years
-- ============================================================

WITH combined AS (

  SELECT
    2023 AS sale_year,
    subtotal,
    sales_tax,
    discount,
    loyalty,
    total

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2023`

  UNION ALL

  SELECT
    2024,
    subtotal,
    sales_tax,
    discount,
    loyalty,
    total

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2024`

  UNION ALL

  SELECT
    2025,
    subtotal,
    sales_tax,
    discount,
    loyalty,
    total

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2025`
)

SELECT
  sale_year,

  MIN(subtotal) AS min_subtotal,
  MAX(subtotal) AS max_subtotal,

  MIN(sales_tax) AS min_sales_tax,
  MAX(sales_tax) AS max_sales_tax,

  MIN(discount) AS min_discount,
  MAX(discount) AS max_discount,

  MIN(loyalty) AS min_loyalty,
  MAX(loyalty) AS max_loyalty,

  MIN(total) AS min_total,
  MAX(total) AS max_total

FROM combined

GROUP BY sale_year

ORDER BY sale_year;


-- ============================================================
-- Step 2: Validate the recorded Total relationship
-- ============================================================
-- Test whether Total reconciles to Subtotal + Sales_Tax.
--
-- Discount and Loyalty are retained source-system fields but are not assumed
-- to be additional arithmetic components of the recorded line Total.

WITH combined AS (

  SELECT
    2023 AS sale_year,
    subtotal,
    sales_tax,
    total

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2023`

  UNION ALL

  SELECT
    2024,
    subtotal,
    sales_tax,
    total

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2024`

  UNION ALL

  SELECT
    2025,
    subtotal,
    sales_tax,
    total

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2025`
)

SELECT
  sale_year,

  COUNT(*) AS total_rows,

  COUNTIF(
    ABS(total - (subtotal + sales_tax)) > 0.01
  ) AS rows_not_reconciling_within_one_cent,

  ROUND(
    MAX(
      ABS(total - (subtotal + sales_tax))
    ),
    2
  ) AS max_absolute_difference,

  ROUND(
    SUM(total - (subtotal + sales_tax)),
    2
  ) AS net_difference

FROM combined

GROUP BY sale_year

ORDER BY sale_year;


-- ============================================================
-- Step 3: Audit Discount sign behaviour
-- ============================================================
-- Positive and negative Discount values are evaluated separately across
-- positive, negative, and zero-value Sale Lines.
--
-- This avoids incorrectly treating Discount as a conventional markdown field
-- whose value should simply be subtracted from Subtotal.

WITH combined AS (

  SELECT
    2023 AS sale_year,
    total,
    discount

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2023`

  UNION ALL

  SELECT
    2024,
    total,
    discount

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2024`

  UNION ALL

  SELECT
    2025,
    total,
    discount

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2025`
)

SELECT
  sale_year,

  CASE
    WHEN total > 0 THEN 'Positive Total'
    WHEN total < 0 THEN 'Negative Total'
    ELSE 'Zero Total'
  END AS total_sign,

  COUNT(*) AS sale_lines,

  COUNTIF(discount > 0)
    AS positive_discount_lines,

  COUNTIF(discount < 0)
    AS negative_discount_lines,

  COUNTIF(discount = 0)
    AS zero_discount_lines,

  ROUND(
    SUM(CASE WHEN discount > 0 THEN discount ELSE 0 END),
    2
  ) AS positive_discount_value,

  ROUND(
    SUM(CASE WHEN discount < 0 THEN discount ELSE 0 END),
    2
  ) AS negative_discount_value,

  ROUND(SUM(discount), 2)
    AS net_discount

FROM combined

GROUP BY
  sale_year,
  total_sign

ORDER BY
  sale_year,
  CASE total_sign
    WHEN 'Positive Total' THEN 1
    WHEN 'Negative Total' THEN 2
    ELSE 3
  END;


-- ============================================================
-- Step 4: Profile transaction-level monetary ranges
-- ============================================================
-- Aggregate Sale Lines at the validated transaction-event grain before
-- evaluating monetary extremes.
--
-- Detailed transaction IDs and product-level evidence were reviewed privately
-- and are intentionally omitted from the public repository.

WITH combined AS (

  SELECT
    2023 AS sale_year,
    Receipt_Number,
    sale_datetime,
    quantity,
    subtotal,
    sales_tax,
    discount,
    loyalty,
    total

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2023`

  UNION ALL

  SELECT
    2024,
    Receipt_Number,
    sale_datetime,
    quantity,
    subtotal,
    sales_tax,
    discount,
    loyalty,
    total

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2024`

  UNION ALL

  SELECT
    2025,
    Receipt_Number,
    sale_datetime,
    quantity,
    subtotal,
    sales_tax,
    discount,
    loyalty,
    total

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2025`
),

transaction_totals AS (

  SELECT
    sale_year,
    Receipt_Number,
    sale_datetime,

    COUNT(*) AS sale_lines,
    SUM(quantity) AS net_units,
    SUM(subtotal) AS transaction_subtotal,
    SUM(sales_tax) AS transaction_sales_tax,
    SUM(discount) AS transaction_discount,
    SUM(loyalty) AS transaction_loyalty,
    SUM(total) AS transaction_total

  FROM combined

  GROUP BY
    sale_year,
    Receipt_Number,
    sale_datetime
)

SELECT
  sale_year,

  COUNT(*) AS transaction_events,

  ROUND(MIN(transaction_total), 2)
    AS min_transaction_total,

  ROUND(MAX(transaction_total), 2)
    AS max_transaction_total,

  ROUND(
    MAX(ABS(transaction_total)),
    2
  ) AS max_absolute_transaction_total

FROM transaction_totals

GROUP BY sale_year

ORDER BY sale_year;


-- ============================================================
-- Findings
-- ============================================================
--
-- Monetary validation found no evidence of systemic currency-parsing or
-- numeric-conversion errors.
--
-- Every Sale Line across all three source years reconciled to:
--
--   Total = Subtotal + Sales_Tax
--
-- within a one-cent tolerance.
--
-- Maximum row-level reconciliation difference was $0.01 in each year.
-- Small accumulated annual differences were consistent with cent-level
-- rounding rather than broken monetary logic.
--
-- The Discount field does not behave as an independent arithmetic component
-- of Total. Both positive and negative Discount values occur within legitimate
-- positive, negative, and zero-value Sale Lines.
--
-- Net recorded Discount reconciled to the annual cleaned-table totals, but
-- its signed values must be interpreted according to source-system behaviour
-- rather than assumed to represent a conventional markdown calculation.
--
-- Private review of the highest and lowest Sale Lines and complete transaction
-- events found legitimate merchandise, return, operational, bulk, event,
-- deposit, and department-level activity.
--
-- Several unusually large department-level transactions were independently
-- checked against private raw Sale and Payment records. They had valid closed
-- transaction status and matching recorded payments, providing additional
-- evidence that the extreme values represented genuine business activity.
--
-- Transaction-level review also demonstrated that large positive and negative
-- Sale Lines can offset within the same event. Extreme line magnitude alone
-- is therefore not sufficient evidence of an invalid transaction.
--
-- Cleaning decision:
-- Retain legitimate monetary extremes and preserve the source monetary fields.
--
-- Do not remove records solely because their monetary values are unusually
-- large or negative.
--
-- Do not independently subtract Discount or Loyalty when reconstructing Total.
--
-- Department-level and other operational placeholder records remain valid for
-- revenue reconciliation but may be separated from standard merchandise for
-- product-level analysis.