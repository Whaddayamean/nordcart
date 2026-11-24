-- downstream of the `select *` passthrough view
select country_code, status, count(*) as orders, min(order_ts) as oldest_order_ts
from {{ ref('stg_orders_passthrough') }}
where status in ('processing', 'shipped')
group by 1, 2
