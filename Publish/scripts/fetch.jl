# Download published products into $ICE_DATA/v2/<Domain>/<GRID>/ and verify their
# checksums.
#
#   julia --project=Publish Publish/scripts/fetch.jl                  # list the records
#   julia --project=Publish Publish/scripts/fetch.jl Antarctica Topo  # all grids
#   julia --project=Publish Publish/scripts/fetch.jl Antarctica Topo ANT-8KM ANT-16KM
#
# With --overwrite, local files that differ from the registry are replaced.

include(joinpath(@__DIR__, "..", "registry.jl"))

overwrite = "--overwrite" in ARGS
args = filter(!=("--overwrite"), ARGS)

if isempty(args)
    for (domain, dataset) in list_records()
        info, files = read_record(domain, dataset)
        grids = sort(unique(entry_grid(e) for e in values(files)))
        println(rpad("$domain/$dataset", 24), rpad(get(info, "version", "?"), 10),
                rpad("doi:" * get(info, "doi", "?"), 32), join(grids, " "))
    end
else
    length(args) >= 2 || error("usage: fetch.jl [<Domain> <Dataset> [<GRID> ...]] [--overwrite]")
    paths = fetch_record(args[1], args[2]; grids=args[3:end], overwrite=overwrite)
    println("$(length(paths)) files in $(products_dir())")
end
