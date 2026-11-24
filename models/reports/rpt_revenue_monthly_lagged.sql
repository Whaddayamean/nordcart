{{ config(state={'lag_tolerance': '1d'}) }}
-- lag_tolerance = 1 day: even when fct_daily_revenue has new data, this model may be
-- reused until its last build is more than a day old.
select
    {{ dbt.date_trunc('month', 'order_date') }}   as month_start,
    sum(orders)                                   as orders,
    sum(net_amount)                               as net_amount
from {{ ref('fct_daily_revenue') }}
group by {{ dbt.date_trunc('month', 'order_date') }}
