# EDGE CASE: Python model (dbt State supports SQL models only). Disabled by default because Python
# models need extra warehouse setup: enable with --vars '{enable_python_model: true}'.
# Snowflake: needs Anaconda packages accepted. Databricks: set submission_method (e.g. serverless_cluster).
def model(dbt, session):
    dbt.config(materialized="table", packages=["pandas"])
    rel = dbt.ref("fct_customer_ltv")
    if hasattr(rel, "df"):            # DuckDB
        df = rel.df()
    elif hasattr(rel, "toPandas"):    # Databricks (Spark)
        df = rel.toPandas()
    else:                             # Snowflake (Snowpark)
        df = rel.to_pandas()
    df.columns = [c.lower() for c in df.columns]
    df = df[["customer_id", "ltv_eur", "revenue_orders"]].copy()
    q = df["ltv_eur"].rank(pct=True)
    df["value_tier"] = "bronze"
    df.loc[q > 0.5, "value_tier"] = "silver"
    df.loc[q > 0.8, "value_tier"] = "gold"
    df.loc[q > 0.95, "value_tier"] = "platinum"
    return df
