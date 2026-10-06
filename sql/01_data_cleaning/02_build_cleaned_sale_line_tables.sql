-- DATA CLEANING 02
-- Build Cleaned Sale Line Tables

-- Purpose:
-- Build one cleaned product-level analytical table for each source year,
-- using the transaction-event rules established in DATA CLEANING 01.
--
-- Each output row represents one product-level Sale Line.
--
-- Cleaning rules:
--   1. Keep product-level Sale Line records only.
--   2. Join transaction metadata using Receipt_Number + Date.
--   3. Collapse repeated Sale headers at the transaction-metadata level.
--   4. Exclude events containing no valid Sale header after removing
--      SAVED / parked and VOIDED / voided activity.
--   5. Retain valid completed and pending-fulfillment transactions.
--   6. Preserve transaction source metadata as sales_source_code.
--   7. Preserve populated transaction Attributes as transaction_attribute.
--   8. Convert Date, Quantity, and monetary fields to analytical data types.
--   9. Retain Details and Sku for later product-level review.
--
-- One source year also contained identified non-production practice/test
-- activity. That activity was excluded during cleaned-table construction.
--
-- Raw proprietary data is not included in the public repository.


-- ============================================================
-- 2023 cleaned Sale Line table
-- ============================================================
-- 2023 contains a small amount of identified non-production source activity.
--
-- The public repository does not expose the original internal source code;
-- <PRACTICE_TEST_SOURCE> represents that privately identified source.

CREATE OR REPLACE TABLE
  `retail-sales-analytics-510318.retail_sales.sales_lines_2023` AS

WITH sale_metadata AS (

  SELECT
    Receipt_Number,
    Date,

    MAX(
      REGEXP_EXTRACT(
        UPPER(NULLIF(TRIM(Register), '')),
        r'^[A-Z]+'
      )
    ) AS sales_source_code,

    MAX(
      NULLIF(TRIM(Attributes), '')
    ) AS transaction_attribute,

    COUNTIF(
      NOT (
        (Status = 'VOIDED' AND State = 'voided')
        OR
        (Status = 'SAVED' AND State = 'parked')
      )
    ) AS valid_sale_headers

  FROM `retail-sales-analytics-510318.retail_sales.raw_sales_2023`

  WHERE Line_Type = 'Sale'

  GROUP BY
    Receipt_Number,
    Date
),

retained_transactions AS (

  SELECT
    Receipt_Number,
    Date,
    sales_source_code,
    transaction_attribute

  FROM sale_metadata

  WHERE valid_sale_headers > 0

    -- Public placeholder for the privately identified practice/test source.
    AND sales_source_code != '<PRACTICE_TEST_SOURCE>'
)

SELECT
  PARSE_DATETIME(
    '%m/%d/%Y %H:%M:%S',
    raw.Date
  ) AS sale_datetime,

  raw.Receipt_Number,

  meta.sales_source_code,

  meta.transaction_attribute,

  SAFE_CAST(raw.Quantity AS INT64)
    AS quantity,

  SAFE_CAST(
    REPLACE(REPLACE(raw.Subtotal, '$', ''), ',', '')
    AS NUMERIC
  ) AS subtotal,

  SAFE_CAST(
    REPLACE(REPLACE(raw.Sales_Tax, '$', ''), ',', '')
    AS NUMERIC
  ) AS sales_tax,

  SAFE_CAST(
    REPLACE(REPLACE(raw.Discount, '$', ''), ',', '')
    AS NUMERIC
  ) AS discount,

  SAFE_CAST(
    REPLACE(REPLACE(raw.Loyalty, '$', ''), ',', '')
    AS NUMERIC
  ) AS loyalty,

  SAFE_CAST(
    REPLACE(REPLACE(raw.Total, '$', ''), ',', '')
    AS NUMERIC
  ) AS total,

  raw.Details,
  raw.Sku

FROM `retail-sales-analytics-510318.retail_sales.raw_sales_2023` AS raw

JOIN retained_transactions AS meta
  ON raw.Receipt_Number = meta.Receipt_Number
 AND raw.Date = meta.Date

