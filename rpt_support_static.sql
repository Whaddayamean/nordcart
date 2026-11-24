-- depends ONLY on the dormant source: the purest "should never rebuild" case
select category, priority, count(*) as tickets, avg(csat) as avg_csat
from {{ ref('stg_support_tickets') }}
group by 1, 2
