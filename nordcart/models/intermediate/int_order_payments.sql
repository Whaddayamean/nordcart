{{ config(materialized='view') }}
select
    order_id,
    count(*)                                                              as payment_count,
    sum(case when status = 'captured' then amount_cents else 0 end)       as captured_cents,
    sum(case when status = 'refunded' then amount_cents else 0 end)       as refunded_cents,
    min(paid_ts)                                                          as first_paid_ts,
    max(_loaded_at)                                                       as payments_loaded_at
from {{ ref('stg_payments') }}
group by 1