WHERE raw.Line_Type = 'Sale Line';


-- ============================================================
-- 2024 cleaned Sale Line table
-- ============================================================

CREATE OR REPLACE TABLE
  `retail-sales-analytics-510318.retail_sales.sales_lines_2024` AS

WITH sale_metadata AS (

  SELECT
    Receipt_Number,
    Date,

    MAX(
      REGEXP_EXTRACT(
        UPPER(NULLIF(TRIM(Register), '')),
        r'^[A-Z]+'
      )
    ) AS sales_source_code,

    MAX(
      NULLIF(TRIM(Attributes), '')
    ) AS transaction_attribute,

    COUNTIF(
      NOT (
        (Status = 'VOIDED' AND State = 'voided')
        OR
        (Status = 'SAVED' AND State = 'parked')
      )
    ) AS valid_sale_headers

  FROM `retail-sales-analytics-510318.retail_sales.raw_sales_2024`

  WHERE Line_Type = 'Sale'

  GROUP BY
    Receipt_Number,
    Date
),

retained_transactions AS (

  SELECT
    Receipt_Number,
    Date,
    sales_source_code,
    transaction_attribute

  FROM sale_metadata

  WHERE valid_sale_headers > 0
)

SELECT
  PARSE_DATETIME(
    '%m/%d/%Y %H:%M:%S',
    raw.Date
  ) AS sale_datetime,

  raw.Receipt_Number,

  meta.sales_source_code,

  meta.transaction_attribute,

  SAFE_CAST(raw.Quantity AS INT64)
    AS quantity,

  SAFE_CAST(
    REPLACE(REPLACE(raw.Subtotal, '$', ''), ',', '')
    AS NUMERIC
  ) AS subtotal,

  SAFE_CAST(
    REPLACE(REPLACE(raw.Sales_Tax, '$', ''), ',', '')
    AS NUMERIC
  ) AS sales_tax,

  SAFE_CAST(
    REPLACE(REPLACE(raw.Discount, '$', ''), ',', '')
    AS NUMERIC
  ) AS discount,

  SAFE_CAST(
    REPLACE(REPLACE(raw.Loyalty, '$', ''), ',', '')
    AS NUMERIC
  ) AS loyalty,

  SAFE_CAST(
    REPLACE(REPLACE(raw.Total, '$', ''), ',', '')
    AS NUMERIC
  ) AS total,

  raw.Details,
  raw.Sku

FROM `retail-sales-analytics-510318.retail_sales.raw_sales_2024` AS raw

JOIN retained_transactions AS meta
  ON raw.Receipt_Number = meta.Receipt_Number
 AND raw.Date = meta.Date

WHERE raw.Line_Type = 'Sale Line';


-- ============================================================
-- 2025 cleaned Sale Line table
-- ============================================================
-- DATA CLEANING 01 identified repeated exact Sale headers in 2025.
--
-- Grouping Sale metadata by Receipt_Number + Date reduces those duplicate
-- headers to one transaction-level metadata record before joining to
-- product-level Sale Lines.
--
-- Product-level Sale Line records are not deduplicated.

CREATE OR REPLACE TABLE
  `retail-sales-analytics-510318.retail_sales.sales_lines_2025` AS

WITH sale_metadata AS (

  SELECT
    Receipt_Number,
    Date,

    MAX(
      REGEXP_EXTRACT(
        UPPER(NULLIF(TRIM(Register), '')),
        r'^[A-Z]+'
      )
    ) AS sales_source_code,

    MAX(
      NULLIF(TRIM(Attributes), '')
    ) AS transaction_attribute,

    COUNTIF(
      NOT (
        (Status = 'VOIDED' AND State = 'voided')
        OR
        (Status = 'SAVED' AND State = 'parked')
      )
    ) AS valid_sale_headers

  FROM `retail-sales-analytics-510318.retail_sales.raw_sales_2025`

  WHERE Line_Type = 'Sale'

  GROUP BY
    Receipt_Number,
    Date
),

retained_transactions AS (

  SELECT
    Receipt_Number,
    Date,
    sales_source_code,
    transaction_attribute

  FROM sale_metadata

  WHERE valid_sale_headers > 0
)

