-- DATA PRIVACY 01
-- Audit Privacy-Sensitive Information

-- Purpose:
-- Identify information that could reveal customers, individuals, locations,
-- internal operational structure, or the identity of the source retailer
-- before creating the public-facing analytical tables.
--
-- This public file is a sanitized representation of the private privacy audit.
-- Identifying company names, store names, source codes, receipt prefixes,
-- personal references, and internal SKU literals have been generalized.
--
-- The private cleaned tables remain unchanged during this stage.


-- ============================================================
-- Step 1: Confirm retained analytical fields
-- ============================================================
-- Privacy begins with field minimization.
--
-- Customer names, payment information, employee names, register fields,
-- notes, and other unnecessary raw-export fields were excluded before the
-- public transformation.

SELECT
  table_name,
  ordinal_position,
  column_name,
  data_type

FROM `retail-sales-analytics-510318.retail_sales.INFORMATION_SCHEMA.COLUMNS`

WHERE table_name IN (
  'sales_lines_2023',
  'sales_lines_2024',
  'sales_lines_2025'
)

ORDER BY
  table_name,
  ordinal_position;


-- ============================================================
-- Step 2: Audit retained source metadata
-- ============================================================
-- Internal source codes may reveal store or location structure.
--
-- The public audit reports only the number of distinct source groups rather
-- than publishing the original codes.

WITH combined AS (

  SELECT
    2023 AS sale_year,
    sales_source_code

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2023`

  UNION ALL

  SELECT
    2024,
    sales_source_code

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2024`

  UNION ALL

  SELECT
    2025,
    sales_source_code

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2025`
)

SELECT
  sale_year,

  COUNT(DISTINCT sales_source_code)
    AS internal_source_groups

FROM combined

GROUP BY sale_year

ORDER BY sale_year;


-- ============================================================
-- Step 3: Audit original transaction-identifier structure
-- ============================================================
-- Original receipt values contain operational coding and are therefore not
-- suitable for publication.
--
-- This public version reports broad structural formats rather than the
-- retailer's actual prefixes.

WITH combined AS (

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
)

SELECT
  sale_year,

  CASE
    WHEN REGEXP_CONTAINS(Receipt_Number, r'^\d+$')
      THEN 'Numeric'

    WHEN REGEXP_CONTAINS(Receipt_Number, r'^[A-Za-z]+')
      THEN 'Coded Prefix'

    ELSE 'Other'
  END AS receipt_structure,

  COUNT(*) AS sale_lines,

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
  receipt_structure

ORDER BY
  sale_year,
  sale_lines DESC;


-- ============================================================
-- Step 4: Audit retained transaction attributes
-- ============================================================
-- These values were reviewed privately to ensure they contain generic
-- operational metadata rather than customer-specific information.

WITH combined AS (

  SELECT
    2023 AS sale_year,
    Receipt_Number,
    sale_datetime,
    transaction_attribute

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2023`

  UNION ALL

  SELECT
    2024,
    Receipt_Number,
    sale_datetime,
    transaction_attribute

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2024`

  UNION ALL

  SELECT
    2025,
    Receipt_Number,
    sale_datetime,
    transaction_attribute

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2025`
)

SELECT
  sale_year,
  COALESCE(transaction_attribute, '<NULL>')
    AS transaction_attribute,

  COUNT(*) AS sale_lines,

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
  transaction_attribute

ORDER BY
  sale_year,
  sale_lines DESC;


-- ============================================================
-- Step 5: Search for known identifying terms
-- ============================================================
-- Actual identifiers are replaced with placeholders in the public SQL.
--
-- The private version searched the retailer name, individual store/location
-- names, geographic references, and known person-specific references.

