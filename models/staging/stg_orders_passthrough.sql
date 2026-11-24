-- EDGE CASE: `select *` over a ref(). dbt State's docs say it rebuilds such views because it
-- can't resolve the column list without querying the upstream schema. How does hodor treat it?
select * from {{ ref('stg_orders') }}
