with o as (select * from {{ ref('stg_orders') }}),
li as (
    select order_id,
           count(*)               as item_lines,
           sum(quantity)          as units,
           sum(line_amount_eur)   as gross_eur,
           sum(line_cost_eur)     as cost_eur,
           max(rate_to_eur)       as rate_to_eur
    from {{ ref('int_order_items_enriched') }}
    group by 1
),
p as (select * from {{ ref('int_order_payments') }})
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
    coalesce(li.item_lines, 0)                                           as item_lines,
    coalesce(li.units, 0)                                                as units,
    coalesce(li.gross_eur, 0)                                            as gross_eur,
    coalesce(li.cost_eur, 0)                                             as cost_eur,
    {{ cents_to_eur('o.discount_cents', 'coalesce(li.rate_to_eur, 0)') }} as discount_eur,
    {{ cents_to_eur('o.shipping_cents', 'coalesce(li.rate_to_eur, 0)') }} as shipping_eur,
    coalesce(p.captured_cents, 0)                                        as captured_cents,
    coalesce(p.refunded_cents, 0)                                        as refunded_cents,
    p.first_paid_ts,
    greatest(o._loaded_at, coalesce(p.payments_loaded_at, o._loaded_at)) as _loaded_at
from o
left join li using (order_id)
left join p using (order_id)
