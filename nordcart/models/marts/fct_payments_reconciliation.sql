select
    o.order_date,
    o.currency,
    count(*)                                                   as orders,
    sum(case when o.captured_cents = 0 and o.is_revenue then 1 else 0 end) as unpaid_revenue_orders,
    sum(o.captured_cents) / 100.0                              as captured_local,
    sum(o.refunded_cents) / 100.0                              as refunded_local
from {{ ref('int_orders_enriched') }} o
group by 1, 2
