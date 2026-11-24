select
    session_date,
    channel_code,
    device,
    count(*)                                              as sessions,
    sum(case when product_views > 0 then 1 else 0 end)    as sessions_with_view,
    sum(case when add_to_carts > 0 then 1 else 0 end)     as sessions_with_cart,
    sum(case when checkouts > 0 then 1 else 0 end)        as sessions_with_checkout,
    sum(case when purchases > 0 then 1 else 0 end)        as sessions_with_purchase
from {{ ref('int_web_sessions') }}
group by 1, 2, 3
