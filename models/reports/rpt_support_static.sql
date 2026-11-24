-- Reads only the dormant support_tickets source, which never changes.
select category, priority, count(*) as tickets, avg(csat) as avg_csat
from {{ ref('stg_support_tickets') }}
group by category, priority
