-- downstream of the stamped model: collateral damage of the anti-pattern
select {{ dbt.date_trunc('month', 'order_date') }} as month_start, sum(net_revenue_eur) as net_revenue_eur
from {{ ref('rpt_audit_stamped') }}
group by 1
