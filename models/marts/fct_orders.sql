{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='order_id',
    on_schema_change='append_new_columns'
) }}
-- Classic "high-watermark on _loaded_at" incremental. This pattern by itself ignores silent
-- updates, deletes and late arrivals, with or without a state tool; build a --full-refresh
-- reference (`./demo build reference`) to tell incremental behaviour apart from tool behaviour.
select
    e.*,
    ch.channel_group,
    ch.is_digital
from {{ ref('int_orders_enriched') }} e
left join {{ ref('dim_channels') }} ch using (channel_code)
{% if is_incremental() %}
where e._loaded_at > (select max(_loaded_at) from {{ this }})
{% endif %}
