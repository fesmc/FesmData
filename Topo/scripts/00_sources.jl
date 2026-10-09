#
# List the original datasets of datamanifest.toml and whether they are present on
# this machine. With --download, fetch the missing ones that can be downloaded
# automatically (run on a node with internet access, e.g. a Levante login node).
#
# Usage:
#     julia --project=Topo Topo/scripts/00_sources.jl [--download]
#
include(joinpath(@__DIR__, "..", "common.jl"))

db = manifest()
download = "--download" in ARGS

println("Datasets folder: ", get(ENV, "DATAMANIFEST_DATASETS_DIR", "(DataManifest default)"))
for key in sort(collect(keys(db.datasets)))
    entry = db.datasets[key]
    path = get_dataset_path(db, key)
    if !ispath(path) && download && !entry.skip_download
        println("Downloading $key ...")
        path = download_dataset(db, key)
    end
    status = ispath(path) ? "present" : (entry.skip_download ? "MISSING (manual download)" : "MISSING")
    println(rpad(key, 28), rpad(status, 28), path)
end
