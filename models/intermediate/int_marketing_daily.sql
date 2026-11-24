{{ config(materialized='view') }}
select
    spend_date,
    marketing_channel,
    sum(spend_cents) / 100.0   as spend_eur,
    sum(impressions)           as impressions,
    sum(clicks)                as clicks
from {{ ref('stg_marketing_spend') }}
group by 1, 2
