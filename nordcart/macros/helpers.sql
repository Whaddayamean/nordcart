{#
  Model helpers. `cents_to_eur` is used by several models, so editing it changes the compiled
  SQL of those models without touching any model file (see `./demo change macro`).
#}
{% macro cents_to_eur(cents_col, rate_col) -%}
    round(({{ cents_col }} / 100.0) * {{ rate_col }}, 2)
{%- endmacro %}

{#
  Every tool builds into its own prefix: <target.schema>_<layer>, e.g. demo_hodor_marts and
  demo_dbtstate_marts, so they never touch each other's objects.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}{{ target.schema }}
    {%- else -%}{{ target.schema }}_{{ custom_schema_name | trim }}{%- endif -%}
{%- endmacro %}
