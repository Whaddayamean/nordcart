select
    cast(snapshot_date as date)        as snapshot_date,
    warehouse_id,
    product_id,
    on_hand_qty,
    reserved_qty,
    on_hand_qty - reserved_qty         as available_qty,
    _loaded_at
from {{ source('raw', 'inventory_snapshots') }}
