-- DATA PRIVACY 04
-- Audit Customer-Specific Free Text

-- Purpose:
-- Confirm that the retained product/operational description field does not
-- function as a customer-notes field or contain customer-specific free text.
--
-- Direct contact-style PII screening is documented separately.
-- This step focuses on note-like language, unusually long descriptions,
-- and confirmation that the source Notes field was excluded from the
-- analytical pipeline.


-- ============================================================
-- Step 1: Confirm source-note fields are excluded
-- ============================================================

SELECT
  table_name,

  COUNTIF(
    LOWER(column_name) IN ('note', 'notes')
  ) AS note_fields_present

FROM `retail-sales-analytics-510318.retail_sales.INFORMATION_SCHEMA.COLUMNS`

WHERE table_name IN (
  'sales_lines_2023',
  'sales_lines_2024',
  'sales_lines_2025'
)

GROUP BY table_name

ORDER BY table_name;


-- ============================================================
-- Step 2: Measure customer-note language candidates
-- ============================================================
-- Matches are review indicators, not automatic privacy violations.
-- Product names may legitimately contain terms such as "contact."

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

  COUNT(*) AS total_sale_lines,

  COUNTIF(
    REGEXP_CONTAINS(
      LOWER(COALESCE(Details, '')),
      r'\b(customer|client|phone|email|call|contact|attention|attn)\b'
      r'|hold for|special order|ordered for|pickup for|reserved for'
    )
  ) AS rows_matching_note_language,

  COUNT(
    DISTINCT IF(
      REGEXP_CONTAINS(
        LOWER(COALESCE(Details, '')),
        r'\b(customer|client|phone|email|call|contact|attention|attn)\b'
        r'|hold for|special order|ordered for|pickup for|reserved for'
      ),
      Details,
      NULL
    )
  ) AS distinct_matching_descriptions

FROM combined

GROUP BY sale_year

ORDER BY sale_year;


-- ============================================================
-- Step 3: Measure unusually long descriptions
-- ============================================================
-- Length alone is not treated as a privacy violation.
-- Long descriptions are reviewed privately for note-like content.

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

  COUNTIF(
    LENGTH(Details) >= 100
  ) AS long_description_rows,

  COUNT(
    DISTINCT IF(
      LENGTH(Details) >= 100,
      Details,
      NULL
    )
  ) AS distinct_long_descriptions

FROM combined

GROUP BY sale_year

ORDER BY sale_year;


-- ============================================================
-- Findings
-- ============================================================
--
-- The source export contained a separate free-text Notes field that was not
-- required for analysis and could contain customer-specific information.
-- That field was excluded from the cleaned analytical tables and is not
-- carried into the portfolio dataset.
--
-- Note-language screening of Details produced a small number of candidates.
-- Private manual review confirmed that the matches were legitimate product
-- or operational descriptions rather than customer-specific notes.
--
-- Unusually long Details values were also manually reviewed. They contained
-- legitimate combinations of product attributes and technical information,
-- not customer names or customer-specific instructions.
--
-- Direct email, phone, and postal-code screening was performed separately
-- and produced no matches in the retained descriptive analytical fields.
--
-- Privacy decision:
-- Retain Details because it provides useful analytical context.
--
-- No additional customer-specific redaction is required beyond the
-- business-identity sanitization documented in the preceding privacy step.
--
-- The original source Notes field remains excluded.