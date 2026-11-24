{{ config(materialized='view') }}
select d.order_date, c.region, c.country_name, sum(d.net_revenue_eur) as net_revenue_eur
from {{ ref('fct_daily_revenue') }} d
left join {{ ref('country_codes') }} c using (country_code)
group by 1, 2, 3
