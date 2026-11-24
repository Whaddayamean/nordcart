{#
  Used by int_orders_enriched. Editing this macro changes the compiled SQL of that model
  (and everything downstream) without touching any model file: the "macro-only change" experiment.
#}
{% macro to_amount(cents_col) -%}
    round({{ cents_col }} / 100.0, 2)
{%- endmacro %}

{# Every tool builds into its own prefix: <target.schema>_<layer>, e.g. demo_hodor_marts. #}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}{{ target.schema }}
    {%- else -%}{{ target.schema }}_{{ custom_schema_name | trim }}{%- endif -%}
{%- endmacro %}
