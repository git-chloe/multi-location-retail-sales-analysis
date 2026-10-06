-- DATA PRIVACY 03
-- Audit and Sanitize Product / Operational Descriptions

-- Purpose:
-- Preserve analytically useful product and operational descriptions while
-- identifying and removing text that could reveal the source retailer,
-- named locations, individuals, or other business-specific information.
--
-- This public file documents a sanitized version of the methodology.
-- Actual company, store, person, geographic, and event search literals remain
-- private and are represented here by generalized placeholders.
--
-- The source data and executable private mappings are not published.


-- ============================================================
-- Step 1: Profile retained descriptions
-- ============================================================

WITH combined AS (

  SELECT
    2023 AS sale_year,
    Receipt_Number,
    sale_datetime,
    Details

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2023`

  UNION ALL

  SELECT
    2024,
    Receipt_Number,
    sale_datetime,
    Details

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2024`

  UNION ALL

  SELECT
    2025,
    Receipt_Number,
    sale_datetime,
    Details

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2025`
)

SELECT
  sale_year,

  COUNT(*) AS sale_lines,

  COUNT(DISTINCT Details)
    AS distinct_descriptions,

  COUNTIF(Details IS NULL)
    AS missing_descriptions,

  COUNT(
    DISTINCT CONCAT(
      Receipt_Number,
      '|',
      CAST(sale_datetime AS STRING)
    )
  ) AS transaction_events

FROM combined

GROUP BY sale_year

ORDER BY sale_year;


-- ============================================================
-- Step 2: Screen for contact-style PII
-- ============================================================
-- Known retailer/store identifiers are audited privately because publishing
-- the actual search literals would undermine the anonymization itself.

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
    REGEXP_CONTAINS(
      LOWER(COALESCE(Details, '')),
      pattern
    )
  ) AS matching_rows

FROM combined

CROSS JOIN pii_patterns

GROUP BY
  sale_year,
  pii_type

ORDER BY
  sale_year,
  pii_type;


-- ============================================================
-- Step 3: Apply contextual sanitization
-- ============================================================
-- Transformation order matters.
--
-- Private implementation:
--
--   1. Generalizes geography only when its context contributes to
--      identifying the retailer.
--
--   2. Generalizes specifically identifiable event and person-related
--      descriptions.
--
--   3. Handles specific operational phrases before broader substitutions.
--
--   4. Replaces retailer/store identifiers with generic labels.
--
-- This prevents blanket replacement from unnecessarily altering unrelated
-- third-party product attributes.
--
-- Illustrative private mappings:
--
--   retailer identity      -> Retailer
--   named locations        -> Store A / Store B / Store C / Store D
--   identifying geography  -> City / Location
--   named local event      -> Annual Event
--   person-specific cause  -> Community Fundraiser
--
-- Generic operational terminology such as Warehouse is retained.


-- ============================================================
-- Step 4: Validate final transformation
-- ============================================================
-- Full validation is performed privately against the executable mapping.
--
-- The validation measures:
--
--   - total rows;
--   - rows whose Details value changed;
--   - percent of rows changed;
--   - remaining direct identifiers;
--   - remaining named-event references;
--   - remaining retailer-linked geography.
--
-- Final private results:
--
--   2023:
--     88,627 total rows
--     1,583 rows changed
--     1.79% changed
--
--   2024:
--     74,872 total rows
--       906 rows changed
--     1.21% changed
--
--   2025:
--     57,492 total rows
--       588 rows changed
--     1.02% changed
--
-- All three years returned:
--
--   0 remaining direct identifiers
--   0 remaining named-event references
--   0 remaining retailer-linked geography references


-- ============================================================
-- Findings
-- ============================================================
--
-- Details was retained because it contains substantial analytical value,
-- including merchandise, service, lease/rental, event, and operational
-- context.
--
-- Privacy review identified business names, named locations, retailer-linked
-- geography, a specifically identifiable local event, and a person-specific
-- fundraising description within otherwise legitimate records.
--
-- Contact-style screening found no email addresses, phone numbers, or
-- Canadian postal codes in Details.
--
-- Rather than deleting affected records, the identifying portion of each
-- description was selectively replaced.
--
-- Geography was treated contextually rather than globally. Geographic terms
-- were generalized when they contributed to identifying the source retailer,
-- while unrelated third-party product attributes were preserved.
--
-- The named event was generalized to "Annual Event" and the person-specific
-- fundraising family to "Community Fundraiser", preserving useful
-- transactional distinctions without preserving identifying information.
--
-- Only a small portion of each annual table required description changes:
-- 1.79% in 2023, 1.21% in 2024, and 1.02% in 2025.
--
-- Final private validation returned zero remaining direct identifiers,
-- zero named-event references, and zero retailer-linked geography references
-- across all three years.
--
-- Privacy decision:
-- Preserve useful descriptive information and remove only the identifying
-- component of affected values.