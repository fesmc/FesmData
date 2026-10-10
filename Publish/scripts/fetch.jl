# Download published products into $ICE_DATA/v2/<Domain>/<GRID>/ and verify their
# checksums. Needs only the Julia standard library: no project, nothing to install.
#
#   julia Publish/scripts/fetch.jl                  # list the records
#   julia Publish/scripts/fetch.jl Antarctica Topo  # all grids
#   julia Publish/scripts/fetch.jl Antarctica Topo ANT-8KM ANT-16KM
#
# With --overwrite, local files that differ from the registry are replaced; with
# --sandbox, the records are the test releases (registry/_sandbox/).

include(joinpath(@__DIR__, "..", "registry.jl"))

overwrite = "--overwrite" in ARGS
sandbox = "--sandbox" in ARGS
args = filter(a -> !startswith(a, "--"), ARGS)

if isempty(args)
    for (domain, dataset) in list_records(; sandbox=sandbox)
        tables, files = read_record(domain, dataset; sandbox=sandbox)
        release, zenodo = tables["_RELEASE"], get(tables, "_ZENODO", Dict())
        doi = get(zenodo, "git_tag", "") == release["git_tag"] ? "doi:" * zenodo["doi"] : ""
        grids = sort(unique(entry_grid(e) for e in values(files)))
        println(rpad("$domain/$dataset", 24), rpad(release["version"], 8), rpad(release["date"], 12),
                rpad(doi, 30), join(grids, " "))
    end
else
    length(args) >= 2 || error("usage: fetch.jl [<Domain> <Dataset> [<GRID> ...]] [--overwrite] [--sandbox]")
    paths = fetch_record(args[1], args[2]; grids=args[3:end], overwrite=overwrite, sandbox=sandbox)
    println("$(length(paths)) files in $(products_dir())")
end
