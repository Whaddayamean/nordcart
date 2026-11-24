-- frozen source only: heavy-ish aggregate over 3 years of POS history that never changes
select
    store_id,
    {{ dbt.date_trunc('month', 'sale_date') }}       as month_start,
    count(*)                             as receipts,
    sum(quantity)                        as units,
    sum(revenue_cents) / 100.0           as revenue_czk,
    count(distinct product_id)           as distinct_products
from {{ ref('stg_legacy_store_sales') }}
group by 1, 2
