{{ config(state={'lag_tolerance': '1d'}) }}
-- EDGE CASE: lag_tolerance of 1 day. Upstream inventory changes daily but planners only
-- need this once a day, so intra-day runs should reuse it.
with inv as (
    select * from {{ ref('int_inventory_daily') }}
    where snapshot_date = (select max(snapshot_date) from {{ ref('int_inventory_daily') }})
),
sold as (
    select product_id, sum(quantity) / 28.0 as avg_daily_units
    from {{ ref('fct_order_items') }}
    where order_date >= (select {{ dbt.dateadd('day', -28, 'max(order_date)') }} from {{ ref('fct_order_items') }})
    group by 1
)
select
    inv.snapshot_date,
    inv.product_id,
    p.category,
    inv.available_qty,
    coalesce(s.avg_daily_units, 0)                                       as avg_daily_units,
    round(inv.available_qty / nullif(s.avg_daily_units, 0), 1)           as days_of_cover,
    case when inv.available_qty / nullif(s.avg_daily_units, 0) < 7 then 'reorder' else 'ok' end as stock_status
from inv
left join sold s using (product_id)
left join {{ ref('dim_products') }} p using (product_id)
