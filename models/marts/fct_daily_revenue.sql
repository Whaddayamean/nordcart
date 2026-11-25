select
    order_date,
    country_code,
    count(*)                                   as orders,
    sum(units)                                 as units,
    sum(gross_amount)                          as gross_amount,
    sum(discount_amount)                       as discount_amount,
    sum(gross_amount - discount_amount)        as net_amount,
    sum(gross_amount - cost_amount)            as gross_margin,
    avg(gross_amount)                        as avg_order_amount
from {{ ref('int_orders_enriched') }}
where is_revenue
group by order_date, country_code
