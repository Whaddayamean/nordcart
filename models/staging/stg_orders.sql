-- a beautiful stg_orders model doc
select
    order_id,
    customer_id,
    cast(order_ts as timestamp)        as order_ts,
    cast(order_ts as date)             as order_date,
    status,
    channel_code,
    ship_country                       as country_code,
    currency,
    shipping_cents,
    discount_cents,
    status in ('completed', 'shipped') as is_revenue,
    _loaded_at
from {{ source('raw', 'orders') }}

