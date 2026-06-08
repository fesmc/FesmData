from itertools import groupby, product
from pyesgf.search import SearchConnection   # pip install esgf-pyclient

conn = SearchConnection('https://esgf-data.dkrz.de/esg-search', distrib=True)

queries = [
    # CMIP6 naming conventions
    {
        "project" : "CMIP6", 
        "variable_id" : ["thetao", "so"],
        "experiment_id" : ["lgm", "historical","ssp585"],
        "table_id" : "Omon",
        "facets" : 'source_id,variable_id,experiment_id',
    },
    # CMIP5 naming conventions
    {
        "project" : 'CMIP5',
        "variable" : ["thetao", "so"],  # 'variable' not 'variable_id'
        "experiment" : ["lgm", "historical", "rcp85"],  # 'experiment' not 'experiment_id'; rcp85 instead of ssp585
        "time_frequency" : "mon",  # monthly data
        "facets" : 'model,variable,experiment',  # 'model' not 'source_id'
    }
]

query_results = []

for query in queries:
    # Server-side constraints: OR for vars/exps
    ctx = conn.new_context(**query)

    # Download all metadata matching any of the constraints above
    results = ctx.search()
    js_results = [result.json for result in results]

    # cache the result for re-use with `search_listing` function below
    query_results.append(js_results)

    if query["project"] == "CMIP5":
        model_key, experiment_key, variable_key = "model", "experiment", "variable"
    else:
        model_key, experiment_key, variable_key = "source_id", "experiment_id", "variable_id"

    # Refine the constraints (product)
    required_combos = set((x, v) for x in query[experiment_key] for v in query[variable_key])
    
    valid_models = []
    key_func = lambda x: x[model_key][0] # sort by model
    for model, group in groupby(sorted(js_results, key=key_func), key=key_func):
        combos = set((r[experiment_key][0], r[variable_key][0]) for r in group)
        if required_combos.issubset(combos):
            valid_models.append(model)
    
    print(f"{query['project']} Models matching all criteria: {valid_models}")
    
    # save result as additional query field for later use
    query[model_key] = valid_models


# Alternatively we can write a more generic function:

def search_listing(js_results, query, require_all_on=["source_id"]):
    """
    Find unique group values for which all combinations of fields in query
    (of length 2+) are present.
    By default, finds source_ids for which all variable_id/experiment_id combos exist.
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


# for use:
for query, js_results in zip(queries, query_results):
    model_key = "model" if query["project"] == "CMIP5" else "source_id"
    valid_models = search_listing(js_results, query, require_all_on=[model_key])
    print(query["project"], valid_models)



