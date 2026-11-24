{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='session_id',
    on_schema_change='append_new_columns'
) }}
-- HEAVY model: sessionisation of the clickstream with window functions.
-- Sessions never cross midnight, so re-processing whole days (1-day lookback) is idempotent.
with ev as (
    select * from {{ ref('stg_web_events') }}
    {% if is_incremental() %}
    where event_date >= (select {{ dbt.dateadd('day', -1, 'max(session_date)') }} from {{ this }})
    {% endif %}
),
prev as (
    select
        *,
        lag(event_ts) over (partition by anonymous_id, event_date order by event_ts, event_id) as prev_event_ts
    from ev
),
gaps as (
    select
        *,
        case
            when prev_event_ts is null then 1
            when {{ dbt.datediff('prev_event_ts', 'event_ts', 'minute') }} > 30 then 1
            else 0
        end as is_new_session
    from prev
),
numbered as (
    select *, sum(is_new_session) over (partition by anonymous_id, event_date order by event_ts, event_id
                                        rows between unbounded preceding and current row) as session_seq
    from gaps
)
select
    concat(anonymous_id, '-', cast(event_date as {{ dbt.type_string() }}), '-', cast(session_seq as {{ dbt.type_string() }})) as session_id,
    anonymous_id,
    max(customer_id)                                                      as customer_id,
    min(event_date)                                                       as session_date,
    min(event_ts)                                                         as session_start,
    max(event_ts)                                                         as session_end,
    count(*)                                                              as events,
    sum(case when event_type = 'product_view' then 1 else 0 end)          as product_views,
    sum(case when event_type = 'add_to_cart' then 1 else 0 end)           as add_to_carts,
    sum(case when event_type = 'checkout_start' then 1 else 0 end)        as checkouts,
    sum(case when event_type = 'purchase' then 1 else 0 end)              as purchases,
    min(channel_code)                                                     as channel_code,
    min(utm_source)                                                       as utm_source,
    min(device)                                                           as device
from numbered
group by anonymous_id, event_date, session_seq
