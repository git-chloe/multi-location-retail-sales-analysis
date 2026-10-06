-- DATA CLEANING 04
-- Validate Zero-Priced Sale Lines

-- Purpose:
-- Determine whether product-level Sale Lines with no standalone recorded
-- price represent data-quality problems or legitimate transaction activity.
--
-- A cross-year validation confirmed that subtotal = 0 and total = 0 identify
-- exactly the same records in all three source years.
--
-- subtotal = 0 is used because it most directly represents whether a Sale
-- Line carries its own recorded price before tax.
--
-- Zero-priced records are investigated rather than automatically removed.
--
-- Specific retailer locations, shipping-provider references, product
-- descriptions, and other proprietary literals used during private review
-- have been generalized or omitted from this public version.


-- ============================================================
-- Step 1: Measure zero-priced Sale Line activity
-- ============================================================

WITH combined AS (

  SELECT
    2023 AS sale_year,
    Receipt_Number,
    sale_datetime,
    quantity,
    subtotal

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2023`

  UNION ALL

  SELECT
    2024,
    Receipt_Number,
    sale_datetime,
    quantity,
    subtotal

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2024`

  UNION ALL

  SELECT
    2025,
    Receipt_Number,
    sale_datetime,
    quantity,
    subtotal

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2025`
)

SELECT
  sale_year,

  COUNTIF(subtotal = 0)
    AS zero_priced_rows,

  COUNT(
    DISTINCT IF(
      subtotal = 0,
      CONCAT(
        Receipt_Number,
        '|',
        CAST(sale_datetime AS STRING)
      ),
      NULL
    )
  ) AS affected_transaction_events,

  SUM(
    CASE
      WHEN subtotal = 0 THEN quantity
      ELSE 0
    END
  ) AS net_units

FROM combined

GROUP BY sale_year

ORDER BY sale_year;


-- ============================================================
-- Step 2: Classify zero-priced Sale Lines
-- ============================================================
-- The same classification framework is applied to each year.
--
-- Identifying location names and certain operational literals have been
-- replaced with generic placeholders in the published SQL.

WITH combined AS (

  SELECT
    2023 AS sale_year,
    Receipt_Number,
    sale_datetime,
    quantity,
    subtotal,
    loyalty,
    Details

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2023`

  UNION ALL

  SELECT
    2024,
    Receipt_Number,
    sale_datetime,
    quantity,
    subtotal,
    loyalty,
    Details

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2024`

  UNION ALL

  SELECT
    2025,
    Receipt_Number,
    sale_datetime,
    quantity,
    subtotal,
    loyalty,
    Details

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2025`
),

classified AS (

  SELECT
    *,

    CASE
      WHEN LOWER(Details) LIKE 'trade-in%'
        THEN 'Trade-In Credit'

      WHEN LOWER(Details) LIKE 'season lease%'
        THEN 'Season Lease'

      WHEN LOWER(Details) LIKE '%shipping%'
        OR LOWER(Details) LIKE '%parcel%'
        OR LOWER(Details) LIKE '%<shipping_provider>%'
        THEN 'Shipping'

      WHEN LOWER(Details) LIKE '%warranty%'
        THEN 'Warranty'

      WHEN LOWER(Details) IN (
        '<location_a>',
        '<location_a_pickup>',
        '<location_b>',
        '<location_c>',
        '<location_d>',
        'warehouse'
      )
        THEN 'Location / Operational'

      WHEN LOWER(Details) LIKE '%leas%'
        THEN 'Lease'

      WHEN LOWER(Details) LIKE '%service%'
        OR LOWER(Details) LIKE '%serv.%'
        OR LOWER(Details) LIKE '%labour%'
        OR LOWER(Details) LIKE '%fitting%'
        OR LOWER(Details) LIKE '%tune%'
        OR LOWER(Details) LIKE '%repair%'
        OR LOWER(Details) LIKE '%adjustment%'
        OR LOWER(Details) LIKE '%test ride%'
        OR LOWER(Details) LIKE '%tire pressure%'
        OR LOWER(Details) LIKE '%lubricate chain%'
        OR LOWER(Details) LIKE '%safety check%'
        OR LOWER(Details) LIKE '%wheel truing%'
        OR LOWER(Details) LIKE '%reconditioning%'
        OR LOWER(Details) LIKE '%sharpen%'
        THEN 'Service / Labour'

      ELSE 'Other'
    END AS zero_priced_type

  FROM combined

  WHERE subtotal = 0
)

SELECT
  sale_year,
  zero_priced_type,

  COUNT(*) AS row_count,

  COUNT(
    DISTINCT CONCAT(
      Receipt_Number,
      '|',
      CAST(sale_datetime AS STRING)
    )
  ) AS transaction_events,

  SUM(quantity) AS net_units,

  ROUND(SUM(loyalty), 2)
    AS loyalty_value,

  ROUND(
    100 * COUNT(*) /
    SUM(COUNT(*)) OVER (PARTITION BY sale_year),
    2
  ) AS pct_of_zero_priced_rows

FROM classified

GROUP BY
  sale_year,
  zero_priced_type

ORDER BY
  sale_year,
  row_count DESC;


-- ============================================================
-- Step 3: Measure transaction context
-- ============================================================
-- Determine whether zero-priced categories appear within transactions that
-- also contain one or more priced Sale Lines.
--
-- Category-level event counts are not additive because one transaction event
-- can contain more than one zero-priced category.

