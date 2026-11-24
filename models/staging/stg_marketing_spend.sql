select
    cast(spend_date as date)           as spend_date,
    channel_code                       as marketing_channel,
    campaign_id,
    spend_cents,
    impressions,
    clicks,
    _loaded_at
from {{ source('raw', 'marketing_spend') }}
