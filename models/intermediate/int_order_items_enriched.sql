with items as (select * from {{ ref('stg_order_items') }}),
orders as (select order_id, order_date, currency, country_code, channel_code, is_revenue from {{ ref('stg_orders') }}),
products as (select * from {{ ref('stg_products') }}),
fx as (select * from {{ ref('int_fx_latest') }}),
fx_latest as (select distinct currency, latest_rate_to_eur from fx)
select
    i.order_item_id,
    i.order_id,
    o.order_date,
    o.country_code,
    o.channel_code,
    o.is_revenue,
    i.product_id,
    p.category,
    p.subcategory,
    p.brand,
    i.quantity,
    i.line_amount_cents,
    i.quantity * p.unit_cost_cents                                           as line_cost_cents,
    coalesce(fx.rate_to_eur, fl.latest_rate_to_eur)                          as rate_to_eur,
    {{ cents_to_eur('i.line_amount_cents', 'coalesce(fx.rate_to_eur, fl.latest_rate_to_eur)') }} as line_amount_eur,
    {{ cents_to_eur('i.quantity * p.unit_cost_cents', 'coalesce(fx.rate_to_eur, fl.latest_rate_to_eur)') }} as line_cost_eur
from items i
join orders o using (order_id)
left join products p using (product_id)
left join fx on fx.currency = o.currency and fx.rate_date = o.order_date
left join fx_latest fl on fl.currency = o.currency
