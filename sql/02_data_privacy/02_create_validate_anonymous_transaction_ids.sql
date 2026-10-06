-- DATA PRIVACY 02
-- Create and Validate Anonymous Transaction Identifiers

-- Purpose:
-- Replace original operational receipt identifiers with anonymous transaction
-- IDs while preserving transaction-event and Sale Line relationships.
--
-- Earlier grain validation established that an original receipt identifier
-- alone is not universally unique. Transaction events are therefore defined
-- by the composite private key:
--
--   Receipt_Number + sale_datetime
--
-- Original receipt values remain private and are not included in the
-- public-facing analytical tables.
--
-- Anonymous IDs restart within each annual table. Cross-year analysis should
-- therefore use:
--
--   sale_year + transaction_id


-- ============================================================
-- Step 1: Generate annual anonymous transaction mappings
-- ============================================================
-- IDs are ordered primarily by sale_datetime rather than the original receipt
-- identifier so that the anonymous sequence does not primarily follow private
-- operational receipt-prefix structure.

WITH combined_events AS (

  SELECT DISTINCT
    2023 AS sale_year,
    Receipt_Number,
    sale_datetime

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2023`

  UNION ALL

  SELECT DISTINCT
    2024,
    Receipt_Number,
    sale_datetime

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2024`

  UNION ALL

  SELECT DISTINCT
    2025,
    Receipt_Number,
    sale_datetime

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2025`
),

transaction_mapping AS (

  SELECT
    sale_year,
    Receipt_Number,
    sale_datetime,

    CONCAT(
      'TXN_',
      LPAD(
        CAST(
          ROW_NUMBER() OVER (
            PARTITION BY sale_year
            ORDER BY
              sale_datetime,
              Receipt_Number
          ) AS STRING
        ),
        6,
        '0'
      )
    ) AS transaction_id

  FROM combined_events
)

SELECT
  sale_year,

  COUNT(*) AS transaction_events,

  COUNT(DISTINCT transaction_id)
    AS unique_transaction_ids,

  COUNT(*) - COUNT(DISTINCT transaction_id)
    AS id_collisions,

  COUNTIF(transaction_id IS NULL)
    AS missing_transaction_ids

FROM transaction_mapping

GROUP BY sale_year

ORDER BY sale_year;


-- ============================================================
-- Step 2: Validate complete Sale Line coverage
-- ============================================================
-- Every Sale Line must receive a transaction_id, and the number of transaction
-- events must remain unchanged.

WITH combined_sales AS (

  SELECT
    2023 AS sale_year,
    *

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2023`

  UNION ALL

  SELECT
    2024 AS sale_year,
    *

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2024`

  UNION ALL

  SELECT
    2025 AS sale_year,
    *

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2025`
),

transaction_mapping AS (

  SELECT
    sale_year,
    Receipt_Number,
    sale_datetime,

    CONCAT(
      'TXN_',
      LPAD(
        CAST(
          ROW_NUMBER() OVER (
            PARTITION BY sale_year
            ORDER BY
              sale_datetime,
              Receipt_Number
          ) AS STRING
        ),
        6,
        '0'
      )
    ) AS transaction_id

  FROM (

    SELECT DISTINCT
      sale_year,
      Receipt_Number,
      sale_datetime

    FROM combined_sales
  )
),

mapped_sale_lines AS (

  SELECT
    sales.sale_year,
    sales.Receipt_Number,
    sales.sale_datetime,
    mapping.transaction_id

  FROM combined_sales AS sales

  LEFT JOIN transaction_mapping AS mapping
    ON sales.sale_year = mapping.sale_year
   AND sales.Receipt_Number = mapping.Receipt_Number
   AND sales.sale_datetime = mapping.sale_datetime
)

SELECT
  sale_year,

  COUNT(*) AS original_sale_lines,

  COUNTIF(transaction_id IS NOT NULL)
    AS mapped_sale_lines,

  COUNTIF(transaction_id IS NULL)
    AS unmapped_sale_lines,

  COUNT(
    DISTINCT CONCAT(
      Receipt_Number,
      '|',
      CAST(sale_datetime AS STRING)
    )
  ) AS original_transaction_events,

  COUNT(DISTINCT transaction_id)
    AS anonymized_transaction_events

FROM mapped_sale_lines

GROUP BY sale_year

ORDER BY sale_year;


-- ============================================================
-- Step 3: Validate Sale Line membership by transaction
-- ============================================================
-- The number of product-level Sale Lines within each transaction event should
-- remain unchanged after replacing the private event key with transaction_id.

