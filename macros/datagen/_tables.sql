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
