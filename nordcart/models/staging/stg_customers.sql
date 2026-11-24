select
    customer_id,
    first_name,
    last_name,
    lower(email)                       as email,
    upper(country_code)                as country_code,
    segment,
    cast(signup_ts as timestamp)       as signup_ts,
    is_active,
    _loaded_at
from {{ source('raw', 'customers') }}
