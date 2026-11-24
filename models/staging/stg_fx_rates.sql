select
    cast(rate_date as date)            as rate_date,
    currency,
    rate_to_eur,
    _loaded_at
from {{ source('raw', 'fx_rates') }}
