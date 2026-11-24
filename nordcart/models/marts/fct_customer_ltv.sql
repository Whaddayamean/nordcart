-- moderately heavy: per-customer window aggregates over the full order history
with o as (
    select customer_id, order_id, order_date, gross_eur - discount_eur as net_eur
    from {{ ref('int_orders_enriched') }}
    where is_revenue
),
seq as (
    select *,
        row_number() over (partition by customer_id order by order_date, order_id) as order_seq,
        sum(net_eur) over (partition by customer_id order by order_date, order_id
                           rows between unbounded preceding and current row)   as running_net_eur,
        lag(order_date) over (partition by customer_id order by order_date, order_id) as prev_order_date
    from o
)
select
    customer_id,
    max(order_seq)                                                   as revenue_orders,
    max(running_net_eur)                                             as ltv_eur,
    avg({{ dbt.datediff('prev_order_date', 'order_date', 'day') }})  as avg_days_between_orders,
    min(order_date)                                                  as first_order_date,
    max(order_date)                                                  as last_order_date,
    max(case when order_seq = 2 then {{ dbt.datediff('prev_order_date', 'order_date', 'day') }} end) as days_to_second_order
from seq
group by 1
