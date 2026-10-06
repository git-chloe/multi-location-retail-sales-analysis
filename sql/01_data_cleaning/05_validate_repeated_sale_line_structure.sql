-- DATA CLEANING 05
-- Validate Repeated Sale Line Structure

-- Purpose:
-- Determine whether Sale Lines that are identical across every retained
-- analytical field can safely be treated as accidental duplicates.
--
-- The source export does not provide a unique identifier for individual
-- Sale Line records. Matching field values therefore do not prove that
-- repeated rows are duplicate data.
--
-- Repeated-line structure is validated before considering DISTINCT or
-- row-level deduplication.


-- ============================================================
-- Step 1: Identify identical retained-field Sale Line groups
-- ============================================================
-- Only Sale Lines matching across the complete retained analytical record
-- are grouped together.

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
),

repeated_groups AS (

  SELECT
    sale_year,
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
    Sku,

    COUNT(*) AS identical_line_count

  FROM combined

  GROUP BY
    sale_year,
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

  HAVING COUNT(*) > 1
)

SELECT
  sale_year,

  COUNT(*) AS repeated_line_groups,

  SUM(identical_line_count)
    AS rows_in_repeated_groups,

  SUM(identical_line_count - 1)
    AS rows_removed_by_distinct,

  COUNT(
    DISTINCT CONCAT(
      Receipt_Number,
      '|',
      CAST(sale_datetime AS STRING)
    )
  ) AS affected_transaction_events,

  MAX(identical_line_count)
    AS max_identical_lines_in_group

FROM repeated_groups

GROUP BY sale_year

ORDER BY sale_year;


-- ============================================================
-- Step 2: Profile repeated-group sizes
-- ============================================================
-- Determine whether repeated groups are primarily pairs or include larger
-- repeated structures.

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
),

repeated_groups AS (

  SELECT
    sale_year,
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
    Sku,

    COUNT(*) AS identical_line_count

  FROM combined

  GROUP BY
    sale_year,
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

  HAVING COUNT(*) > 1
)

SELECT
  sale_year,
  identical_line_count,

  COUNT(*) AS repeated_line_groups,

  SUM(identical_line_count)
    AS rows_in_groups,

  SUM(identical_line_count - 1)
    AS rows_removed_by_distinct

FROM repeated_groups

GROUP BY
  sale_year,
  identical_line_count

ORDER BY
  sale_year,
  identical_line_count;


-- ============================================================
-- Findings
-- ============================================================
--
-- Sale Lines with identical retained analytical values occur in every
-- source year:
--
--   2023:
--     4,045 repeated-line groups
--     9,059 rows within those groups
--     5,014 rows would be removed by indiscriminate DISTINCT
--
--   2024:
--     3,890 repeated-line groups
--     8,754 rows within those groups
--     4,864 rows would be removed by indiscriminate DISTINCT
--
--   2025:
--     4,162 repeated-line groups
--     9,095 rows within those groups
--     4,933 rows would be removed by indiscriminate DISTINCT
--
-- Most repeated groups contain two matching Sale Lines, but larger groups
-- occur in all three years. Maximum observed group sizes were 20 lines in
-- 2023, 15 in 2024, and 14 in 2025.
--
-- Private review of high-frequency groups and complete transaction context
-- found repeated Sale Lines across plausible merchandise, service, credit,
-- fee, rental, and operational activity.
--
-- The source data does not provide a unique Sale Line identifier. Identical
-- retained values therefore cannot distinguish an accidental duplicated row
-- from two legitimate Sale Lines recorded separately within the same event.
--
-- This is distinct from confirmed duplicate transaction-header metadata.
-- Metadata-level duplication can be collapsed when independently validated;
-- that does not justify deduplicating product-level Sale Lines.
--
-- Cleaning decision:
-- Retain repeated Sale Lines.
--
-- Do not apply DISTINCT or row-level deduplication solely because retained
-- analytical field values match.