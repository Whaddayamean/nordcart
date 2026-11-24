{#
  SELECT statements that produce rows for each raw table. Used by nc_init (CREATE TABLE AS)
  and nc_tick (INSERT INTO). Column order matters: INSERTs are positional.
#}

{% macro nc_sel_customers(start_id, n, ts_from, span_s) %}
{%- set L = nc_lists() -%}
{%- set id = '(g.i + ' ~ start_id ~ ')' -%}
select
    {{ id }}                                                          as customer_id,
    {{ nc_pick(id, 'fn', L.first) }}                                  as first_name,
    {{ nc_pick(id, 'ln', L.last) }}                                   as last_name,
    concat('user', cast({{ id }} as string), '@example.com')         as email,
    {{ nc_pick(id, 'cc', L.countries) }}                              as country_code,
    {{ nc_pick(id, 'seg', L.segments) }}                              as segment,
    {{ dbt.dateadd('second', nc_rand(id, 'su', span_s), ts_from) }}  as signup_ts,
    ({{ nc_rand(id, 'act', 100) }} >= 6)                              as is_active,
    {{ nc_now() }}                                                    as _loaded_at
from {{ nc_rows(n) }} g
{% endmacro %}

{% macro nc_sel_products(start_id, n) %}
{%- set L = nc_lists() -%}
{%- set id = '(g.i + ' ~ start_id ~ ')' -%}
select
    b.product_id,
    concat('NC-', cast(b.product_id as string))                      as sku,
    concat(b.brand, ' ', b.subcategory, ' ', cast(b.product_id as string)) as product_name,
    b.category,
    b.subcategory,
    b.brand,
    b.unit_cost_cents,
    cast(b.unit_cost_cents * (125 + {{ nc_rand('b.product_id', 'mk', 115) }}) / 100 as bigint) as list_price_cents,
    ({{ nc_rand('b.product_id', 'disc', 100) }} < 5)                 as is_discontinued,
    {{ nc_now() }}                                                    as _loaded_at
from (
    select
        {{ id }}                                       as product_id,
        {{ nc_pick(id, 'cat', L.categories) }}         as category,
        {{ nc_pick(id, 'sub', L.subcategories) }}      as subcategory,
        {{ nc_pick(id, 'br', L.brands) }}              as brand,
        500 + {{ nc_rand(id, 'cost', 20000) }}         as unit_cost_cents
    from {{ nc_rows(n) }} g
) b
{% endmacro %}

{# orders: n rows spread over [offset_s, offset_s + span_s) seconds after the business start #}
{% macro nc_sel_orders(start_id, n, offset_s, span_s, n_customers) %}
{%- set L = nc_lists() -%}
{%- set id = '(g.i + ' ~ start_id ~ ')' -%}
select
    b.order_id,
    b.customer_id,
    b.order_ts,
    b.status,
    b.channel_code,
    b.ship_country,
    case b.ship_country {% for c, cur in L.currency_by_country.items() %}when '{{ c }}' then '{{ cur }}' {% endfor %}end as currency,
    b.shipping_cents,
    b.discount_cents,
    {{ nc_now() }}                                                    as _loaded_at
from (
    select
        {{ id }}                                                      as order_id,
        1 + {{ nc_rand(id, 'cust', n_customers) }}                    as customer_id,
        {{ dbt.dateadd('second', offset_s ~ ' + cast(g.i * ' ~ span_s ~ ' / ' ~ n ~ ' as bigint)', nc_start()) }} as order_ts,
        {{ nc_pick(id, 'st', L.statuses) }}                           as status,
        {{ nc_pick(id, 'ch', L.channels) }}                           as channel_code,
        {{ nc_pick(id, 'cc', L.countries) }}                          as ship_country,
        {{ nc_pick(id, 'sh', [0, 0, 0, 299, 499, 899]) }}             as shipping_cents,
        case when {{ nc_rand(id, 'd', 100) }} < 18 then 100 + {{ nc_rand(id, 'dv', 2400) }} else 0 end as discount_cents
    from {{ nc_rows(n) }} g
) b
{% endmacro %}

{# 1-5 items for every order with order_id > after_order_id #}
{% macro nc_sel_order_items(after_order_id, start_item_id, n_products) %}
select
    row_number() over (order by o.order_id, k.i) + {{ start_item_id - 1 }} as order_item_id,
    o.order_id,
    p.product_id,
    {{ nc_pick('o.order_id, k.i', 'q', [1, 1, 1, 2, 2, 3, 4]) }}            as quantity,
    cast(p.list_price_cents * (85 + {{ nc_rand('o.order_id, k.i', 'pd', 16) }}) / 100 as bigint) as unit_price_cents,
    {{ nc_now() }}                                                         as _loaded_at
from {{ nc_rel('orders') }} o
join {{ nc_rows(5) }} k
  on k.i <= {{ nc_rand('o.order_id', 'k', 5) }}
join {{ nc_rel('products') }} p
  on p.product_id = 1 + {{ nc_rand('o.order_id, k.i', 'p', n_products) }}
where o.order_id > {{ after_order_id }}
{% endmacro %}

{% macro nc_sel_payments(after_order_id, start_payment_id) %}
{%- set L = nc_lists() -%}
select
    row_number() over (order by o.order_id) + {{ start_payment_id - 1 }}  as payment_id,
    o.order_id,
    {{ nc_pick('o.order_id', 'pm', L.pay_methods) }}                     as payment_method,
    greatest(0, coalesce(s.gross_cents, 0) + o.shipping_cents - o.discount_cents) as amount_cents,
    o.currency,
    {{ dbt.dateadd('second', '5 + ' ~ nc_rand('o.order_id', 'pt', 3600), 'o.order_ts') }} as paid_ts,
    {{ nc_pick('o.order_id', 'ps', L.pay_statuses) }}                    as status,
    {{ nc_now() }}                                                        as _loaded_at
from {{ nc_rel('orders') }} o
left join (
    select order_id, sum(quantity * unit_price_cents) as gross_cents
    from {{ nc_rel('order_items') }}
    where order_id > {{ after_order_id }}
    group by order_id
) s on s.order_id = o.order_id
where o.order_id > {{ after_order_id }}
  and o.status in ('completed', 'shipped', 'returned')
{% endmacro %}

{% macro nc_sel_web_events(start_id, n, offset_s, span_s, n_customers, n_products) %}
{%- set L = nc_lists() -%}
{%- set id = '(g.i + ' ~ start_id ~ ')' -%}
select
    b.event_id,
    concat('a_', cast(b.anon as string))                                 as anonymous_id,
    case when {{ nc_rand('b.anon', 'idt', 100) }} < 40 then 1 + ({{ 'b.anon' }} % {{ n_customers }}) end as customer_id,
    b.event_ts,
    b.event_type,
    case when b.page = '/p/item' then concat('/p/', cast(1 + {{ nc_rand('b.event_id', 'pp', n_products) }} as string)) else b.page end as page_path,
    b.channel_code,
    b.utm_source,
    b.device,
    {{ nc_now() }}                                                        as _loaded_at
from (
    select
        {{ id }}                                                          as event_id,
        {{ nc_rand(id, 'anon', n_customers * 3) }}                        as anon,
        {{ dbt.dateadd('second', offset_s ~ ' + cast(g.i * ' ~ span_s ~ ' / ' ~ n ~ ' as bigint)', nc_start()) }} as event_ts,
        {{ nc_pick(id, 'et', L.event_types) }}                            as event_type,
        {{ nc_pick(id, 'pg', L.pages) }}                                  as page,
        {{ nc_pick(id, 'wc', L.web_channels) }}                           as channel_code,
        {{ nc_pick(id, 'utm', L.utm) }}                                   as utm_source,
        {{ nc_pick(id, 'dev', L.devices) }}                               as device
    from {{ nc_rows(n) }} g
) b
{% endmacro %}

{% macro nc_union_values(col, values) -%}
    ({% for v in values %}select '{{ v }}' as {{ col }}{% if not loop.last %} union all {% endif %}{% endfor %})
{%- endmacro %}

{% macro nc_day(first_day, offset_expr) -%}
    cast({{ dbt.dateadd('day', offset_expr, "cast('" ~ first_day ~ "' as date)") }} as date)
{%- endmacro %}

{% macro nc_sel_inventory(first_day, n_days, n_products) %}
{%- set L = nc_lists() -%}
select
    {{ nc_day(first_day, 'd.i') }}                                        as snapshot_date,
    w.warehouse_id,
    p.i + 1                                                               as product_id,
    5 + {{ nc_rand("p.i, w.warehouse_id, d.i, '" ~ first_day ~ "'", 'oh', 80) }} as on_hand_qty,
    {{ nc_rand("p.i, w.warehouse_id, d.i, '" ~ first_day ~ "'", 'rs', 8) }}      as reserved_qty,
    {{ nc_now() }}                                                        as _loaded_at
from {{ nc_rows(n_days) }} d
cross join {{ nc_rows(n_products) }} p
cross join {{ nc_union_values('warehouse_id', L.warehouses) }} w
{% endmacro %}

{% macro nc_sel_fx(first_day, n_days) %}
{%- set L = nc_lists() -%}
select
    {{ nc_day(first_day, 'd.i') }}                                        as rate_date,
    c.currency,
    case c.currency {% for cur, base in L.fx.items() %}when '{{ cur }}' then {{ base }} {% endfor %}end
      * (case when c.currency = 'EUR' then 1 else 1 + ({{ nc_rand("d.i, c.currency, '" ~ first_day ~ "'", 'fx', 800) }} - 400) / 100000.0 end) as rate_to_eur,
    {{ nc_now() }}                                                        as _loaded_at
from {{ nc_rows(n_days) }} d
cross join {{ nc_union_values('currency', L.fx.keys() | list) }} c
{% endmacro %}

{% macro nc_sel_marketing(first_day, n_days) %}
{%- set L = nc_lists() -%}
{%- set k = "d.i, m.channel_code, c.i, '" ~ first_day ~ "'" -%}
select
    {{ nc_day(first_day, 'd.i') }}                                        as spend_date,
    m.channel_code,
    concat(m.channel_code, '-0', cast(c.i + 1 as string))                as campaign_id,
    case when m.channel_code = 'seo' then 0 else 1000 + {{ nc_rand(k, 'sp', 50000) }} end as spend_cents,
    1000 + {{ nc_rand(k, 'imp', 40000) }}                                 as impressions,
    cast((1000 + {{ nc_rand(k, 'imp', 40000) }}) * (8 + {{ nc_rand(k, 'ctr', 32) }}) / 1000 as bigint) as clicks,
    {{ nc_now() }}                                                        as _loaded_at
from {{ nc_rows(n_days) }} d
cross join {{ nc_union_values('channel_code', L.mkt_channels) }} m
cross join {{ nc_rows(3) }} c
{% endmacro %}

{% macro nc_sel_support_tickets(n, n_customers, span_s) %}
{%- set id = '(g.i + 1)' -%}
select
    b.ticket_id, b.customer_id, b.opened_ts,
    {{ dbt.dateadd('second', '600 + ' ~ nc_rand('b.ticket_id', 'cl', 600000), 'b.opened_ts') }} as closed_ts,
    b.priority, b.category, b.csat,
    {{ nc_ts('2025-09-01 03:00:00') }}                                    as _loaded_at
from (
    select
        {{ id }}                                                          as ticket_id,
        1 + {{ nc_rand(id, 'tc', n_customers) }}                          as customer_id,
        {{ dbt.dateadd('second', nc_rand(id, 'to', span_s), nc_start()) }} as opened_ts,
        {{ nc_pick(id, 'pr', ['low', 'low', 'normal', 'normal', 'normal', 'high', 'urgent']) }} as priority,
        {{ nc_pick(id, 'tcat', ['delivery', 'refund', 'product', 'account', 'payment']) }}    as category,
        {{ nc_pick(id, 'csat', [1, 2, 3, 3, 4, 4, 4, 5, 5, 5]) }}                             as csat
    from {{ nc_rows(n) }} g
) b
{% endmacro %}

{% macro nc_sel_legacy(n, n_products) %}
{%- set L = nc_lists() -%}
{%- set id = '(g.i + 1)' -%}
select
    {{ id }}                                                              as sale_id,
    {{ nc_pick(id, 'store', L.stores) }}                                  as store_id,
    {{ nc_day('2021-01-01', nc_rand(id, 'sd', 1095)) }}                   as sale_date,
    1 + {{ nc_rand(id, 'lp', n_products) }}                               as product_id,
    1 + {{ nc_rand(id, 'lq', 4) }}                                        as quantity,
    (1 + {{ nc_rand(id, 'lq', 4) }}) * (500 + {{ nc_rand(id, 'lr', 5000) }}) as revenue_cents,
    {{ nc_ts('2024-06-30 23:00:00') }}                                    as _loaded_at
from {{ nc_rows(n) }} g
{% endmacro %}
