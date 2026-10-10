# Catalogue of the released products, from the registry: the records, and the grids and
# files of a record, for `fesmdata.jl list` and the website. Standard library only.

include(joinpath(@__DIR__, "registry.jl"))

function human_size(n::Integer)
    n < 1e6 && return "$(round(n / 1e3; digits=1)) kB"
    n < 1e9 && return "$(round(n / 1e6; digits=1)) MB"
    return "$(round(n / 1e9; digits=2)) GB"
end

"Resolution of a grid name in metres (ANT-4KM, GRL-PAL-500M), for sorting."
function grid_resolution(grid::AbstractString)
    m = match(r"-(\d+(?:\.\d+)?)(KM|M)$", grid)
    m === nothing && return Inf
    return parse(Float64, m[1]) * (m[2] == "KM" ? 1000 : 1)
end

"Order of grids: by region (domain or crop), then from fine to coarse."
grid_order(grid::AbstractString) = (replace(grid, r"-[\d.]+K?M$" => ""), grid_resolution(grid))

"Order of the files of a grid: the grid description and grid file first."
file_order(name::AbstractString) = (startswith(name, "grid_") ? 0 : endswith(name, "_grid.nc") ? 1 : 2, name)

"Grids of a record, from fine to coarse, with their files (name => entry)."
function record_grids(files::AbstractDict)
    grids = Dict{String,Vector{Pair{String,Any}}}()
    for (name, e) in files
        push!(get!(grids, entry_grid(e), Pair{String,Any}[]), name => e)
    end
    return [g => sort(grids[g]; by=p -> file_order(first(p))) for g in sort(collect(keys(grids)); by=grid_order)]
end

total_size(entries) = sum(e -> get(e, "size", 0), entries; init=0)

"DOI of a record, if its release is archived on Zenodo (else empty)."
function record_doi(tables::AbstractDict)
    z = get(tables, "_ZENODO", nothing)
    return z !== nothing && z["git_tag"] == tables["_RELEASE"]["git_tag"] ? z["doi"] : ""
end

"""
    list_records_table(records; sandbox=false)

Print a table of records ((domain, dataset) pairs): version, release date, size, DOI
(if any record has one) and grids from fine to coarse.
"""
function list_records_table(records; sandbox::Bool=false)
    isempty(records) && (println("No records"); return)
    rows = []
    for (domain, dataset) in records
        tables, files = read_record(domain, dataset; sandbox=sandbox)
        release = tables["_RELEASE"]
        push!(rows, ("$domain/$dataset", release["version"], release["date"], human_size(total_size(values(files))),
                     record_doi(tables), join(first.(record_grids(files)), " ")))
    end
    with_doi = any(r -> !isempty(r[5]), rows)
    w = maximum(length(r[1]) for r in rows) + 2
    println(rpad("Record", w), rpad("Version", 9), rpad("Released", 12), rpad("Size", 10),
            with_doi ? rpad("DOI", 26) : "", "Grids (fine to coarse)")
    for r in rows
        println(rpad(r[1], w), rpad(r[2], 9), rpad(r[3], 12), rpad(r[4], 10), with_doi ? rpad(r[5], 26) : "", r[6])
    end
end

"""
    record_detail(domain, dataset; grids=String[], sandbox=false)

Print a record: its release, and the files of each grid (all grids, or those of
`grids`) with their sizes and whether they are in \$ICE_DATA (by size; `fetch` checks
the checksums).
"""
function record_detail(domain::AbstractString, dataset::AbstractString; grids=String[], sandbox::Bool=false)
    tables, files = read_record(domain, dataset; sandbox=sandbox)
    release = tables["_RELEASE"]
    all_grids = record_grids(files)
    unknown = setdiff(grids, first.(all_grids))
    isempty(unknown) || error("$domain/$dataset: no grids $(join(unknown, ", ")), available: $(join(first.(all_grids), ", "))")
    selected = filter(g -> isempty(grids) || first(g) in grids, all_grids)
    println("$domain/$dataset, version $(release["version"]) ($(release["git_tag"])), released $(release["date"])")
    println("Packages: $(release["store"])")
    doi = record_doi(tables)
    isempty(doi) || println("DOI: https://doi.org/$doi")
    have_local = haskey(ENV, "ICE_DATA")
    have_local || println("(ICE_DATA is not set: local files not checked)")
    counts = Dict("present" => 0, "missing" => 0, "differs" => 0)
    for (grid, entries) in selected
        println("\n", rpad(grid, 16), length(entries), " files, ", human_size(total_size(last.(entries))))
        for (name, e) in entries
            state = ""
            if have_local
                path = local_path(e)
                state = !isfile(path) ? "missing" : filesize(path) == e["size"] ? "present" : "differs"
                counts[state] += 1
            end
            println("  ", rpad(name, 40), lpad(human_size(e["size"]), 10), "  ", state)
        end
    end
    n = sum(length(last(g)) for g in selected)
    println("\nTotal: $n files, $(human_size(total_size(e for g in selected for e in last.(last(g)))))",
            have_local ? " (in \$ICE_DATA: $(counts["present"]) present, $(counts["missing"]) missing" *
                         (counts["differs"] > 0 ? ", $(counts["differs"]) different" : "") * ")" : "")
    println("Download: julia fesmdata.jl fetch $domain $dataset", isempty(grids) ? " [GRID ...]" : " " * join(grids, " "))
end

"""
    list(args; sandbox=false)

`fesmdata.jl list`: all records; the records of a dataset or a domain; or, with a
domain and a dataset, the record in detail, for all grids or those given.
"""
function list(args; sandbox::Bool=false)
    records = list_records(; sandbox=sandbox)
    datasets = Set(last.(records))
    domains = Set(first.(records))
    domain = filter(in(domains), args)
    dataset = filter(in(datasets), args)
    grids = filter(a -> !(a in domains) && !(a in datasets), args)
    (length(domain) > 1 || length(dataset) > 1) && error("list: give at most one domain and one dataset")
    if length(domain) == 1 && length(dataset) == 1
        record_detail(only(domain), only(dataset); grids=grids, sandbox=sandbox)
    else
        isempty(grids) || error("list: unknown $(join(grids, ", ")) (datasets: $(join(sort(collect(datasets)), ", ")); " *
                                "domains: $(join(sort(collect(domains)), ", ")); grids need a domain and a dataset)")
        list_records_table(filter(r -> (isempty(domain) || r[1] in domain) && (isempty(dataset) || r[2] in dataset), records);
                           sandbox=sandbox)
    end
end
