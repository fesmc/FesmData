#
# List the original datasets of datamanifest.toml and whether they are present on
# this machine. With --download, fetch the missing ones that can be downloaded
# automatically (run on a node with internet access, e.g. a Levante login node), and
# the tiles of the Copernicus DEMs (GLO-90, GLO-30) of the domains that use them: the
# active domains, or the DOMAINs given.
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

# Tiles of the Copernicus DEMs over the domains with products that use them
for name in sort(collect(keys(COPERNICUS_DEMS)))
    dir = get_dataset_path(db, name)
    keys_dem = filter(isempty(named) ? topo_domains() : named) do key
        any(srcs -> name in srcs, values(product_sources(Domain(key))))
    end
    for key in keys_dem
        dom = Domain(key)
        if download
            download_copdem(name, dir, dom)
        elseif isfile(joinpath(dir, "tileList.txt"))
            tiles = copdem_tiles(name, dom, dir)
            println(rpad("$name $key", 28), count(t -> isfile(copdem_file(dir, t)), tiles), " of ",
                    length(tiles), " tiles present")
        else
            println(rpad("$name $key", 28), "MISSING (tile list, run with --download)")
        end
    end
end
