#
# List the original datasets of datamanifest.toml and whether they are present on
# this machine. With --download, fetch the missing ones that can be downloaded
# automatically (run on a node with internet access, e.g. a Levante login node), and
# the GLO-90 tiles of the domains that use them: the active domains, or the DOMAINs
# given.
#
# Usage:
#     julia --project=Topo Topo/scripts/00_sources.jl [--download] [DOMAIN ...]
#
include(joinpath(@__DIR__, "..", "common.jl"))
include(joinpath(TOPO_DIR, "sources.jl"))

db = manifest()
download = "--download" in ARGS
named = filter(!=("--download"), ARGS)

println("Datasets folder: ", fesmdata_dir("sources"))
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

# GLO-90 tiles of the domains with products that use them
glo90 = get_dataset_path(db, "copernicus_glo90")
keys_glo90 = filter(isempty(named) ? topo_domains() : named) do key
    any(srcs -> "copernicus_glo90" in srcs, values(product_sources(Domain(key))))
end
for key in keys_glo90
    dom = Domain(key)
    if download
        download_glo90(glo90, dom)
    elseif isfile(joinpath(glo90, "tileList.txt"))
        names = glo90_tiles(dom, glo90)
        println(rpad("copernicus_glo90 $key", 28), count(n -> isfile(glo90_file(glo90, n)), names), " of ",
                length(names), " tiles present")
    else
        println(rpad("copernicus_glo90 $key", 28), "MISSING (tile list, run with --download)")
    end
end
