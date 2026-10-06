-- CREATE PORTFOLIO TABLE 01
-- Create Anonymized Portfolio Sales Tables

-- Purpose:
-- Create portfolio-facing analytical tables from the final cleaned annual
-- sales datasets while preserving analytical relationships and removing
-- private business identifiers.
--
-- Private source data, original receipt identifiers, source-code mappings,
-- identifying SKU values, and private replacement dictionaries are not
-- published.
--
-- The same transformation framework is applied independently to each year.


-- ============================================================
-- Transformation Framework
-- ============================================================
--
-- 1. Identify each transaction using the validated event key:
--
--      private_receipt_identifier + sale_datetime
--
-- 2. Assign an anonymous transaction ID:
--
--      TXN_000001
--      TXN_000002
--      ...
--
--    IDs are assigned primarily in chronological order so public numbering
--    does not reproduce the private receipt/source structure.
--
-- 3. Replace private source codes with approved public categories:
--
--      Store A
--      Store B
--      Store C
--      Store D
--      Online / Event
--
-- 4. Apply contextual description sanitization:
--
--      retailer identity       -> Retailer
--      named stores            -> Store A / B / C / D
--      retailer-linked city    -> City
--      retailer-linked place   -> Location
--      named local event       -> Annual Event
--      person-specific cause   -> Community Fundraiser
--
--    Unrelated third-party geographic references are preserved.
--
-- 5. Replace identifying SKU values with anonymous or generic codes.
--
--    Examples of public-safe categories:
--
--      anonymous store code
--      generic service code
--      generic operational code
--
-- 6. Remove private/helper fields from the final SELECT.
--
-- 7. Retain only the approved analytical schema:
--
--      sale_datetime
--      transaction_id
--      sales_source
--      transaction_attribute
--      quantity
--      subtotal
--      sales_tax
--      discount
--      loyalty
--      total
--      Details
--      Sku


-- ============================================================
-- Illustrative Creation Pattern
-- ============================================================
--
-- The executable private version contains the actual identifier mappings.
-- This public version shows the transformation structure without exposing
-- those private literals.

WITH transaction_map AS (

  SELECT
    private_receipt_identifier,
    sale_datetime,

    CONCAT(
      'TXN_',
      LPAD(
        CAST(
          ROW_NUMBER() OVER (
            ORDER BY
              sale_datetime,
              private_receipt_identifier
          ) AS STRING
        ),
        6,
        '0'
      )
    ) AS transaction_id

  FROM (
    SELECT DISTINCT
      private_receipt_identifier,
      sale_datetime

    FROM cleaned_sales
  )
),

portfolio_transformation AS (

  SELECT
    s.sale_datetime,
    t.transaction_id,

    -- Private source codes are mapped to approved anonymous categories.
    anonymized_sales_source AS sales_source,

    s.transaction_attribute,
    s.quantity,
    s.subtotal,
    s.sales_tax,
    s.discount,
    s.loyalty,
    s.total,

    sanitized_details AS Details,
    sanitized_sku AS Sku

  FROM cleaned_sales AS s

  JOIN transaction_map AS t
    ON s.private_receipt_identifier = t.private_receipt_identifier
   AND s.sale_datetime = t.sale_datetime
)

SELECT *
FROM portfolio_transformation;


-- ============================================================
-- Final Annual Tables
-- ============================================================
--
-- The private executable process creates:
--
--   portfolio_sales_2023
--   portfolio_sales_2024
--   portfolio_sales_2025
--
-- Each annual table retains the Sale Line grain and the same approved
-- 12-field public schema.
--
-- Creation is followed by a separate validation step that reconciles each
-- portfolio table directly to its corresponding cleaned source table.