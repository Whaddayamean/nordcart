{{ config(materialized='view') }}
-- daily FX plus a "latest known rate" fallback per currency
with r as (select * from {{ ref('stg_fx_rates') }}),
latest as (
    select currency, rate_to_eur as latest_rate_to_eur
    from (
        select currency, rate_to_eur,
               row_number() over (partition by currency order by rate_date desc) as rn
        from r
    ) x
    where rn = 1
)
select r.rate_date, r.currency, r.rate_to_eur, l.latest_rate_to_eur
from r join latest l using (currency)
