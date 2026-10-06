-- DATA CLEANING 01
-- Transaction Grain & Source Metadata

-- Purpose:
-- Establish the correct transaction-event grain before building cleaned
-- product-level Sale Line tables.
--
-- The same validation framework is applied across 2023, 2024, and 2025 to:
--   1. Test whether Receipt_Number uniquely identifies a transaction.
--   2. Validate Receipt_Number + Date as the transaction-event key.
--   3. Confirm that Sale-level source metadata is unambiguous within an event.
--   4. Confirm whether populated transaction Attributes can be retained.
--   5. Review repeated Sale headers before joining metadata to Sale Lines.
--   6. Review pending fulfillment transactions before defining exclusions.
--
-- Raw proprietary data is not included in the public repository.


-- ============================================================
-- Step 1: Compare receipt identifiers with transaction events
-- ============================================================
-- Receipt numbers may be reused across separate events.
-- Compare receipt-level uniqueness with Receipt_Number + Date event counts
-- before using Receipt_Number as a transaction key.

WITH combined_sales AS (

  SELECT
    2023 AS sale_year,
    Receipt_Number,
    Date

  FROM `retail-sales-analytics-510318.retail_sales.raw_sales_2023`

  WHERE Line_Type = 'Sale'


  UNION ALL


  SELECT
    2024 AS sale_year,
    Receipt_Number,
    Date

  FROM `retail-sales-analytics-510318.retail_sales.raw_sales_2024`

  WHERE Line_Type = 'Sale'


  UNION ALL


  SELECT
    2025 AS sale_year,
    Receipt_Number,
    Date

  FROM `retail-sales-analytics-510318.retail_sales.raw_sales_2025`

  WHERE Line_Type = 'Sale'
)

SELECT
  sale_year,

  COUNT(DISTINCT Receipt_Number)
    AS distinct_receipt_numbers,

  COUNT(
    DISTINCT CONCAT(
      Receipt_Number,
      '|',
      Date
    )
  ) AS transaction_events,

  COUNT(*) AS sale_rows

FROM combined_sales

GROUP BY sale_year

ORDER BY sale_year;


-- ============================================================
-- Step 2: Validate transaction-event source and Attribute metadata
-- ============================================================
-- Test whether each Receipt_Number + Date event maps to a single source
-- prefix and at most one populated transaction Attribute.
--
-- Only the source prefix is analytically required; individual register
-- identifiers are not retained.

WITH combined_sales AS (

  SELECT
    2023 AS sale_year,
    Receipt_Number,
    Date,
    Register,
    Attributes

  FROM `retail-sales-analytics-510318.retail_sales.raw_sales_2023`

  WHERE Line_Type = 'Sale'


  UNION ALL


  SELECT
    2024 AS sale_year,
    Receipt_Number,
    Date,
    Register,
    Attributes

  FROM `retail-sales-analytics-510318.retail_sales.raw_sales_2024`

  WHERE Line_Type = 'Sale'


  UNION ALL


  SELECT
    2025 AS sale_year,
    Receipt_Number,
    Date,
    Register,
    Attributes

  FROM `retail-sales-analytics-510318.retail_sales.raw_sales_2025`

  WHERE Line_Type = 'Sale'
),

transaction_events AS (

  SELECT
    sale_year,
    Receipt_Number,
    Date,

    COUNT(*) AS sale_headers,

    COUNT(
      DISTINCT REGEXP_EXTRACT(
        UPPER(NULLIF(TRIM(Register), '')),
        r'^[A-Z]+'
      )
    ) AS distinct_sources,

    COUNT(
      DISTINCT NULLIF(TRIM(Attributes), '')
    ) AS distinct_attributes

  FROM combined_sales

  GROUP BY
    sale_year,
    Receipt_Number,
    Date
)

SELECT
  sale_year,

  COUNT(*) AS transaction_events,

  COUNTIF(distinct_sources = 0)
    AS events_missing_source,

  COUNTIF(distinct_sources > 1)
    AS events_with_multiple_sources,

  COUNTIF(distinct_attributes > 1)
    AS events_with_multiple_attributes,

  COUNTIF(sale_headers > 1)
    AS events_with_multiple_sale_headers

FROM transaction_events

GROUP BY sale_year

ORDER BY sale_year;


-- ============================================================
-- Step 3: Review repeated Sale headers
-- ============================================================
-- Repeated Sale headers are evaluated at the metadata layer before any
-- deduplication decision is made.
--
-- This is important because duplicate transaction headers do not, by
-- themselves, imply that product-level Sale Line records are duplicated.

