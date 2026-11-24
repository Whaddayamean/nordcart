-- One row per order with item totals. Amounts are in the order's local currency.
-- Uses the to_amount() macro: edit macros/helpers.sql to try a "macro-only" change.
with o as (
    select * from {{ ref('stg_orders') }}
),
items as (
    select
        i.order_id,
        count(*)                              as item_lines,
        sum(i.quantity)                       as units,
        sum(i.line_amount_cents)              as gross_cents,
        sum(i.quantity * p.unit_cost_cents)   as cost_cents,
        max(i._loaded_at)                     as items_loaded_at
    from {{ ref('stg_order_items') }} i
    left join {{ ref('stg_products') }} p using (product_id)
    group by i.order_id
)
select
    o.order_id,
    o.customer_id,
    o.order_ts,
    o.order_date,
    o.status,
    o.channel_code,
    o.country_code,
    o.currency,
    o.is_revenue,
    coalesce(items.item_lines, 0)                         as item_lines,
    coalesce(items.units, 0)                              as units,
    {{ to_amount('coalesce(items.gross_cents, 0)') }}     as gross_amount,
    {{ to_amount('coalesce(items.cost_cents, 0)') }}      as cost_amount,
    {{ to_amount('o.discount_cents') }}                   as discount_amount,
    {{ to_amount('o.shipping_cents') }}                   as shipping_amount,
    greatest(o._loaded_at, coalesce(items.items_loaded_at, o._loaded_at)) as _loaded_at
from o
left join items using (order_id)