SELECT
  PARSE_DATETIME(
    '%m/%d/%Y %H:%M:%S',
    raw.Date
  ) AS sale_datetime,

  raw.Receipt_Number,

  meta.sales_source_code,

  meta.transaction_attribute,

  SAFE_CAST(raw.Quantity AS INT64)
    AS quantity,

  SAFE_CAST(
    REPLACE(REPLACE(raw.Subtotal, '$', ''), ',', '')
    AS NUMERIC
  ) AS subtotal,

  SAFE_CAST(
    REPLACE(REPLACE(raw.Sales_Tax, '$', ''), ',', '')
    AS NUMERIC
  ) AS sales_tax,

  SAFE_CAST(
    REPLACE(REPLACE(raw.Discount, '$', ''), ',', '')
    AS NUMERIC
  ) AS discount,

  SAFE_CAST(
    REPLACE(REPLACE(raw.Loyalty, '$', ''), ',', '')
    AS NUMERIC
  ) AS loyalty,

  SAFE_CAST(
    REPLACE(REPLACE(raw.Total, '$', ''), ',', '')
    AS NUMERIC
  ) AS total,

  raw.Details,
  raw.Sku

FROM `retail-sales-analytics-510318.retail_sales.raw_sales_2025` AS raw

JOIN retained_transactions AS meta
  ON raw.Receipt_Number = meta.Receipt_Number
 AND raw.Date = meta.Date

WHERE raw.Line_Type = 'Sale Line';


-- ============================================================
-- Step 4: Validate cleaned Sale Line tables
-- ============================================================
-- Confirm transaction coverage, required metadata, successful type conversion,
-- and the available date range for each cleaned source year.

