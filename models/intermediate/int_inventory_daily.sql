{{ config(
    materialized='incremental',
    incremental_strategy='append'
) }}
-- append-only incremental: new snapshot days only
select
    snapshot_date,
    product_id,
    sum(on_hand_qty)    as on_hand_qty,
    sum(reserved_qty)   as reserved_qty,
    sum(available_qty)  as available_qty,
    count(*)            as warehouses
from {{ ref('stg_inventory_snapshots') }}
{% if is_incremental() %}
where snapshot_date > (select max(snapshot_date) from {{ this }})
{% endif %}
group by 1, 2
