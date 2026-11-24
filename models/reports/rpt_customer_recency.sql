-- EDGE CASE: volatile SQL (current_date). The result changes every day even if no data changes.
select
    customer_id,
    last_order_date,
    {{ dbt.datediff('last_order_date', 'current_date', 'day') }} as days_since_last_order,
    case
        when {{ dbt.datediff('last_order_date', 'current_date', 'day') }} <= 90 then 'active'
        when {{ dbt.datediff('last_order_date', 'current_date', 'day') }} <= 365 then 'lapsing'
        else 'churned'
    end as recency_bucket
from {{ ref('fct_customer_ltv') }}
