select
    product_id,
    sku,
    product_name,
    category,
    subcategory,
    brand,
    unit_cost_cents,
    list_price_cents,
    is_discontinued,
    _loaded_at
from {{ source('raw', 'products') }}
