-- frozen legacy history UNION live online sales
with legacy as (
    select {{ dbt.date_trunc('month', 'sale_date') }} as month_start, 'legacy_pos' as source_system,
           sum(revenue_cents) / 100.0 as revenue_local
    from {{ ref('stg_legacy_store_sales') }} group by 1, 2
),
online as (
    select {{ dbt.date_trunc('month', 'order_date') }} as month_start, 'online' as source_system,
           sum(net_revenue_eur) as revenue_local
    from {{ ref('fct_daily_revenue') }} group by 1, 2
)
select * from legacy
union all
select * from online
