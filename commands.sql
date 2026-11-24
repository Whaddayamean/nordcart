{#
  Data commands. Run them with any dbt (CLI or dbt platform IDE), e.g.

    dbt run-operation nc_init   --args '{scale: small}'
    dbt run-operation nc_tick   --args '{cadence: hourly}'           # hourly | daily | weekly | all, comma lists ok
    dbt run-operation nc_mutate --args '{op: silent_update, table: customers, pct: 1}'
    dbt run-operation nc_stats

  The raw layer lives in <nc_raw_database>.<nc_raw_schema> (default: target database, schema
  `nordcart_raw`) and is SHARED by every tool/schema you build from it.
  Add --vars '{nc_dry_run: true}' to print the SQL instead of running it.
#}

{% macro nc_tables() %}
    {{ return(['orders', 'order_items', 'payments', 'web_events', 'customers', 'inventory_snapshots',
               'fx_rates', 'products', 'marketing_spend', 'support_tickets', 'legacy_store_sales']) }}
{% endmacro %}

{% macro nc_meta() %}
    {% set res = run_query("select scale, tick, biz_hours from " ~ nc_rel('nc_meta')) %}
    {% set row = res.rows[0] %}
    {{ return({'scale': row[0], 'tick': row[1] | int, 'biz_hours': row[2] | int}) }}
{% endmacro %}

{% macro nc_date_after(days) -%}
    {{- (modules.datetime.date(2025, 1, 1) + modules.datetime.timedelta(days=days)).isoformat() -}}
{%- endmacro %}

{# ------------------------------------------------------------------------------------- init #}
{% macro nc_init(scale='small') %}
    {% set S = nc_scales()[scale] %}
    {% set days = S.days %}
    {{ log("nc_init: scale=" ~ scale ~ " -> " ~ nc_raw_database() ~ "." ~ nc_raw_schema(), info=True) }}
    {% if not var('nc_dry_run', false) %}
        {% do adapter.create_schema(api.Relation.create(database=nc_raw_database(), schema=nc_raw_schema())) %}
    {% endif %}
    {% set ctas = "create or replace table " %}
    {{ nc_exec(ctas ~ nc_rel('nc_meta') ~ " as select '" ~ scale ~ "' as scale, 0 as tick, " ~ (days * 24) ~ " as biz_hours", 'nc_meta') }}
    {{ nc_exec(ctas ~ nc_rel('customers') ~ " as " ~ nc_sel_customers(1, S.customers, dbt.dateadd('day', -700, nc_start()), (700 + days) * 86400), 'customers') }}
    {{ nc_exec(ctas ~ nc_rel('products') ~ " as " ~ nc_sel_products(1, S.products), 'products') }}
    {{ nc_exec(ctas ~ nc_rel('orders') ~ " as " ~ nc_sel_orders(1, S.orders, 0, days * 86400, S.customers), 'orders') }}
    {{ nc_exec(ctas ~ nc_rel('order_items') ~ " as " ~ nc_sel_order_items(0, 1, S.products), 'order_items') }}
    {{ nc_exec(ctas ~ nc_rel('payments') ~ " as " ~ nc_sel_payments(0, 1), 'payments') }}
    {{ nc_exec(ctas ~ nc_rel('web_events') ~ " as " ~ nc_sel_web_events(1, S.events, 0, days * 86400, S.customers, S.products), 'web_events') }}
    {{ nc_exec(ctas ~ nc_rel('inventory_snapshots') ~ " as " ~ nc_sel_inventory(nc_date_after(days - 30), 30, S.products), 'inventory_snapshots') }}
    {{ nc_exec(ctas ~ nc_rel('fx_rates') ~ " as " ~ nc_sel_fx(nc_date_after(0), days), 'fx_rates') }}
    {{ nc_exec(ctas ~ nc_rel('marketing_spend') ~ " as " ~ nc_sel_marketing(nc_date_after(0), days), 'marketing_spend') }}
    {{ nc_exec(ctas ~ nc_rel('support_tickets') ~ " as " ~ nc_sel_support_tickets((S.customers / 6) | int, S.customers, days * 86400), 'support_tickets') }}
    {{ nc_exec(ctas ~ nc_rel('legacy_store_sales') ~ " as " ~ nc_sel_legacy((S.orders / 2) | int, S.products), 'legacy_store_sales') }}
    {% do nc_commit() %}
    {% if not var('nc_dry_run', false) %}{{ nc_stats() }}{% endif %}
{% endmacro %}

{# ------------------------------------------------------------------------------------- tick #}
{#  hourly : `hours` business hours of orders, order_items, payments, web_events
    daily  : one new business day of customers, inventory_snapshots, fx_rates
    weekly : one new week of marketing_spend + a batch of new products
    support_tickets and legacy_store_sales never change (use nc_mutate to disturb them). #}
{% macro nc_tick(cadence='hourly', hours=1, volume=1) %}
    {% set M = nc_meta() %}
    {% set S = nc_scales()[M.scale] %}
    {% set cad = cadence.split(',') | map('trim') | list %}
    {% if 'all' in cad %}{% set cad = ['hourly', 'daily', 'weekly'] %}{% endif %}
    {% set n_customers = nc_scalar("select max(customer_id) from " ~ nc_rel('customers')) | int %}
    {% set n_products = nc_scalar("select max(product_id) from " ~ nc_rel('products')) | int %}
    {% set done = [] %}

    {% if 'weekly' in cad %}
        {% set n = [1, (S.products * 0.5 / S.days * 7) | int] | max %}
        {{ nc_exec("insert into " ~ nc_rel('products') ~ " " ~ nc_sel_products(n_products + 1, n)) }}
        {% set n_products = n_products + n %}
        {% set last = nc_scalar("select max(spend_date) from " ~ nc_rel('marketing_spend')) %}
        {{ nc_exec("insert into " ~ nc_rel('marketing_spend') ~ " " ~ nc_sel_marketing((last + modules.datetime.timedelta(days=1)).isoformat(), 7)) }}
        {% do done.append('products +' ~ n ~ ', marketing_spend +7 days') %}
    {% endif %}

    {% if 'daily' in cad %}
        {% set n = [1, (S.customers * 0.6 / S.days) | int] | max %}
        {{ nc_exec("insert into " ~ nc_rel('customers') ~ " " ~ nc_sel_customers(n_customers + 1, n, dbt.dateadd('hour', M.biz_hours, nc_start()), 86400)) }}
        {% set n_customers = n_customers + n %}
        {% set last_inv = nc_scalar("select max(snapshot_date) from " ~ nc_rel('inventory_snapshots')) %}
        {{ nc_exec("insert into " ~ nc_rel('inventory_snapshots') ~ " " ~ nc_sel_inventory((last_inv + modules.datetime.timedelta(days=1)).isoformat(), 1, n_products)) }}
        {% set last_fx = nc_scalar("select max(rate_date) from " ~ nc_rel('fx_rates')) %}
        {{ nc_exec("insert into " ~ nc_rel('fx_rates') ~ " " ~ nc_sel_fx((last_fx + modules.datetime.timedelta(days=1)).isoformat(), 1)) }}
        {% do done.append('customers +' ~ n ~ ', inventory_snapshots +1 day, fx_rates +1 day') %}
    {% endif %}

    {% set biz_hours = M.biz_hours %}
    {% if 'hourly' in cad %}
        {% set per_hour = (S.orders / (S.days * 24) * hours * volume) | int %}
        {% set n_orders = [1, per_hour] | max %}
        {% set n_events = [1, (S.events / (S.days * 24) * hours * volume) | int] | max %}
        {% set max_order = nc_scalar("select max(order_id) from " ~ nc_rel('orders')) | int %}
        {% set max_item = nc_scalar("select max(order_item_id) from " ~ nc_rel('order_items')) | int %}
        {% set max_pay = nc_scalar("select max(payment_id) from " ~ nc_rel('payments')) | int %}
        {% set max_event = nc_scalar("select max(event_id) from " ~ nc_rel('web_events')) | int %}
        {% set offset_s = biz_hours * 3600 %}
        {% set span_s = (hours * 3600) | int %}
        {{ nc_exec("insert into " ~ nc_rel('orders') ~ " " ~ nc_sel_orders(max_order + 1, n_orders, offset_s, span_s, n_customers)) }}
        {{ nc_exec("insert into " ~ nc_rel('order_items') ~ " " ~ nc_sel_order_items(max_order, max_item + 1, n_products)) }}
        {{ nc_exec("insert into " ~ nc_rel('payments') ~ " " ~ nc_sel_payments(max_order, max_pay + 1)) }}
        {{ nc_exec("insert into " ~ nc_rel('web_events') ~ " " ~ nc_sel_web_events(max_event + 1, n_events, offset_s, span_s, n_customers, n_products)) }}
        {% set biz_hours = biz_hours + (hours | int) %}
        {% do done.append('orders +' ~ n_orders ~ ' (+items, payments), web_events +' ~ n_events) %}
    {% endif %}

    {{ nc_exec("update " ~ nc_rel('nc_meta') ~ " set tick = tick + 1, biz_hours = " ~ biz_hours) }}
    {% do nc_commit() %}
    {{ log("nc_tick " ~ (M.tick + 1) ~ " [" ~ cad | join(',') ~ "]: " ~ done | join('; '), info=True) }}
{% endmacro %}

{# ----------------------------------------------------------------------------------- mutate #}
{#  silent_update   UPDATE rows, _loaded_at untouched
    update_with_ts  UPDATE rows and set _loaded_at = now
    delete          DELETE rows (orders: also their items and payments)
    late_arrival    orders only: re-insert copies with NEW ids but a 30-days-old _loaded_at
    add_column      ALTER TABLE ... ADD COLUMN loyalty_tier
    truncate_reload delete everything and insert the identical rows again #}
{% macro nc_mutate(op, table, pct=1) %}
    {% set M = nc_meta() %}
    {% set keys = {
        'customers': 'customer_id', 'products': 'product_id', 'orders': 'order_id',
        'order_items': 'order_item_id', 'payments': 'payment_id', 'web_events': 'event_id',
        'support_tickets': 'ticket_id', 'legacy_store_sales': 'sale_id',
        'fx_rates': 'rate_date, currency', 'marketing_spend': 'spend_date, campaign_id',
        'inventory_snapshots': 'snapshot_date, warehouse_id, product_id'} %}
    {% set setters = {
        'customers': "segment = case when segment = 'consumer' then 'consumer_plus' else 'consumer' end, email = replace(email, '@example.com', '@example.org')",
        'products': 'list_price_cents = cast(list_price_cents * 107 / 100 as bigint)',
        'orders': "status = case when status = 'shipped' then 'completed' else 'returned' end",
        'order_items': 'quantity = quantity + 1',
        'payments': "status = 'refunded'",
        'web_events': "event_type = 'search'",
        'support_tickets': 'csat = 1',
        'legacy_store_sales': 'revenue_cents = revenue_cents + 100',
        'fx_rates': 'rate_to_eur = rate_to_eur * 1.01',
        'marketing_spend': 'spend_cents = spend_cents * 2',
        'inventory_snapshots': 'on_hand_qty = 0'} %}
    {% if table not in keys %}{{ exceptions.raise_compiler_error("unknown table " ~ table) }}{% endif %}
    {% set m = [2, (100 / pct) | round | int] | max %}
    {% set salt = 'mut' ~ M.tick %}
    {% set pred = nc_rand(keys[table], salt, m) ~ ' = 0' %}
    {% set rel = nc_rel(table) %}
    {% set before = run_query("select count(*), max(_loaded_at) from " ~ rel).rows[0] %}

    {% if op == 'silent_update' %}
        {{ nc_exec("update " ~ rel ~ " set " ~ setters[table] ~ " where " ~ pred) }}
    {% elif op == 'update_with_ts' %}
        {{ nc_exec("update " ~ rel ~ " set " ~ setters[table] ~ ", _loaded_at = " ~ nc_now() ~ " where " ~ pred) }}
    {% elif op == 'delete' %}
        {% if table == 'orders' %}
            {% set opred = nc_rand('order_id', salt, m) ~ ' = 0' %}
            {{ nc_exec("delete from " ~ nc_rel('payments') ~ " where " ~ opred) }}
            {{ nc_exec("delete from " ~ nc_rel('order_items') ~ " where " ~ opred) }}
        {% endif %}
        {{ nc_exec("delete from " ~ rel ~ " where " ~ pred) }}
    {% elif op == 'late_arrival' %}
        {% if table != 'orders' %}{{ exceptions.raise_compiler_error("late_arrival is implemented for orders") }}{% endif %}
        {% set off_o = nc_scalar("select max(order_id) from " ~ rel) | int %}
        {% set off_i = nc_scalar("select max(order_item_id) from " ~ nc_rel('order_items')) | int %}
        {% set off_p = nc_scalar("select max(payment_id) from " ~ nc_rel('payments')) | int %}
        {% set opred = nc_rand('order_id', salt, m) ~ ' = 0' %}
        {% set old = dbt.dateadd('day', -30, '_loaded_at') %}
        {{ nc_exec("insert into " ~ rel ~ " select order_id + " ~ off_o ~ ", customer_id, order_ts, status, channel_code, ship_country, currency, shipping_cents, discount_cents, " ~ old ~ " from " ~ rel ~ " where " ~ opred) }}
        {{ nc_exec("insert into " ~ nc_rel('order_items') ~ " select order_item_id + " ~ off_i ~ ", order_id + " ~ off_o ~ ", product_id, quantity, unit_price_cents, " ~ old ~ " from " ~ nc_rel('order_items') ~ " where order_id <= " ~ off_o ~ " and " ~ opred) }}
        {{ nc_exec("insert into " ~ nc_rel('payments') ~ " select payment_id + " ~ off_p ~ ", order_id + " ~ off_o ~ ", payment_method, amount_cents, currency, paid_ts, status, " ~ old ~ " from " ~ nc_rel('payments') ~ " where order_id <= " ~ off_o ~ " and " ~ opred) }}
    {% elif op == 'add_column' %}
        {% if target.type in ('databricks', 'spark') %}
            {{ nc_exec("alter table " ~ rel ~ " add columns (loyalty_tier string)") }}
        {% else %}
            {{ nc_exec("alter table " ~ rel ~ " add column loyalty_tier varchar") }}
        {% endif %}
    {% elif op == 'truncate_reload' %}
        {% set tmp = nc_rel(table ~ '_nc_tmp') %}
        {{ nc_exec("create or replace table " ~ tmp ~ " as select * from " ~ rel) }}
        {{ nc_exec("delete from " ~ rel ~ " where 1 = 1") }}
        {{ nc_exec("insert into " ~ rel ~ " select * from " ~ tmp) }}
        {{ nc_exec("drop table " ~ tmp) }}
    {% else %}
        {{ exceptions.raise_compiler_error("unknown op " ~ op) }}
    {% endif %}

    {{ nc_exec("update " ~ nc_rel('nc_meta') ~ " set tick = tick + 1") }}
    {% do nc_commit() %}
    {% set after = run_query("select count(*), max(_loaded_at) from " ~ rel).rows[0] %}
    {{ log("nc_mutate " ~ op ~ " on " ~ table ~ " (~" ~ pct ~ "% of rows): rows " ~ before[0] ~ " -> " ~ after[0]
           ~ ", max(_loaded_at) " ~ before[1] ~ " -> " ~ after[1], info=True) }}
{% endmacro %}

{# ------------------------------------------------------------------------------------ stats #}
{% macro nc_stats() %}
    {% set M = nc_meta() %}
    {{ log("raw layer " ~ nc_raw_database() ~ "." ~ nc_raw_schema() ~ "  scale=" ~ M.scale ~ "  tick=" ~ M.tick, info=True) }}
    {% set parts = [] %}
    {% for t in nc_tables() %}
        {% do parts.append("select '" ~ t ~ "' as tbl, " ~ loop.index ~ " as ord, count(*) as n, max(_loaded_at) as max_loaded_at from " ~ nc_rel(t)) %}
    {% endfor %}
    {% set res = run_query("select tbl, n, max_loaded_at from (" ~ parts | join(' union all ') ~ ") x order by ord") %}
    {% for r in res.rows %}
        {{ log("  " ~ r[0] ~ ": " ~ (r[1] | int) ~ " rows, max(_loaded_at) = " ~ r[2], info=True) }}
    {% endfor %}
{% endmacro %}
