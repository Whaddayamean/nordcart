select
    i.*,
    i.line_amount_eur - i.line_cost_eur as line_margin_eur
from {{ ref('int_order_items_enriched') }} i
