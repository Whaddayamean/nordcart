-- Run metadata baked into the SQL: '{{ invocation_id }}' differs on every run, so the
-- compiled SQL changes every time even though the logic does not.
select
    order_date,
    sum(net_amount)                                              as net_amount,
    '{{ invocation_id }}'                                        as dbt_invocation_id,
    cast('{{ run_started_at }}' as {{ dbt.type_timestamp() }})   as dbt_run_started_at
from {{ ref('fct_daily_revenue') }}
group by order_date
