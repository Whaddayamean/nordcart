select
    event_id,
    anonymous_id,
    customer_id,
    cast(event_ts as timestamp)        as event_ts,
    cast(event_ts as date)             as event_date,
    event_type,
    page_path,
    channel_code,
    utm_source,
    device,
    _loaded_at
from {{ source('raw', 'web_events') }}