WITH validation AS (

  SELECT
    2023 AS sale_year,

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

    COUNTIF(sale_datetime IS NULL)
      AS missing_dates,

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

    COUNTIF(Sku IS NULL)
      AS missing_sku,

    COUNTIF(Details IS NULL)
      AS missing_details,

    COUNTIF(transaction_attribute IS NOT NULL)
      AS rows_with_transaction_attribute

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2023`


  UNION ALL


  SELECT
    2024,

    COUNT(*),

    COUNT(DISTINCT Receipt_Number),

    COUNT(
      DISTINCT CONCAT(
        Receipt_Number,
        '|',
        CAST(sale_datetime AS STRING)
      )
    ),

    MIN(sale_datetime),
    MAX(sale_datetime),

    COUNTIF(sale_datetime IS NULL),
    COUNTIF(sales_source_code IS NULL),
    COUNTIF(quantity IS NULL),
    COUNTIF(subtotal IS NULL),
    COUNTIF(sales_tax IS NULL),
    COUNTIF(discount IS NULL),
    COUNTIF(loyalty IS NULL),
    COUNTIF(total IS NULL),
    COUNTIF(Sku IS NULL),
    COUNTIF(Details IS NULL),
    COUNTIF(transaction_attribute IS NOT NULL)

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2024`


  UNION ALL


  SELECT
    2025,

    COUNT(*),

    COUNT(DISTINCT Receipt_Number),

    COUNT(
      DISTINCT CONCAT(
        Receipt_Number,
        '|',
        CAST(sale_datetime AS STRING)
      )
    ),

    MIN(sale_datetime),
    MAX(sale_datetime),

    COUNTIF(sale_datetime IS NULL),
    COUNTIF(sales_source_code IS NULL),
    COUNTIF(quantity IS NULL),
    COUNTIF(subtotal IS NULL),
    COUNTIF(sales_tax IS NULL),
    COUNTIF(discount IS NULL),
    COUNTIF(loyalty IS NULL),
    COUNTIF(total IS NULL),
    COUNTIF(Sku IS NULL),
    COUNTIF(Details IS NULL),
    COUNTIF(transaction_attribute IS NOT NULL)

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2025`
)

SELECT *

FROM validation

ORDER BY sale_year;


-- ============================================================
-- Step 5: Reconcile cleaned analytical totals
-- ============================================================
-- Record final row, transaction, quantity, and monetary totals after
-- transaction-event exclusions and type conversion.

SELECT
  2023 AS sale_year,

  COUNT(*) AS total_rows,

  COUNT(
    DISTINCT CONCAT(
      Receipt_Number,
      '|',
      CAST(sale_datetime AS STRING)
    )
  ) AS transaction_events,

  SUM(quantity) AS net_units,
  SUM(subtotal) AS net_subtotal,
  SUM(sales_tax) AS net_sales_tax,
  SUM(discount) AS net_discount,
  SUM(loyalty) AS net_loyalty,
  SUM(total) AS net_sales

FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2023`


UNION ALL


SELECT
  2024,

  COUNT(*),

  COUNT(
    DISTINCT CONCAT(
      Receipt_Number,
      '|',
      CAST(sale_datetime AS STRING)
    )
  ),

  SUM(quantity),
  SUM(subtotal),
  SUM(sales_tax),
  SUM(discount),
  SUM(loyalty),
  SUM(total)

FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2024`


UNION ALL


SELECT
  2025,

  COUNT(*),

  COUNT(
    DISTINCT CONCAT(
      Receipt_Number,
      '|',
      CAST(sale_datetime AS STRING)
    )
  ),

  SUM(quantity),
  SUM(subtotal),
  SUM(sales_tax),
  SUM(discount),
  SUM(loyalty),
  SUM(total)

FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2025`

ORDER BY sale_year;


-- ============================================================
-- Findings
-- ============================================================
--
-- Cleaned product-level Sale Line tables were successfully created for all
-- three source years using Receipt_Number + Date as the transaction-event key.
--
-- Final cleaned tables contain:
--
--   2023:
--     88,627 Sale Line rows
--     44,512 transaction events
--
--   2024:
--     74,872 Sale Line rows
--     38,203 transaction events
--
--   2025:
--     57,492 Sale Line rows
--     27,233 transaction events
--
-- 2023 and 2024 cover complete calendar years.
-- The available 2025 source data ends October 29 and is therefore treated as
-- a partial year in later comparative analysis.
--
-- Transaction metadata is joined using Receipt_Number + Date rather than
-- Receipt_Number alone, preventing reused receipt identifiers from causing
-- unrelated transaction events to inherit incorrect source or status metadata.
--
-- This correction was materially important in 2024: transaction-event-level
-- exclusion logic restored 98 legitimate Sale Line records that had been
-- removed under an earlier receipt-level exclusion approach because another
-- event reused the same Receipt_Number.
--
-- Repeated Sale headers are collapsed only at the transaction-metadata layer.
-- Product-level Sale Line records are not deduplicated without independent
-- evidence that they are duplicates.
--
-- SAVED / parked and VOIDED / voided events are removed at the complete
-- transaction-event level. Valid pending-fulfillment activity remains included.
--
-- A privately identified non-production practice/test source present in one
-- source year was excluded from cleaned analytical data.
--
-- All retained Sale Lines successfully received transaction source metadata,
-- and analytical numeric/date fields were converted without introducing
-- missing values.
--
-- Final analytical totals:
--
--   2023:
--     Net units:      90,960
--     Net subtotal:   $7,922,392.23
--     Net sales tax:  $1,022,233.92
--     Net discount:   $568,878.56
--     Net loyalty:    $81,058.11
--     Net sales:      $8,944,625.71
--
--   2024:
--     Net units:      73,587
--     Net subtotal:   $6,801,993.27
--     Net sales tax:  $882,411.04
--     Net discount:   $795,712.33
--     Net loyalty:    $66,089.68
--     Net sales:      $7,684,400.31
--
--   2025:
--     Net units:      61,097
--     Net subtotal:   $4,502,186.78
--     Net sales tax:  $586,661.56
--     Net discount:   $765,125.27
--     Net loyalty:    $31,304.44
--     Net sales:      $5,088,845.54
--
-- These cleaned private tables form the product-level foundation for
-- subsequent data-quality review, privacy transformation, anonymization,
-- portfolio-table creation, and analysis.