WITH combined_sales AS (

  SELECT
    2023 AS sale_year,
    Receipt_Number,
    Date,
    Register,
    Quantity,
    Subtotal,
    Sales_Tax,
    Discount,
    Loyalty,
    Total,
    Details,
    Status,
    State,
    Attributes

  FROM `retail-sales-analytics-510318.retail_sales.raw_sales_2023`

  WHERE Line_Type = 'Sale'


  UNION ALL


  SELECT
    2024 AS sale_year,
    Receipt_Number,
    Date,
    Register,
    Quantity,
    Subtotal,
    Sales_Tax,
    Discount,
    Loyalty,
    Total,
    Details,
    Status,
    State,
    Attributes

  FROM `retail-sales-analytics-510318.retail_sales.raw_sales_2024`

  WHERE Line_Type = 'Sale'


  UNION ALL


  SELECT
    2025 AS sale_year,
    Receipt_Number,
    Date,
    Register,
    Quantity,
    Subtotal,
    Sales_Tax,
    Discount,
    Loyalty,
    Total,
    Details,
    Status,
    State,
    Attributes

  FROM `retail-sales-analytics-510318.retail_sales.raw_sales_2025`

  WHERE Line_Type = 'Sale'
),

repeated_events AS (

  SELECT
    sale_year,
    Receipt_Number,
    Date

  FROM combined_sales

  GROUP BY
    sale_year,
    Receipt_Number,
    Date

  HAVING COUNT(*) > 1
),

event_comparison AS (

  SELECT
    s.sale_year,
    s.Receipt_Number,
    s.Date,

    COUNT(*) AS sale_headers,

    COUNT(
      DISTINCT TO_JSON_STRING(
        STRUCT(
          s.Register,
          s.Quantity,
          s.Subtotal,
          s.Sales_Tax,
          s.Discount,
          s.Loyalty,
          s.Total,
          s.Details,
          s.Status,
          s.State,
          s.Attributes
        )
      )
    ) AS distinct_header_versions

  FROM combined_sales AS s

  JOIN repeated_events AS r
    ON s.sale_year = r.sale_year
   AND s.Receipt_Number = r.Receipt_Number
   AND s.Date = r.Date

  GROUP BY
    s.sale_year,
    s.Receipt_Number,
    s.Date
)

SELECT
  sale_year,

  COUNT(*) AS repeated_sale_events,

  COUNTIF(distinct_header_versions = 1)
    AS exact_duplicate_events,

  COUNTIF(distinct_header_versions > 1)
    AS events_with_different_headers

FROM event_comparison

GROUP BY sale_year

ORDER BY sale_year;


-- ============================================================
-- Step 4: Audit transaction-level metadata fields
-- ============================================================
-- Review the completeness and variation of metadata fields that may be
-- useful when constructing the cleaned Sale Line tables.

WITH combined_sales AS (

  SELECT
    2023 AS sale_year,
    Register,
    Status,
    State,
    Attributes

  FROM `retail-sales-analytics-510318.retail_sales.raw_sales_2023`

  WHERE Line_Type = 'Sale'


  UNION ALL


  SELECT
    2024 AS sale_year,
    Register,
    Status,
    State,
    Attributes

  FROM `retail-sales-analytics-510318.retail_sales.raw_sales_2024`

  WHERE Line_Type = 'Sale'


  UNION ALL


  SELECT
    2025 AS sale_year,
    Register,
    Status,
    State,
    Attributes

  FROM `retail-sales-analytics-510318.retail_sales.raw_sales_2025`

  WHERE Line_Type = 'Sale'
),

metadata_audit AS (

  SELECT
    sale_year,
    'Register / Source' AS field,
    COUNT(*) AS sale_rows,
    COUNTIF(Register IS NULL OR TRIM(Register) = '')
      AS null_or_blank,
    COUNT(DISTINCT Register)
      AS distinct_values

  FROM combined_sales

  GROUP BY sale_year


  UNION ALL


  SELECT
    sale_year,
    'Status',
    COUNT(*),
    COUNTIF(Status IS NULL OR TRIM(Status) = ''),
    COUNT(DISTINCT Status)

  FROM combined_sales

  GROUP BY sale_year


  UNION ALL


  SELECT
    sale_year,
    'State',
    COUNT(*),
    COUNTIF(State IS NULL OR TRIM(State) = ''),
    COUNT(DISTINCT State)

  FROM combined_sales

  GROUP BY sale_year


  UNION ALL


  SELECT
    sale_year,
    'Attributes',
    COUNT(*),
    COUNTIF(Attributes IS NULL OR TRIM(Attributes) = ''),
    COUNT(DISTINCT Attributes)

  FROM combined_sales

  GROUP BY sale_year
)

SELECT
  *

FROM metadata_audit

ORDER BY
  sale_year,
  field;


-- ============================================================
-- Step 5: Audit pending fulfillment transactions
-- ============================================================
-- Pending fulfillment does not necessarily mean an unpaid or invalid sale.
--
-- Sale events are therefore compared with Payment records before deciding
-- whether awaiting-pickup or awaiting-dispatch transactions should be removed.
--
-- Sale metadata is first collapsed to one Receipt_Number + Date event so
-- repeated Sale headers do not inflate pending-event counts.

