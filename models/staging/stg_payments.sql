select
    payment_id,
    order_id,
    payment_method,
    amount_cents,
    currency,
    cast(paid_ts as timestamp)         as paid_ts,
    status,
    _loaded_at
from {{ source('raw', 'payments') }}