WITH combined AS (

  SELECT
    2023 AS sale_year,
    Receipt_Number,
    sale_datetime,
    subtotal,
    Details

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2023`

  UNION ALL

  SELECT
    2024,
    Receipt_Number,
    sale_datetime,
    subtotal,
    Details

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2024`

  UNION ALL

  SELECT
    2025,
    Receipt_Number,
    sale_datetime,
    subtotal,
    Details

  FROM `retail-sales-analytics-510318.retail_sales.sales_lines_2025`
),

classified_zero_priced AS (

  SELECT
    sale_year,
    Receipt_Number,
    sale_datetime,

    CASE
      WHEN LOWER(Details) LIKE 'trade-in%'
        THEN 'Trade-In Credit'

      WHEN LOWER(Details) LIKE 'season lease%'
        THEN 'Season Lease'

      WHEN LOWER(Details) LIKE '%shipping%'
        OR LOWER(Details) LIKE '%parcel%'
        OR LOWER(Details) LIKE '%<shipping_provider>%'
        THEN 'Shipping'

      WHEN LOWER(Details) LIKE '%warranty%'
        THEN 'Warranty'

      WHEN LOWER(Details) IN (
        '<location_a>',
        '<location_a_pickup>',
        '<location_b>',
        '<location_c>',
        '<location_d>',
        'warehouse'
      )
        THEN 'Location / Operational'

      WHEN LOWER(Details) LIKE '%leas%'
        THEN 'Lease'

      WHEN LOWER(Details) LIKE '%service%'
        OR LOWER(Details) LIKE '%serv.%'
        OR LOWER(Details) LIKE '%labour%'
        OR LOWER(Details) LIKE '%fitting%'
        OR LOWER(Details) LIKE '%tune%'
        OR LOWER(Details) LIKE '%repair%'
        OR LOWER(Details) LIKE '%adjustment%'
        OR LOWER(Details) LIKE '%test ride%'
        OR LOWER(Details) LIKE '%tire pressure%'
        OR LOWER(Details) LIKE '%lubricate chain%'
        OR LOWER(Details) LIKE '%safety check%'
        OR LOWER(Details) LIKE '%wheel truing%'
        OR LOWER(Details) LIKE '%reconditioning%'
        OR LOWER(Details) LIKE '%sharpen%'
        THEN 'Service / Labour'

      ELSE 'Other'
    END AS zero_priced_type

  FROM combined

  WHERE subtotal = 0
),

transaction_context AS (

  SELECT
    sale_year,
    Receipt_Number,
    sale_datetime,

    COUNTIF(subtotal != 0)
      AS priced_sale_lines

  FROM combined

  GROUP BY
    sale_year,
    Receipt_Number,
    sale_datetime
),

category_events AS (

  SELECT DISTINCT
    z.sale_year,
    z.zero_priced_type,
    z.Receipt_Number,
    z.sale_datetime,
    t.priced_sale_lines

  FROM classified_zero_priced AS z

  JOIN transaction_context AS t
    ON z.sale_year = t.sale_year
   AND z.Receipt_Number = t.Receipt_Number
   AND z.sale_datetime = t.sale_datetime
)

SELECT
  sale_year,
  zero_priced_type,

  COUNT(*) AS transaction_events,

  COUNTIF(priced_sale_lines > 0)
    AS events_with_priced_sale_lines,

  COUNTIF(priced_sale_lines = 0)
    AS events_with_only_zero_priced_lines,

  ROUND(
    100 * COUNTIF(priced_sale_lines > 0) / COUNT(*),
    2
  ) AS pct_with_priced_sale_lines

FROM category_events

GROUP BY
  sale_year,
  zero_priced_type

ORDER BY
  sale_year,
  transaction_events DESC;


-- ============================================================
-- Findings
-- ============================================================
--
-- Zero-priced Sale Lines are present in all three source years:
--
--   2023: 5,654 rows across 3,370 transaction events
--   2024: 4,738 rows across 2,808 transaction events
--   2025: 7,058 rows across 2,542 transaction events
--
-- The records are not explained by a single data-quality issue. They represent
-- several legitimate POS structures including trade-in credits, lease
-- components, shipping, operational records, warranties, service components,
-- package components, and other merchandise recorded without a standalone
-- line price.
--
-- The composition also changes across years.
--
-- In 2023 and 2024, Trade-In Credit and Season Lease records account for a
-- substantial share of zero-priced activity.
--
-- In 2025, Service / Labour components account for 4,528 rows, or 64.15% of
-- all zero-priced Sale Lines. Most of these appear within transactions that
-- also contain a priced line, indicating a detailed service-component
-- recording structure rather than broadly missing prices.
--
-- Most operational, shipping, lease, and service categories occur within
-- transactions containing separately priced Sale Lines.
--
-- Trade-In Credit behaves differently: nearly all such transaction events
-- contain only zero-priced lines, while the associated credit value is
-- recorded in the loyalty field.
--
-- Private inspection of the remaining Other category found ordinary
-- merchandise, package, rental, used-product, and miscellaneous activity.
-- Other represents only 2.67% of zero-priced rows in 2023, 4.37% in 2024,
-- and 3.30% in 2025.
--
-- No evidence was identified that zero-priced Sale Lines represent a
-- systematic parsing, conversion, or missing-price defect.
--
-- Cleaning decision:
-- Retain zero-priced Sale Lines in the cleaned analytical tables.
--
-- Their inclusion in later metrics depends on the analytical question.
-- In particular, zero-priced units are retained in the source data but are
-- not automatically treated as separately purchased merchandise units when
-- measuring retail basket quantity.