WITH combined_sales AS (

  SELECT
    2023 AS sale_year,
    Receipt_Number,
    sale_datetime

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2023`

  UNION ALL

  SELECT
    2024,
    Receipt_Number,
    sale_datetime

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2024`

  UNION ALL

  SELECT
    2025,
    Receipt_Number,
    sale_datetime

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2025`
),

transaction_mapping AS (

  SELECT
    sale_year,
    Receipt_Number,
    sale_datetime,

    CONCAT(
      'TXN_',
      LPAD(
        CAST(
          ROW_NUMBER() OVER (
            PARTITION BY sale_year
            ORDER BY
              sale_datetime,
              Receipt_Number
          ) AS STRING
        ),
        6,
        '0'
      )
    ) AS transaction_id

  FROM (

    SELECT DISTINCT
      sale_year,
      Receipt_Number,
      sale_datetime

    FROM combined_sales
  )
),

original_event_counts AS (

  SELECT
    sale_year,
    Receipt_Number,
    sale_datetime,
    COUNT(*) AS original_sale_lines

  FROM combined_sales

  GROUP BY
    sale_year,
    Receipt_Number,
    sale_datetime
),

anonymized_event_counts AS (

  SELECT
    sales.sale_year,
    mapping.transaction_id,
    COUNT(*) AS anonymized_sale_lines

  FROM combined_sales AS sales

  JOIN transaction_mapping AS mapping
    ON sales.sale_year = mapping.sale_year
   AND sales.Receipt_Number = mapping.Receipt_Number
   AND sales.sale_datetime = mapping.sale_datetime

  GROUP BY
    sales.sale_year,
    mapping.transaction_id
)

SELECT
  original.sale_year,

  COUNT(*) AS transaction_events_checked,

  COUNTIF(
    original.original_sale_lines != anonymized.anonymized_sale_lines
  ) AS line_count_mismatches

FROM original_event_counts AS original

JOIN transaction_mapping AS mapping
  ON original.sale_year = mapping.sale_year
 AND original.Receipt_Number = mapping.Receipt_Number
 AND original.sale_datetime = mapping.sale_datetime

JOIN anonymized_event_counts AS anonymized
  ON mapping.sale_year = anonymized.sale_year
 AND mapping.transaction_id = anonymized.transaction_id

GROUP BY original.sale_year

ORDER BY original.sale_year;


-- ============================================================
-- Step 4: Validate reused original identifiers
-- ============================================================
-- Original receipt identifiers reused across multiple transaction datetimes
-- must still map to separate anonymous events.
--
-- Only aggregate validation is returned publicly; original receipt values
-- are intentionally not displayed.

WITH combined_events AS (

  SELECT DISTINCT
    2023 AS sale_year,
    Receipt_Number,
    sale_datetime

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2023`

  UNION ALL

  SELECT DISTINCT
    2024,
    Receipt_Number,
    sale_datetime

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2024`

  UNION ALL

  SELECT DISTINCT
    2025,
    Receipt_Number,
    sale_datetime

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2025`
),

transaction_mapping AS (

  SELECT
    sale_year,
    Receipt_Number,
    sale_datetime,

    CONCAT(
      'TXN_',
      LPAD(
        CAST(
          ROW_NUMBER() OVER (
            PARTITION BY sale_year
            ORDER BY
              sale_datetime,
              Receipt_Number
          ) AS STRING
        ),
        6,
        '0'
      )
    ) AS transaction_id

  FROM combined_events
),

reused_receipts AS (

  SELECT
    sale_year,
    Receipt_Number,

    COUNT(*) AS transaction_events,

    COUNT(DISTINCT transaction_id)
      AS anonymous_transaction_ids

  FROM transaction_mapping

  GROUP BY
    sale_year,
    Receipt_Number

  HAVING COUNT(*) > 1
)

SELECT
  sale_year,

  COUNT(*) AS reused_original_identifiers,

  SUM(transaction_events)
    AS transaction_events_using_reused_identifiers,

  COUNTIF(
    transaction_events != anonymous_transaction_ids
  ) AS mapping_mismatches

FROM reused_receipts

GROUP BY sale_year

ORDER BY sale_year;


-- ============================================================
-- Findings
-- ============================================================
--
-- Original receipt identifiers were not suitable for publication because
-- they contain operational coding and are not universally unique.
--
-- Anonymous transaction IDs were therefore generated from the validated
-- private transaction-event key:
--
--   Receipt_Number + sale_datetime
--
-- Every transaction event received exactly one anonymous ID with:
--   - 0 ID collisions
--   - 0 missing IDs
--   - 0 unmapped Sale Lines
--   - 0 transaction-level Sale Line-count mismatches
--
-- Original receipt identifiers reused across multiple datetimes remained
-- correctly separated as independent anonymous transaction events.
--
-- The transformation therefore preserves transaction relationships without
-- exposing original operational receipt information.
--
-- transaction_id values restart within each annual table by design.
--
-- For combined cross-year analysis, the public transaction key is:
--
--   sale_year + transaction_id
--
-- Privacy decision:
-- Original receipt identifiers remain private and are replaced by anonymous
-- transaction IDs in the public-facing portfolio tables.