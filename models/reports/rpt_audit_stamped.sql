-- EDGE CASE (very common anti-pattern): run metadata baked into compiled SQL.
-- '{{ invocation_id }}' differs on every invocation, so the compiled SQL hash changes on
-- every run. How does each tool treat that?
select
    order_date,
    sum(net_revenue_eur)                   as net_revenue_eur,
    '{{ invocation_id }}'                  as dbt_invocation_id,
    cast('{{ run_started_at }}' as {{ dbt.type_timestamp() }}) as dbt_run_started_at
from {{ ref('fct_daily_revenue') }}
group by 1
