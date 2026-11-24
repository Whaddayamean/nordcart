{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='order_id',
    on_schema_change='append_new_columns'
) }}
-- Incremental model with a "high-watermark" on _loaded_at: each run only merges orders loaded
-- after the newest one already in the table. On its own, this pattern ignores silent updates,
-- deletes and late-arriving rows, with or without a state tool. Compare against the
-- --full-refresh reference to tell the model's behaviour apart from the tools' behaviour.
select *
from {{ ref('int_orders_enriched') }}
{% if is_incremental() %}
where _loaded_at > (select max(_loaded_at) from {{ this }})
{% endif %}
