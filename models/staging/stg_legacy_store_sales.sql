{{ config(materialized='table') }}
-- frozen source (legacy POS decommissioned 2024). Materialised as a table on purpose:
-- in a stateless world this re-copies 2+ years of history on every run.
select
    sale_id,
    store_id,
    cast(sale_date as date)            as sale_date,
    product_id,
    quantity,
    revenue_cents
from {{ source('raw', 'legacy_store_sales') }}
