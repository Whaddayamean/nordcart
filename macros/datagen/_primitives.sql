{#
  Cross-warehouse primitives for the in-warehouse data generator.
  Supported: snowflake, databricks, duckdb. Everything is deterministic: "random" values are
  hashes of the row's id plus a salt, so re-running the same command yields the same data.
#}

{% macro nc_raw_database() -%}
    {{- var('nc_raw_database', target.database) -}}
{%- endmacro %}

{% macro nc_raw_schema() -%}
    {{- var('nc_raw_schema', 'nordcart_raw') -}}
{%- endmacro %}

{% macro nc_rel(table) -%}
    {{- nc_raw_database() }}.{{ nc_raw_schema() }}.{{ table -}}
{%- endmacro %}

{# integer in [0, m) derived from a hash of `expr` (any comma-separated list of SQL expressions) #}
{% macro nc_rand(expr, salt, m) -%}
    {%- if target.type == 'snowflake' -%}
        mod(abs(hash({{ expr }}, '{{ salt }}')), {{ m }})
    {%- elif target.type in ('databricks', 'spark') -%}
        pmod(hash({{ expr }}, '{{ salt }}'), {{ m }})
    {%- else -%}
        cast(hash({{ expr }}, '{{ salt }}') % {{ m }} as bigint)
    {%- endif -%}
{%- endmacro %}

{# pick one of `values` (repeat a value to weight it). Strings are quoted, numbers are not. #}
{% macro nc_pick(expr, salt, values) -%}
    case {{ nc_rand(expr, salt, values | length) }}
    {%- for v in values %} when {{ loop.index0 }} then {% if v is number %}{{ v }}{% else %}'{{ v }}'{% endif %}{% endfor %} end
{%- endmacro %}

{# a derived table with one column `i` = 0 .. n-1 #}
{% macro nc_rows(n) -%}
    {%- if target.type == 'snowflake' -%}
        (select row_number() over (order by seq8()) - 1 as i from table(generator(rowcount => {{ n }})))
    {%- elif target.type in ('databricks', 'spark') -%}
        (select id as i from range({{ n }}))
    {%- else -%}
        (select range as i from range({{ n }}))
    {%- endif -%}
{%- endmacro %}

{% macro nc_ts(literal) -%}
    cast('{{ literal }}' as {{ dbt.type_timestamp() }})
{%- endmacro %}

{% macro nc_now() -%}
    cast({{ dbt.current_timestamp() }} as {{ dbt.type_timestamp() }})
{%- endmacro %}

{# business clock origin: every generated order/event timestamp is START + n seconds #}
{% macro nc_start() -%}{{ nc_ts('2025-01-01 00:00:00') }}{%- endmacro %}

{% macro nc_scalar(sql) -%}
    {%- set res = run_query(sql) -%}
    {{- return(res.columns[0].values()[0]) -}}
{%- endmacro %}

{% macro nc_exec(sql, label=none) %}
    {% if label %}{{ log("  " ~ label, info=True) }}{% endif %}
    {% if var('nc_dry_run', false) %}
        {{ print(sql ~ ";") }}
    {% else %}
        {% do run_query(sql) %}
    {% endif %}
{% endmacro %}

{% macro nc_scales() %}
    {{ return({
        'tiny':   {'customers': 2000,   'products': 300,  'orders': 10000,  'days': 120},
        'small':  {'customers': 25000,  'products': 2000, 'orders': 150000, 'days': 365},
        'medium': {'customers': 120000, 'products': 8000, 'orders': 900000, 'days': 540},
    }) }}
{% endmacro %}

{% macro nc_lists() %}
    {{ return({
        'first': ['Jan', 'Petr', 'Eva', 'Anna', 'Lukas', 'Tereza', 'Martin', 'Jana', 'Tomas', 'Lucie', 'Max', 'Lena', 'Jakub', 'Zofia', 'Mateusz', 'Sofia', 'Erik', 'Ida', 'Luca', 'Marta'],
        'last': ['Novak', 'Svoboda', 'Dvorak', 'Cerny', 'Muller', 'Schmidt', 'Kowalski', 'Nagy', 'Horvath', 'Jansen', 'Bauer', 'Rossi', 'Garcia', 'Lindqvist', 'Hansen', 'Kral'],
        'countries': ['CZ','CZ','CZ','CZ','DE','DE','DE','PL','PL','SK','SK','AT','HU','NL','FR','IT','ES','SE','DK','CZ'],
        'segments': ['consumer','consumer','consumer','consumer','consumer','consumer_plus','consumer_plus','smb','smb','enterprise'],
        'channels': ['web','web','web','web','web','app_ios','app_ios','app_android','app_android','marketplace','marketplace','phone'],
        'statuses': ['completed','completed','completed','completed','completed','completed','completed','completed','completed','completed','completed','completed','completed','completed','shipped','shipped','processing','cancelled','returned'],
        'categories': ['electronics','home','fashion','sports','beauty'],
        'subcategories': ['phones','laptops','audio','kitchen','furniture','decor','men','women','shoes','outdoor','fitness','cycling','skincare','makeup','hair'],
        'brands': ['Norda','Vltava','Kestrel','Brindle','Alpenkraft','Lumo','Tatra','Fjordline','Morava','Quillon','Severa','Danubia','Krona'],
        'pay_methods': ['card','card','card','card','card','paypal','paypal','apple_pay','apple_pay','bank_transfer','bnpl'],
        'pay_statuses': ['captured','captured','captured','captured','captured','captured','captured','captured','captured','refunded'],
        'event_types': ['page_view','page_view','page_view','page_view','page_view','page_view','page_view','page_view','page_view','page_view','product_view','product_view','product_view','product_view','product_view','add_to_cart','add_to_cart','checkout_start','purchase','search'],
        'pages': ['/','/c/electronics','/c/home','/c/fashion','/c/sports','/c/beauty','/search','/p/item','/cart','/checkout','/account','/help'],
        'devices': ['desktop','desktop','desktop','desktop','mobile','mobile','mobile','mobile','mobile','tablet'],
        'web_channels': ['web','web','web','app_ios','app_android'],
        'utm': ['google_ads','meta_ads','tiktok_ads','affiliate','newsletter','seo','direct','direct'],
        'mkt_channels': ['google_ads','meta_ads','tiktok_ads','affiliate','newsletter','seo'],
        'warehouses': ['PRG-1','BRQ-1','WAW-1','BER-1'],
        'stores': ['S-PRG-01','S-PRG-02','S-BRQ-01','S-OVA-01','S-BTS-01'],
        'fx': {'EUR': 1.0, 'CZK': 0.0398, 'PLN': 0.232, 'HUF': 0.00252, 'SEK': 0.0871, 'DKK': 0.134},
        'currency_by_country': {'CZ': 'CZK', 'SK': 'EUR', 'DE': 'EUR', 'AT': 'EUR', 'PL': 'PLN', 'HU': 'HUF', 'NL': 'EUR', 'FR': 'EUR', 'IT': 'EUR', 'ES': 'EUR', 'SE': 'SEK', 'DK': 'DKK'},
    }) }}
{% endmacro %}

{# DuckDB: run-operation rolls back an open transaction at the end, so commit explicitly. #}
{% macro nc_commit() %}
    {% if target.type == 'duckdb' and not var('nc_dry_run', false) %}
        {% do adapter.commit() %}
    {% endif %}
{% endmacro %}
