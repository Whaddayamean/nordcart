-- fan-in report with many parents: rebuilt whenever ANY hourly source changes
with rev as (
    select order_date as d, sum(net_revenue_eur) as net_revenue_eur, sum(orders) as orders
    from {{ ref('fct_daily_revenue') }} group by 1
),
web as (
    select session_date as d, sum(sessions) as sessions, sum(sessions_with_purchase) as converting_sessions
    from {{ ref('fct_web_funnel_daily') }} group by 1
),
mkt as (
    select spend_date as d, sum(spend_eur) as spend_eur from {{ ref('fct_marketing_roas') }} group by 1
),
cust as (
    select cast(signup_ts as date) as d, count(*) as new_customers from {{ ref('dim_customers') }} group by 1
)
select
    rev.d                                                         as kpi_date,
    rev.net_revenue_eur,
    rev.orders,
    web.sessions,
    web.converting_sessions,
    round(web.converting_sessions * 1.0 / nullif(web.sessions, 0), 4) as conversion_rate,
    mkt.spend_eur,
    round(rev.net_revenue_eur / nullif(mkt.spend_eur, 0), 2)     as roas,
    coalesce(cust.new_customers, 0)                               as new_customers
from rev
left join web using (d)
left join mkt using (d)
left join cust using (d)