WITH combined AS (

  SELECT
    2023 AS sale_year,
    Receipt_Number,
    sale_datetime,
    Details,
    Sku,
    transaction_attribute

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2023`

  UNION ALL

  SELECT
    2024,
    Receipt_Number,
    sale_datetime,
    Details,
    Sku,
    transaction_attribute

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2024`

  UNION ALL

  SELECT
    2025,
    Receipt_Number,
    sale_datetime,
    Details,
    Sku,
    transaction_attribute

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2025`
),

base AS (

  SELECT
    *,

    CONCAT(
      Receipt_Number,
      '|',
      CAST(sale_datetime AS STRING)
    ) AS event_key,

    LOWER(CONCAT(
      COALESCE(Details, ''), ' ',
      COALESCE(CAST(Sku AS STRING), ''), ' ',
      COALESCE(transaction_attribute, '')
    )) AS searchable_text

  FROM combined
),

privacy_patterns AS (

  SELECT *
  FROM UNNEST([
    STRUCT('Retailer Name' AS identifier_type, r'<company_name>' AS pattern),
    STRUCT('Store Location' AS identifier_type, r'<store_location>' AS pattern),
    STRUCT('Geographic Reference' AS identifier_type, r'<geographic_reference>' AS pattern),
    STRUCT('Known Person Reference' AS identifier_type, r'<person_reference>' AS pattern)
  ])
)

SELECT
  sale_year,
  identifier_type,

  COUNTIF(
    REGEXP_CONTAINS(searchable_text, pattern)
  ) AS matching_rows,

  COUNT(
    DISTINCT IF(
      REGEXP_CONTAINS(searchable_text, pattern),
      event_key,
      NULL
    )
  ) AS affected_transaction_events

FROM base

CROSS JOIN privacy_patterns

GROUP BY
  sale_year,
  identifier_type

ORDER BY
  sale_year,
  identifier_type;


-- ============================================================
-- Step 6: Screen retained free-text for contact-style PII
-- ============================================================

WITH combined AS (

  SELECT
    2023 AS sale_year,
    Receipt_Number,
    sale_datetime,
    Details,
    transaction_attribute

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2023`

  UNION ALL

  SELECT
    2024,
    Receipt_Number,
    sale_datetime,
    Details,
    transaction_attribute

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2024`

  UNION ALL

  SELECT
    2025,
    Receipt_Number,
    sale_datetime,
    Details,
    transaction_attribute

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2025`
),

base AS (

  SELECT
    *,

    CONCAT(
      Receipt_Number,
      '|',
      CAST(sale_datetime AS STRING)
    ) AS event_key,

    LOWER(CONCAT(
      COALESCE(Details, ''), ' ',
      COALESCE(transaction_attribute, '')
    )) AS searchable_text

  FROM combined
),

pii_patterns AS (

  SELECT *
  FROM UNNEST([
    STRUCT(
      'Email Address' AS pii_type,
      r'[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}' AS pattern
    ),
    STRUCT(
      'Phone Number' AS pii_type,
      r'(\+?1[\s.-]?)?(\(?\d{3}\)?[\s.-]?)\d{3}[\s.-]?\d{4}' AS pattern
    ),
    STRUCT(
      'Canadian Postal Code' AS pii_type,
      r'\b[a-z]\d[a-z][ -]?\d[a-z]\d\b' AS pattern
    )
  ])
)

SELECT
  sale_year,
  pii_type,

  COUNTIF(
    REGEXP_CONTAINS(searchable_text, pattern)
  ) AS matching_rows,

  COUNT(
    DISTINCT IF(
      REGEXP_CONTAINS(searchable_text, pattern),
      event_key,
      NULL
    )
  ) AS affected_transaction_events

FROM base

CROSS JOIN pii_patterns

GROUP BY
  sale_year,
  pii_type

ORDER BY
  sale_year,
  pii_type;


-- ============================================================
-- Step 7: Review low-frequency free-text descriptions
-- ============================================================
-- Rare Details values are reviewed privately because unusual customer or
-- operational text may be missed by known-term and regex searches.

WITH combined AS (

  SELECT
    2023 AS sale_year,
    Details

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2023`

  UNION ALL

  SELECT
    2024,
    Details

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2024`

  UNION ALL

  SELECT
    2025,
    Details

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2025`
)

SELECT
  sale_year,
  Details,
  COUNT(*) AS row_count

FROM combined

GROUP BY
  sale_year,
  Details

HAVING COUNT(*) <= 2

ORDER BY
  sale_year,
  row_count,
  Details;


-- ============================================================
-- Findings
-- ============================================================
--
-- Privacy review was performed before creating the public-facing portfolio
-- tables rather than after publication.
--
-- The cleaned tables already exclude unnecessary raw customer, employee,
-- payment, register, and note fields.
--
-- Additional privacy risk remained in fields that are analytically useful:
--   - original receipt identifiers;
--   - internal source codes;
--   - retailer and store names within product/operational descriptions;
--   - identifying geographic references;
--   - retailer-derived internal SKU codes;
--   - a person-specific reference present in one source year.
--
-- Original transaction IDs and internal source codes were therefore marked
-- for replacement rather than publication.
--
-- transaction_attribute was retained because private review found only
-- generic operational metadata.
--
-- Contact-style PII screening found no email addresses, phone numbers, or
-- Canadian postal codes in the retained free-text analytical fields.
--
-- Low-frequency free-text values were also manually reviewed to catch
-- unusual identifying information not covered by known-term searches.
--
-- A generic Warehouse designation was retained because it does not uniquely
-- identify the source retailer.
--
-- Privacy decision:
-- Preserve analytically useful records and selectively anonymize identifying
-- content rather than deleting otherwise valid merchandise, service, or
-- operational records.