from pyesgf.search import SearchConnection

from itertools import groupby, product

def search_listing(js_results, query, require_all_on=["source_id"]):
    """
    Find unique group values for which all combinations of fields in query are present. 
    """
    # Infer which keys have >1 value (excluding keys in require_all_on)
    keys_to_combine = [k for k, v in query.items() if k not in require_all_on and isinstance(v, (list, tuple))]
    # Build required tuples of combos
    required_combos = set(product(*(query[k] for k in keys_to_combine)))
    # Group by the require_all_on fields
    def key_func(x):
        return tuple(x[k][0] if isinstance(x[k], list) else x[k] for k in require_all_on)
    found_keys = []
    for key, group in groupby(sorted(js_results, key=key_func), key=key_func):
        group = list(group)
        # Gather all tuples for this group
        combos = set(
            tuple(
                r[k][0] if isinstance(r[k], list) else r[k]
                for k in keys_to_combine
            ) for r in group
        )
        if required_combos.issubset(combos):
            found_keys.append(key if len(key) > 1 else key[0])
    return found_keys

# Example use:
query = dict(
    variable_id=["thetao", "so"],
    experiment_id=["lgm", "historical", "ssp585"],
    table_id=["Omon"],
)

valid_models = search_listing(js_results, query, require_all_on=["source_id"])
valid_models



# conn = SearchConnection('https://esgf-node.llnl.gov', distrib=True)
conn = SearchConnection('https://esgf-data.dkrz.de/esg-search', distrib=True)


## CMIP6 ##

# 1. Define your requirements
required_vars = ["thetao", "so"]
required_exps = ["lgm", "historical","ssp585"]
table_id = "Omon"

# 2. Server-side constraints: OR for vars/exps. Request facet counts only (limit=0, no dataset download)
ctx = conn.new_context(
    project='CMIP6',
    variable_id=required_vars,
    experiment_id=required_exps,
    table_id=table_id,
    facets='source_id,variable_id,experiment_id',
)

# 3. facet_counts triggers a single query with limit=0 — returns counts only, no dataset records
all_models = list(ctx.facet_counts.get('source_id', {}).keys())

# 4. For each model: constrain server-side and check facet_counts (again limit=0, no download)
valid_models = []
for model in all_models:
    model_ctx = ctx.constrain(source_id=model)
    model_vars = set(model_ctx.facet_counts.get('variable_id', {}).keys())
    model_exps = set(model_ctx.facet_counts.get('experiment_id', {}).keys())
    if set(required_vars).issubset(model_vars) and set(required_exps).issubset(model_exps):
        valid_models.append(model)

print(f"Models matching all criteria: {valid_models}")

## CMIP5 ##

# 1. Define your requirements (CMIP5 naming conventions)
required_vars = ["thetao", "so"]
required_exps = ["lgm", "historical", "rcp85"]  # Note: rcp85 instead of ssp585
time_frequency = "mon"  # monthly data

# 2. Server-side constraints: OR for vars/exps
ctx = conn.new_context(
    project='CMIP5',
    variable=required_vars,          # 'variable' not 'variable_id'
    experiment=required_exps,         # 'experiment' not 'experiment_id'
    time_frequency=time_frequency,
    facets='model,variable,experiment',  # 'model' not 'source_id'
)

# 3. Get all models
all_models = list(ctx.facet_counts.get('model', {}).keys())

# 4. For each model: check if it has all required variables and experiments
valid_models = []
for model in all_models:
    model_ctx = ctx.constrain(model=model)
    model_vars = set(model_ctx.facet_counts.get('variable', {}).keys())
    model_exps = set(model_ctx.facet_counts.get('experiment', {}).keys())
    if set(required_vars).issubset(model_vars) and set(required_exps).issubset(model_exps):
        valid_models.append(model)

print(f"Models matching all criteria: {valid_models}")



