-- singular test: no order may have negative gross value or units
select order_id
from {{ ref('fct_orders') }}
where gross_eur < 0 or units < 0
