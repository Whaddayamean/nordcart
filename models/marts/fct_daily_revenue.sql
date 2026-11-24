select
    order_date,
    country_code,
    channel_code,
    count(distinct order_id)                                   as orders,
    sum(gross_eur)                                             as gross_eur,
    sum(discount_eur)                                          as discount_eur,
    sum(gross_eur - discount_eur)                              as net_revenue_eur,
    sum(gross_eur - cost_eur)                                  as gross_margin_eur
from {{ ref('int_orders_enriched') }}
where is_revenue
group by 1, 2, 3
