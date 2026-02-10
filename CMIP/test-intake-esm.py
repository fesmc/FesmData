import intake

### CMIP6 ###

# First get a master list of data
url = "https://storage.googleapis.com/cmip6/pangeo-cmip6.json"
cat = intake.open_esm_datastore(url)
cat

# Define our query
query = dict(
    variable_id=["thetao", "so"],
    experiment_id=["lgm","historical","ssp585"],
    table_id=["Omon"],
)

# Find matches that contain all entries of interest for each model
# (ie, get models that have all variables for all experiments)
cat1 = cat.search(require_all_on=["source_id"], **query)

cat1.df.source_id.nunique() # 2 models

cat1.df.source_id.unique() # List unique entries

### CMIP5 ###

# CMIP5 catalog from Pangeo
url = "https://storage.googleapis.com/cmip6/pangeo-cmip5.json"
cat = intake.open_esm_datastore(url)
cat

# Define our query (CMIP5 naming conventions)
query = dict(
    variable_id=["thetao", "so"],
    experiment_id=["lgm", "historical", "rcp85"],
    table_id=["mon"],
)

# Find matches that contain all entries of interest for each model
# (ie, get models that have all variables for all experiments)
cat2 = cat.search(require_all_on=["source_id"], **query)

print(f"Number of models: {cat2.df.source_id.nunique()}")

print(f"Models: {cat2.df.source_id.unique()}")  # List unique entries
