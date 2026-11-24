{{ config(state={'require_fresh_data_from': 'all'}) }}
-- EDGE CASE: require_fresh_data_from = all.
-- Only rebuilds when BOTH marketing spend AND web sessions have new data.
with spend as (select * from {{ ref('int_marketing_daily') }}),
sess as (
    select session_date, utm_source as marketing_channel,
           count(*) as sessions, sum(case when purchases > 0 then 1 else 0 end) as converting_sessions
    from {{ ref('int_web_sessions') }}
    group by 1, 2
)
select
    s.spend_date,
    s.marketing_channel,
    s.spend_eur,
    s.impressions,
    s.clicks,
    coalesce(x.sessions, 0)                                         as sessions,
    coalesce(x.converting_sessions, 0)                              as converting_sessions,
    round(s.spend_eur / nullif(x.converting_sessions, 0), 2)        as cost_per_conversion_eur
from spend s
left join sess x on x.session_date = s.spend_date and x.marketing_channel = s.marketing_channel
