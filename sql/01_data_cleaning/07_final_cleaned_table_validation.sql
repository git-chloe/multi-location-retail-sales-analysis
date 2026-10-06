-- DATA CLEANING 07
-- Final Cleaned-Table Validation

-- Purpose:
-- Perform a final quality-control validation of all cleaned annual Sale Line
-- tables before privacy transformation and public-facing anonymization.
--
-- Confirm:
--   1. Final row, transaction, quantity, and monetary totals.
--   2. Required-field completeness.
--   3. Valid annual date coverage.
--   4. Final source structure.
--   5. Expected cleaned-table schema.
--
-- The private validation included retailer-specific source codes and other
-- operational details. Identifying source labels are intentionally omitted
-- from this public version.


-- ============================================================
-- Step 1: Final cross-year table summary
-- ============================================================

WITH combined AS (

  SELECT
    2023 AS sale_year,
    sale_datetime,
    Receipt_Number,
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
    sale_datetime,
    Receipt_Number,
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
    sale_datetime,
    Receipt_Number,
    quantity,
    subtotal,
    sales_tax,
    discount,
    loyalty,
    total

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

  MIN(sale_datetime)
    AS earliest_date,

  MAX(sale_datetime)
    AS latest_date,

  SUM(quantity)
    AS net_units,

  ROUND(SUM(subtotal), 2)
    AS net_subtotal,

  ROUND(SUM(sales_tax), 2)
    AS net_sales_tax,

  ROUND(SUM(discount), 2)
    AS net_discount,

  ROUND(SUM(loyalty), 2)
    AS net_loyalty,

  ROUND(SUM(total), 2)
    AS net_sales

FROM combined

GROUP BY sale_year

ORDER BY sale_year;


-- ============================================================
-- Step 2: Final required-field completeness check
-- ============================================================

WITH combined AS (

  SELECT
    2023 AS sale_year,
    sale_datetime,
    Receipt_Number,
    sales_source_code,
    transaction_attribute,
    quantity,
    subtotal,
    sales_tax,
    discount,
    loyalty,
    total,
    Details,
    Sku

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2023`

  UNION ALL

  SELECT
    2024,
    sale_datetime,
    Receipt_Number,
    sales_source_code,
    transaction_attribute,
    quantity,
    subtotal,
    sales_tax,
    discount,
    loyalty,
    total,
    Details,
    Sku

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2024`

  UNION ALL

  SELECT
    2025,
    sale_datetime,
    Receipt_Number,
    sales_source_code,
    transaction_attribute,
    quantity,
    subtotal,
    sales_tax,
    discount,
    loyalty,
    total,
    Details,
    Sku

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2025`
)

SELECT
  sale_year,

  COUNTIF(sale_datetime IS NULL)
    AS missing_dates,

  COUNTIF(Receipt_Number IS NULL)
    AS missing_receipt_numbers,

  COUNTIF(sales_source_code IS NULL)
    AS missing_sales_source,

  COUNTIF(quantity IS NULL)
    AS missing_quantity,

  COUNTIF(subtotal IS NULL)
    AS missing_subtotal,

  COUNTIF(sales_tax IS NULL)
    AS missing_sales_tax,

  COUNTIF(discount IS NULL)
    AS missing_discount,

  COUNTIF(loyalty IS NULL)
    AS missing_loyalty,

  COUNTIF(total IS NULL)
    AS missing_total,

  COUNTIF(Details IS NULL)
    AS missing_details,

  COUNTIF(Sku IS NULL)
    AS missing_sku,

  COUNTIF(transaction_attribute IS NOT NULL)
    AS rows_with_transaction_attribute

FROM combined

GROUP BY sale_year

ORDER BY sale_year;


-- ============================================================
-- Step 3: Validate annual date coverage
-- ============================================================

WITH combined AS (

  SELECT
    2023 AS expected_year,
    sale_datetime

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2023`

  UNION ALL

  SELECT
    2024,
    sale_datetime

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2024`

  UNION ALL

  SELECT
    2025,
    sale_datetime

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2025`
)

SELECT
  expected_year,

  COUNT(*) AS total_rows,

  COUNTIF(
    EXTRACT(YEAR FROM sale_datetime) != expected_year
  ) AS rows_outside_expected_year,

  MIN(sale_datetime)
    AS earliest_date,

  MAX(sale_datetime)
    AS latest_date

FROM combined

GROUP BY expected_year

ORDER BY expected_year;


-- ============================================================
-- Step 4: Validate final source structure
-- ============================================================
-- Source identities were reviewed privately.
--
-- The public validation reports only the number of retained source groups
-- and whether their event counts reconcile to the complete annual population.

WITH combined AS (

  SELECT
    2023 AS sale_year,
    Receipt_Number,
    sale_datetime,
    sales_source_code

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2023`

  UNION ALL

  SELECT
    2024,
    Receipt_Number,
    sale_datetime,
    sales_source_code

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2024`

  UNION ALL

  SELECT
    2025,
    Receipt_Number,
    sale_datetime,
    sales_source_code

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2025`
),

source_events AS (

  SELECT
    sale_year,
    sales_source_code,

    COUNT(
      DISTINCT CONCAT(
        Receipt_Number,
        '|',
        CAST(sale_datetime AS STRING)
      )
    ) AS transaction_events

  FROM combined

  GROUP BY
    sale_year,
    sales_source_code
),

annual_event_counts AS (

  SELECT
    sale_year,

    COUNT(
      DISTINCT CONCAT(
        Receipt_Number,
        '|',
        CAST(sale_datetime AS STRING)
      )
    ) AS annual_transaction_events

  FROM combined

  GROUP BY sale_year
)

SELECT
  sources.sale_year,

  COUNT(*) AS retained_source_groups,

  SUM(sources.transaction_events)
    AS source_level_transaction_events,

  annual.annual_transaction_events,

  SUM(sources.transaction_events)
    - annual.annual_transaction_events
    AS reconciliation_difference

FROM source_events AS sources

JOIN annual_event_counts AS annual
  USING (sale_year)

GROUP BY
  sources.sale_year,
  annual.annual_transaction_events

ORDER BY sources.sale_year;


-- ============================================================
-- Step 5: Validate annual cleaned-table schemas
-- ============================================================
-- Return only mismatches.
-- Successful validation returns zero rows.

WITH expected_schema AS (

  SELECT 1 AS ordinal_position, 'sale_datetime' AS column_name, 'DATETIME' AS data_type
  UNION ALL SELECT 2, 'Receipt_Number', 'STRING'
  UNION ALL SELECT 3, 'sales_source_code', 'STRING'
  UNION ALL SELECT 4, 'transaction_attribute', 'STRING'
  UNION ALL SELECT 5, 'quantity', 'INT64'
  UNION ALL SELECT 6, 'subtotal', 'NUMERIC'
  UNION ALL SELECT 7, 'sales_tax', 'NUMERIC'
  UNION ALL SELECT 8, 'discount', 'NUMERIC'
  UNION ALL SELECT 9, 'loyalty', 'NUMERIC'
  UNION ALL SELECT 10, 'total', 'NUMERIC'
  UNION ALL SELECT 11, 'Details', 'STRING'
  UNION ALL SELECT 12, 'Sku', 'STRING'
),

annual_tables AS (

  SELECT 2023 AS sale_year, 'sales_lines_2023' AS table_name
  UNION ALL
  SELECT 2024, 'sales_lines_2024'
  UNION ALL
  SELECT 2025, 'sales_lines_2025'
),

expected_by_year AS (

  SELECT
    tables.sale_year,
    expected.ordinal_position,
    expected.column_name,
    expected.data_type

  FROM annual_tables AS tables

  CROSS JOIN expected_schema AS expected
),

actual_schema AS (

  SELECT
    CASE table_name
      WHEN 'sales_lines_2023' THEN 2023
      WHEN 'sales_lines_2024' THEN 2024
      WHEN 'sales_lines_2025' THEN 2025
    END AS sale_year,

    ordinal_position,
    column_name,
    data_type

  FROM `retail-sales-analytics-510318.retail_sales.INFORMATION_SCHEMA.COLUMNS`

  WHERE table_name IN (
    'sales_lines_2023',
    'sales_lines_2024',
    'sales_lines_2025'
  )
)

SELECT
  COALESCE(expected.sale_year, actual.sale_year)
    AS sale_year,

  COALESCE(expected.ordinal_position, actual.ordinal_position)
    AS ordinal_position,

  expected.column_name
    AS expected_column,

  actual.column_name
    AS actual_column,

  expected.data_type
    AS expected_type,

  actual.data_type
    AS actual_type

FROM expected_by_year AS expected

FULL OUTER JOIN actual_schema AS actual
  ON expected.sale_year = actual.sale_year
 AND expected.ordinal_position = actual.ordinal_position

WHERE expected.column_name IS DISTINCT FROM actual.column_name
   OR expected.data_type IS DISTINCT FROM actual.data_type

ORDER BY
  sale_year,
  ordinal_position;


-- ============================================================
-- Findings
-- ============================================================
--
-- Final validation confirmed the cleaned annual tables contain:
--
--   2023:
--     88,627 Sale Lines
--     44,512 transaction events
--     90,960 net units
--     $8,944,625.71 net sales
--
--   2024:
--     74,872 Sale Lines
--     38,203 transaction events
--     73,587 net units
--     $7,684,400.31 net sales
--
--   2025:
--     57,492 Sale Lines
--     27,233 transaction events
--     61,097 net units
--     $5,088,845.54 net sales
--
-- 2023 and 2024 contain complete calendar-year coverage.
-- The available 2025 source ends October 29 and is therefore treated as a
-- partial year throughout later analysis.
--
-- Required analytical fields contain no missing values in any annual table.
--
-- Each year contains the expected five operational source groups, and
-- source-level event counts reconcile exactly to the complete annual
-- transaction-event population.
--
-- Private source validation confirmed that the previously identified
-- practice/test activity was absent from the final cleaned population.
--
-- Schema validation returned zero mismatches across all three annual tables.
--
-- Earlier cleaning stages established that negative quantities, zero-priced
-- records, repeated Sale Lines, and monetary extremes may represent valid
-- business activity and should not be removed automatically.
--
-- Final cleaning decision:
-- The annual Sale Line tables are structurally complete and internally
-- consistent for their available source periods and are approved to proceed
-- to privacy review and anonymization.