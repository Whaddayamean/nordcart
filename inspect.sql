{#
  Inspection helpers.

  Compare what different tools built from the same raw data. Every tool builds into its own
  schema prefix (see generate_schema_name), e.g. demo_dbtstate_marts, demo_hodor_marts.

    dbt run-operation nc_compare --args '{prefixes: [demo_reference, demo_dbtstate, demo_hodor]}'

  For each model: row count + an order-independent hash of all non-float columns + the sum of
  every float column (float sums compared with a 1e-9 relative tolerance). The FIRST prefix is
  the baseline; the others are marked "same" / "DIFFERENT" / "missing" against it.

    dbt run-operation nc_drop_model --args '{prefix: demo_hodor, model: fct_customer_ltv}'
#}

{% macro nc_fingerprint(rel) %}
    {% set cols = adapter.get_columns_in_relation(rel) %}
    {% set exact, floats = [], [] %}
    {% for c in cols if not c.name.lower().startswith('dbt_') %}
        {% set dt = c.dtype | lower %}
        {% if 'float' in dt or 'double' in dt or 'real' in dt %}
            {% do floats.append(c.name) %}
        {% else %}
            {% do exact.append(c.name) %}
        {% endif %}
    {% endfor %}
    {% if exact | length == 0 %}{% do exact.append("'x'") %}{% endif %}
    {% if target.type == 'snowflake' %}
        {% set h = "hash_agg(" ~ exact | join(', ') ~ ")" %}
    {% elif target.type in ('databricks', 'spark') %}
        {% set h = "sum(cast(hash(" ~ exact | join(', ') ~ ") as bigint))" %}
    {% else %}
        {% set h = "sum(hash(" ~ exact | join(', ') ~ "))" %}
    {% endif %}
    {% set sql %}
        select count(*), cast({{ h }} as {{ dbt.type_string() }})
        {%- for f in floats %}, cast(sum({{ f }}) as double){% endfor %}
        from {{ rel }}
    {% endset %}
    {% set row = run_query(sql).rows[0] %}
    {% set fsums = [] %}
    {% for i in range(2, row | length) %}{% do fsums.append((row[i] or 0) | float) %}{% endfor %}
    {{ return({'n': row[0] | int, 'h': row[1] | string, 'f': fsums}) }}
{% endmacro %}

{% macro nc_same(a, b) %}
    {% if a.n != b.n or a.h != b.h or a.f | length != b.f | length %}{{ return(false) }}{% endif %}
    {% for i in range(a.f | length) %}
        {% set x, y = a.f[i], b.f[i] %}
        {% if (x - y) | abs > 1e-9 * ([1.0, x | abs, y | abs] | max) %}{{ return(false) }}{% endif %}
    {% endfor %}
    {{ return(true) }}
{% endmacro %}

{% macro nc_schema_for(prefix, node) %}
    {% set custom = node.config.schema %}
    {{ return(prefix ~ '_' ~ custom if custom else prefix) }}
{% endmacro %}

{% macro nc_compare(prefixes, select=none) %}
    {% if prefixes is string %}{% set prefixes = prefixes.split(',') %}{% endif %}
    {% set w = 34 %}
    {% set header = ["model".ljust(w)] %}
    {% for p in prefixes %}{% do header.append(p.ljust(26)) %}{% endfor %}
    {{ log(header | join(''), info=True) }}
    {% set n_diff = [] %}
    {% for node in graph.nodes.values() | sort(attribute='name') %}
        {% if node.resource_type == 'model' and node.config.enabled and node.config.materialized != 'ephemeral'
              and (select is none or node.name in select) %}
            {% set fps = [] %}
            {% for p in prefixes %}
                {% set rel = adapter.get_relation(database=node.database, schema=nc_schema_for(p, node), identifier=node.alias) %}
                {% do fps.append(nc_fingerprint(rel) if rel else none) %}
            {% endfor %}
            {% set cells = [node.name.ljust(w)] %}
            {% for fp in fps %}
                {% if fp is none %}
                    {% set cell = "missing" %}
                {% elif loop.first or fps[0] is none %}
                    {% set cell = fp.n ~ " rows" %}
                {% elif nc_same(fps[0], fp) %}
                    {% set cell = "same" %}
                {% else %}
                    {% set cell = "DIFFERENT (" ~ fp.n ~ " rows)" %}
                    {% do n_diff.append(node.name) %}
                {% endif %}
                {% do cells.append(cell.ljust(26)) %}
            {% endfor %}
            {{ log(cells | join(''), info=True) }}
        {% endif %}
    {% endfor %}
    {{ log("baseline = " ~ prefixes[0] ~ "; models differing from it: " ~ (n_diff | unique | list | length), info=True) }}
{% endmacro %}

{% macro nc_drop_model(prefix, model) %}
    {% for node in graph.nodes.values() if node.resource_type == 'model' and node.name == model %}
        {% set rel = adapter.get_relation(database=node.database, schema=nc_schema_for(prefix, node), identifier=node.alias) %}
        {% if rel %}
            {% do run_query("drop " ~ (rel.type or 'table') ~ " if exists " ~ rel) %}
            {% do nc_commit() %}
            {{ log("dropped " ~ rel, info=True) }}
        {% else %}
            {{ log("not found: " ~ model ~ " in prefix " ~ prefix, info=True) }}
        {% endif %}
    {% endfor %}
{% endmacro %}

{# Drop every schema a tool built (<prefix> and <prefix>_<layer>), or the raw layer (prefix = 'raw'). #}
{% macro nc_cleanup(prefix) %}
    {% if prefix == 'raw' %}
        {% set schemas = [nc_raw_schema()] %}
        {% set db = nc_raw_database() %}
    {% else %}
        {% set schemas = [prefix] %}
        {% for layer in ['staging', 'intermediate', 'marts', 'reports', 'ref', 'snapshots'] %}
            {% do schemas.append(prefix ~ '_' ~ layer) %}
        {% endfor %}
        {% set db = target.database %}
    {% endif %}
    {% for s in schemas %}
        {% do adapter.drop_schema(api.Relation.create(database=db, schema=s)) %}
        {{ log("dropped schema (if it existed) " ~ db ~ "." ~ s, info=True) }}
    {% endfor %}
    {% do nc_commit() %}
{% endmacro %}
