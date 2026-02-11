# CMIP* data querying, downloading and processing

CMIP (CMIP5, CMIP6, etc) data are stored on ESGF nodes in a particular way to be systematic. And there is a lot of data. So it can be difficult to find what we need.

For the most part, ESMValTool seems to do the job. You can build recipes that relate to the data you want to download, and ESMValTool figures out which files you need from where. Additionally, it can handle processing steps or run scripts on the data to further transform it into a useable product.

However, sometimes ESMValTool fails. This is largely due to inconsistencies in the database etc. So often it is useful to predetermine which data is available for download. This is also true if one is not using ESMValTool at all.

There are a few possibilities for how to query the CMIP databases, and the ones we have so far are outlined below.

## Steps

As an example, let's say we want to determine all models that provided simulations for the particular experiments `["lgm","historical","ssp585"]` (or analogously for CMIP5 `["lgm","historical","rcp85"]`), and provided the ocean variables `["thetao", "so"]`. We want the set of models that have all the output available for all experiments.

### Using intake-esm

`intake-esm` is a Python package that has a search function that let's you achieve this. See the script [test-intake-esm.py](test-intake-esm.py) for a working example, first for CMIP6 models and then for CMIP5 models.

### Using pyesgf

`pyesgf` can do something similar but in a different way. See the script [test-esgf.py](test-esgf.py) for a working example.

### Refinement to pyesgf

See a more complete script and set of functions that leverage `pyesgf` and provide the function `search_esgf()` here:
https://github.com/awi-esc/LGMRecons/blob/main/run_esm.py

(More description needed)
