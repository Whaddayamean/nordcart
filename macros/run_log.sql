{#
  Run log: after every dbt build/run/seed/snapshot/test, record what happened to each node
  (built, reused, skipped, failed) in one shared table, so dbt State and dbt-hodor runs can be
  compared with SQL instead of reading logs.

  Wired up in dbt_project.yml:   on-run-end: "{{ nc_log_results(results) }}"

  Table: <target catalog/database>.<var nc_runlog_schema, default nordcart_runlog>.node_results
  `tool` = target.schema of the run (demo_dbtstate, demo_hodor, demo_reference, ...).
  Disable with --vars '{nc_run_log: false}'.
#}

{% macro nc_runlog_relation() -%}
    {{ target.database }}.{{ var('nc_runlog_schema', 'nordcart_runlog') }}.node_results
{%- endmacro %}

{% macro nc_log_results(results) %}
    {% if execute and var('nc_run_log', true) and flags.WHICH in ('build', 'run', 'seed', 'snapshot', 'test') and results %}
        {% do adapter.create_schema(api.Relation.create(database=target.database, schema=var('nc_runlog_schema', 'nordcart_runlog'))) %}
        {% set rel = nc_runlog_relation() %}
        {% do run_query(
            "create table if not exists " ~ rel ~ " ("
            ~ "tool " ~ dbt.type_string() ~ ", invocation_id " ~ dbt.type_string() ~ ", run_started_at " ~ dbt.type_timestamp()
            ~ ", command " ~ dbt.type_string() ~ ", unique_id " ~ dbt.type_string() ~ ", node " ~ dbt.type_string()
            ~ ", resource_type " ~ dbt.type_string() ~ ", status " ~ dbt.type_string() ~ ", message " ~ dbt.type_string()
            ~ ", adapter_message " ~ dbt.type_string() ~ ", execution_time double)"
        ) %}
        {% set rows = [] %}
        {% for r in results %}
            {% set ar = r.adapter_response or {} %}
            {% set msg = (r.message or '') | string %}
            {% set amsg = (ar.get('_message') if ar is mapping else '') or '' %}
            {% do rows.append("('" ~ target.schema ~ "', '" ~ invocation_id ~ "', cast('"
                ~ run_started_at.strftime('%Y-%m-%d %H:%M:%S') ~ "' as " ~ dbt.type_timestamp() ~ "), '"
                ~ flags.WHICH ~ "', '" ~ r.node.unique_id ~ "', '" ~ r.node.name ~ "', '" ~ r.node.resource_type
                ~ "', '" ~ (r.status | string) ~ "', '" ~ msg.replace("'", "''")[:500] ~ "', '"
                ~ (amsg | string).replace("'", "''")[:200] ~ "', " ~ (r.execution_time or 0) ~ ")") %}
        {% endfor %}
        {% do run_query("insert into " ~ rel ~ " values " ~ rows | join(",\n")) %}
        {% if target.type == 'duckdb' %}{% do adapter.commit() %}{% endif %}
        {{ log("run log: " ~ rows | length ~ " node results -> " ~ rel ~ " (tool = " ~ target.schema ~ ")", info=True) }}
    {% endif %}
    select 1
{% endmacro %}
