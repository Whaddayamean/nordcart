select
    product_id,
    sku,
    product_name,
    category,
    subcategory,
    brand,
    unit_cost_cents / 100.0                                   as unit_cost,
    list_price_cents / 100.0                                  as list_price,
    round(1 - unit_cost_cents * 1.0 / nullif(list_price_cents, 0), 4) as list_margin_pct,
    is_discontinued
from {{ ref('stg_products') }}
