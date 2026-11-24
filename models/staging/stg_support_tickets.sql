-- dormant source: loaded once, never changes -> ideal reuse candidate
select
    ticket_id,
    customer_id,
    cast(opened_ts as timestamp)       as opened_ts,
    cast(closed_ts as timestamp)       as closed_ts,
    priority,
    category,
    csat
from {{ source('raw', 'support_tickets') }}
