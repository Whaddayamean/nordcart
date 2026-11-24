select
    order_item_id,
    order_id,
    product_id,
    quantity,
    unit_price_cents,
    quantity * unit_price_cents        as line_amount_cents,
    _loaded_at
from {{ source('raw', 'order_items') }}
