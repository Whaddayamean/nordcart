-- depends ONLY on the dormant support_tickets source (+ a dim): should be reused forever
-- unless dim_customers changes.
select
    t.category,
    t.priority,
    c.segment,
    count(*)                                                          as tickets,
    avg(t.csat)                                                       as avg_csat,
    avg({{ dbt.datediff('t.opened_ts', 't.closed_ts', 'hour') }})     as avg_hours_to_close
from {{ ref('stg_support_tickets') }} t
left join {{ ref('dim_customers') }} c using (customer_id)
group by 1, 2, 3