WITH combined_raw AS (

  SELECT
    2023 AS sale_year,
    *

  FROM `retail-sales-analytics-510318.retail_sales.raw_sales_2023`


  UNION ALL


  SELECT
    2024 AS sale_year,
    *

  FROM `retail-sales-analytics-510318.retail_sales.raw_sales_2024`


  UNION ALL


  SELECT
    2025 AS sale_year,
    *

  FROM `retail-sales-analytics-510318.retail_sales.raw_sales_2025`
),

sale_events AS (

  SELECT
    sale_year,
    Receipt_Number,
    Date,

    MAX(Status) AS Status,
    MAX(State) AS State,
    MAX(NULLIF(TRIM(Attributes), '')) AS Attributes

  FROM combined_raw

  WHERE Line_Type = 'Sale'

  GROUP BY
    sale_year,
    Receipt_Number,
    Date
),

payment_events AS (

  SELECT
    sale_year,
    Receipt_Number,
    Date,

    COUNT(*) AS payment_rows,

    SUM(
      SAFE_CAST(
        REPLACE(
          REPLACE(Paid, '$', ''),
          ',',
          ''
        )
        AS NUMERIC
      )
    ) AS payment_total

  FROM combined_raw

  WHERE Line_Type = 'Payment'

  GROUP BY
    sale_year,
    Receipt_Number,
    Date
),

pending_events AS (

  SELECT
    s.sale_year,
    s.Receipt_Number,
    s.Date,
    s.Status,
    s.State,
    s.Attributes,

    COALESCE(p.payment_rows, 0)
      AS payment_rows,

    COALESCE(p.payment_total, 0)
      AS payment_total

  FROM sale_events AS s

  LEFT JOIN payment_events AS p
    ON s.sale_year = p.sale_year
   AND s.Receipt_Number = p.Receipt_Number
   AND s.Date = p.Date

  WHERE s.Status IN (
    'AWAITING_PICKUP',
    'AWAITING_DISPATCH'
  )
     OR s.State = 'pending'
)

SELECT
  sale_year,
  Status,
  State,
  Attributes,

  COUNT(*) AS pending_transaction_events,

  COUNTIF(payment_rows > 0)
    AS events_with_payment,

  COUNTIF(payment_rows = 0)
    AS events_without_payment,

  ROUND(SUM(payment_total), 2)
    AS total_payment_amount

FROM pending_events

GROUP BY
  sale_year,
  Status,
  State,
  Attributes

ORDER BY
  sale_year,
  pending_transaction_events DESC;


-- ============================================================
-- Findings
-- ============================================================
--
-- Receipt_Number is not a universally unique transaction identifier across
-- the source data. Some receipt identifiers are reused across transaction
-- events occurring at different datetimes.
--
-- Receipt_Number + Date was therefore adopted as the transaction-event key
-- for joining Sale-level metadata to product-level Sale Line records.
--
-- Within this composite key:
--   - transaction source metadata mapped consistently to a single source
--   - populated transaction Attributes did not conflict within an event
--
-- The Sale-level Register field contains more detail than required for the
-- analysis. Only its source component is retained as sales_source_code.
--
-- Populated transaction Attributes are retained as transaction_attribute.
--
-- Repeated Sale headers were reviewed rather than automatically removed.
-- The most substantial duplication occurred in 2025, where repeated Sale
-- headers were confirmed to be exact duplicates at the metadata layer.
-- These headers can therefore be collapsed to one transaction-level metadata
-- record without assuming that product-level Sale Line records are duplicated.
--
-- Pending fulfillment transactions were also reviewed before exclusion rules
-- were defined. Payment records showed that awaiting-pickup and
-- awaiting-dispatch events frequently represented valid paid sales awaiting
-- operational fulfillment, so they were retained.
--
-- SAVED / parked and VOIDED / voided transaction events are excluded from the
-- analytical dataset because they do not represent completed sales.
-- Because receipt numbers can be reused, those exclusions are applied at the
-- Receipt_Number + Date event level rather than globally by Receipt_Number.
--
-- Source inventory review also identified non-production practice/test
-- activity in one source year. That activity was excluded from analytical
-- table construction.
--
-- Final cleaning decisions:
--   - Use Receipt_Number + Date as the transaction-event key.
--   - Preserve source metadata as sales_source_code.
--   - Preserve populated Attributes as transaction_attribute.
--   - Collapse duplicate Sale metadata only where exact duplicates are
--     confirmed.
--   - Retain valid paid pending-fulfillment transactions.
--   - Exclude SAVED / parked and VOIDED / voided events at event level.
--   - Exclude identified practice/test activity.