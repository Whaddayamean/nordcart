select
    customer_id,
    count(*)                                                     as orders,
    sum(case when is_revenue then 1 else 0 end)                  as revenue_orders,
    sum(case when is_revenue then gross_eur - discount_eur else 0 end) as net_revenue_eur,
    sum(case when is_revenue then gross_eur - cost_eur else 0 end)     as gross_margin_eur,
    min(order_date)                                              as first_order_date,
    max(order_date)                                              as last_order_date
from {{ ref('int_orders_enriched') }}
group by 1
