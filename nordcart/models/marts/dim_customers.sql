with c as (select * from {{ ref('stg_customers') }}),
s as (select * from {{ ref('int_customer_order_stats') }}),
cc as (select * from {{ ref('country_codes') }})
select
    c.customer_id,
    concat(c.first_name, ' ', c.last_name)     as full_name,
    c.email,
    c.country_code,
    cc.country_name,
    cc.region,
    c.segment,
    c.signup_ts,
    c.is_active,
    coalesce(s.orders, 0)                       as lifetime_orders,
    coalesce(s.net_revenue_eur, 0)              as lifetime_net_revenue_eur,
    s.first_order_date,
    s.last_order_date
from c
left join s using (customer_id)
left join cc using (country_code)
