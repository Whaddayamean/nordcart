with c as (select * from {{ ref('stg_customers') }}),
stats as (
    select
        customer_id,
        count(*)                                                         as lifetime_orders,
        sum(case when is_revenue then gross_amount - discount_amount else 0 end) as lifetime_net_amount,
        min(order_date)                                                  as first_order_date,
        max(order_date)                                                  as last_order_date
    from {{ ref('int_orders_enriched') }}
    group by customer_id
),
cc as (select * from {{ ref('country_codes') }})
select
    c.customer_id,
    concat(c.first_name, ' ', c.last_name)   as full_name,
    c.email,
    c.country_code,
    cc.country_name,
    cc.region,
    c.segment,
    c.signup_ts,
    c.is_active,
    coalesce(stats.lifetime_orders, 0)        as lifetime_orders,
    coalesce(stats.lifetime_net_amount, 0)    as lifetime_net_amount,
    stats.first_order_date,
    stats.last_order_date
from c
left join stats using (customer_id)
left join cc using (country_code)
