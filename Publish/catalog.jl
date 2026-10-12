# Catalogue of the released products, from the registry: the records, and the grids and
# files of a record, for `fesmdata.jl list` and the website. Standard library only.

include(joinpath(@__DIR__, "registry.jl"))

function human_size(n::Integer)
    n < 1e6 && return "$(round(n / 1e3; digits=1)) kB"
    n < 1e9 && return "$(round(n / 1e6; digits=1)) MB"
    return "$(round(n / 1e9; digits=2)) GB"
end

"Resolution of a grid name in metres (ANT-4KM, GRL-PAL-500M, GLOBAL-0.5DEG), for sorting."
function grid_resolution(grid::AbstractString)
    m = match(r"-(\d+(?:\.\d+)?)(KM|M|DEG)$", grid)
    m === nothing && return Inf
    return parse(Float64, m[1]) * Dict("KM" => 1000, "M" => 1, "DEG" => 111195)[m[2]]
end

"Order of grids: by region (domain or crop), then from fine to coarse."
grid_order(grid::AbstractString) = (replace(grid, r"-[\d.]+(K?M|DEG)$" => ""), grid_resolution(grid))

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
    record_detail(domain, dataset; grids=String[], dir=nothing, sandbox=false)

Print a record: its release, and the files of each grid (all grids, or those of
`grids`) with their sizes and whether they are in \$ICE_DATA, or in `dir` (by size;
`fetch` checks the checksums).
"""
function record_detail(domain::AbstractString, dataset::AbstractString; grids=String[], dir=nothing,
                       sandbox::Bool=false)
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
    have_local = dir !== nothing || haskey(ENV, "ICE_DATA")
    have_local || println("(ICE_DATA is not set: local files not checked)")
    where = dir === nothing ? "\$ICE_DATA" : local_root(dir)
    counts = Dict("present" => 0, "missing" => 0, "differs" => 0)
    for (grid, entries) in selected
        println("\n", rpad(grid, 16), length(entries), " files, ", human_size(total_size(last.(entries))))
        for (name, e) in entries
            state = ""
            if have_local
                path = local_path(e, local_root(dir))
                state = !isfile(path) ? "missing" : filesize(path) == e["size"] ? "present" : "differs"
                counts[state] += 1
            end
            println("  ", rpad(name, 40), lpad(human_size(e["size"]), 10), "  ", state)
        end
    end
    n = sum(length(last(g)) for g in selected)
    println("\nTotal: $n files, $(human_size(total_size(e for g in selected for e in last.(last(g)))))",
            have_local ? " (in $where: $(counts["present"]) present, $(counts["missing"]) missing" *
                         (counts["differs"] > 0 ? ", $(counts["differs"]) different" : "") * ")" : "")
    println("Download: julia fesmdata.jl fetch $domain $dataset", isempty(grids) ? " [GRID ...]" : " " * join(grids, " "))
end

"""
    select_records(args; sandbox=false) -> (selected, detail)

Records named by the arguments of `list` and `fetch`, in any order: a dataset, a
domain, and grids, which imply their domain (grid names are unique). Returns the
(domain, dataset, grids) of each matching record, and whether a single record or grids
were named (to show them in detail).
"""
function select_records(args; sandbox::Bool=false)
    records = list_records(; sandbox=sandbox)
    datasets = Set(last.(records))
    domains = Set(first.(records))
    grid_domain = Dict{String,String}()
    for (d, s) in records, e in values(read_record(d, s; sandbox=sandbox)[2])
        grid_domain[entry_grid(e)] = d
    end
    domain = filter(in(domains), args)
    dataset = filter(in(datasets), args)
    grids = filter(a -> !(a in domains) && !(a in datasets), args)
    unknown = filter(g -> !haskey(grid_domain, g), grids)
    isempty(unknown) || error("unknown $(join(unknown, ", ")): not a dataset ($(join(sort(collect(datasets)), ", "))), " *
                              "domain ($(join(sort(collect(domains)), ", "))) or grid (e.g. ANT-32KM)")
    (length(domain) > 1 || length(dataset) > 1) && error("give at most one domain and one dataset")
    grid_domains = unique(grid_domain[g] for g in grids)
    isempty(domain) || all(==(only(domain)), grid_domains) ||
        error("grids $(join(grids, ", ")) are not all on $(only(domain))")
    selected = Tuple{String,String,Vector{String}}[]
    for (d, s) in records
        (isempty(domain) || d in domain) && (isempty(dataset) || s in dataset) || continue
        isempty(grids) || d in grid_domains || continue
        push!(selected, (d, s, filter(g -> grid_domain[g] == d, grids)))
    end
    return selected, !isempty(grids) || (length(domain) == 1 && length(dataset) == 1)
end

"""
    list(args; dir=nothing, sandbox=false)

`fesmdata.jl list`: all records, or those of a dataset and/or a domain; with a domain
and a dataset, or with grids, the records in detail (for those grids), with the local
files in \$ICE_DATA/v2 or `dir`.
"""
function list(args; dir=nothing, sandbox::Bool=false)
    selected, detail = select_records(args; sandbox=sandbox)
    detail || return list_records_table([(d, s) for (d, s, _) in selected]; sandbox=sandbox)
    isempty(selected) && (println("No records"); return)
    for (k, (d, s, grids)) in enumerate(selected)
        k > 1 && println("\n", "-"^60, "\n")
        record_detail(d, s; grids=grids, dir=dir, sandbox=sandbox)
    end
end

"""
    check_local(entries, root; overwrite=false) -> Dict

States of the local files of `entries` under `root` (`local_state`, by local path),
after checking their checksums: prints how many are present, to download and of
earlier releases to update, and stops if files were changed locally, unless
`overwrite`.
"""
function check_local(entries, root::AbstractString; overwrite::Bool=false)
    println("Checking the files in $root (checksums)")
    states = Dict(local_path(e, root) => local_state(e, root) for e in entries)
    of_state(state) = filter(e -> states[local_path(e, root)] == state, entries)
    missing_, older, changed = of_state(:missing), of_state(:older), of_state(:changed)
    println("$(length(of_state(:current))) files present, $(length(missing_)) to download ",
            "($(human_size(total_size(missing_)))), $(length(older)) of earlier releases to update ",
            "($(human_size(total_size(older))))")
    if !isempty(changed)
        println("$(length(changed)) files changed locally (not of a release):")
        foreach(e -> println("  ", local_path(e, root)), changed)
        overwrite || error("files changed locally; use --overwrite to replace them")
    end
    return states
end

"""
    local_sources(entries, root, states) -> Dict

For a copy in another folder than \$ICE_DATA/v2 (`root`): the files of `entries` to get
that are in \$ICE_DATA/v2 at the same release (checksums), to hard link or copy from
there instead of downloading them (local path under `root` => path in \$ICE_DATA/v2).
"""
function local_sources(entries, root::AbstractString, states::AbstractDict)
    sources = Dict{String,String}()
    haskey(ENV, "ICE_DATA") && root != products_dir() || return sources
    todo = filter(e -> states[local_path(e, root)] != :current, entries)
    isempty(todo) && return sources
    println("Checking the same files in $(products_dir()) (checksums)")
    for e in todo
        local_state(e) == :current && (sources[local_path(e, root)] = local_path(e))
    end
    n = total_size(e for e in todo if haskey(sources, local_path(e, root)))
    println("$(length(sources)) of them there ($(human_size(n))), to hard link or copy instead of downloading")
    return sources
end

"""
    download_records(records, root, states; sources=Dict(), copy_registry=false,
                     overwrite=false, sandbox=false) -> Vector{String}

Get the files of `records`, (domain, dataset, entries), that are not present under
`root`, with the `states` of `check_local`: from `sources` (see `local_sources`), else
downloaded (see `fetch_file`). With `copy_registry` (a copy in another folder than
\$ICE_DATA/v2), the registry files of the records are copied to `root`/registry/, as a
record of the releases it holds. Returns the local paths.
"""
function download_records(records, root::AbstractString, states::AbstractDict; sources::AbstractDict=Dict(),
                          copy_registry::Bool=false, overwrite::Bool=false, sandbox::Bool=false)
    paths = String[]
    for (d, s, es) in records
        println("\n$d/$s")
        for e in es
            target = local_path(e, root)
            path, status = fetch_file(e, root; overwrite=overwrite, state=states[target],
                                      source=get(sources, target, nothing))
            println(rpad(string(status), 12), path)
            push!(paths, path)
        end
        if copy_registry
            reg = joinpath(root, "registry", d, "$s.toml")
            mkpath(dirname(reg))
            cp(registry_file(d, s; sandbox=sandbox), reg; force=true)
        end
    end
    return paths
end

"Entries of the selected records, as (domain, dataset, entries)."
selected_entries(selected; sandbox::Bool=false) =
    [(d, s, record_entries(d, s; grids=grids, sandbox=sandbox)) for (d, s, grids) in selected]

"""
    fetch_files(args; dir=nothing, overwrite=false, sandbox=false) -> Vector{String}

`fesmdata.jl fetch`: download the files of a dataset on a domain, or on grids (which
imply their domain), into \$ICE_DATA/v2 or `dir`. The dataset must be named, and a
domain or grids. The files present are checked first, as by `mirror`.
"""
function fetch_files(args; dir=nothing, overwrite::Bool=false, sandbox::Bool=false)
    selected, _ = select_records(args; sandbox=sandbox)
    datasets = unique(s for (_, s, _) in selected)
    length(datasets) == 1 && only(datasets) in args || error("fetch: name the dataset (e.g. Topo)")
    any(a -> a in first.(selected), args) || any(!isempty(g) for (_, _, g) in selected) ||
        error("fetch: name a domain or grids (e.g. Antarctica, ANT-32KM)")
    root = local_root(dir)
    records = selected_entries(selected; sandbox=sandbox)
    entries = [e for (_, _, es) in records for e in es]
    states = check_local(entries, root; overwrite=overwrite)
    sources = local_sources(entries, root, states)
    return download_records(records, root, states; sources=sources, copy_registry=dir !== nothing,
                            overwrite=overwrite, sandbox=sandbox)
end

"""
    mirror(args; dir=nothing, overwrite=false, sandbox=false, yes=false) -> Vector{String}

`fesmdata.jl mirror`: download all records (or those of a dataset and/or a domain)
into \$ICE_DATA/v2, or `dir`. The files present are checked first (checksums): files
of the release are kept, files of an earlier release are updated, and files changed
locally stop the mirror (replaced with `overwrite`). Into `dir`, files of the release
in \$ICE_DATA/v2 are hard linked or copied from there, e.g. to archive the releases
there before updating it. Then, after one confirmation (none with `yes`) showing what
is to get, the missing and outdated files are downloaded.
"""
function mirror(args; dir=nothing, overwrite::Bool=false, sandbox::Bool=false, yes::Bool=false)
    selected, _ = select_records(args; sandbox=sandbox)
    isempty(selected) && (println("No records"); return String[])
    root = local_root(dir)
    records = selected_entries(selected; sandbox=sandbox)
    entries = [e for (_, _, es) in records for e in es]
    println("$(length(selected)) records, $(length(entries)) files, $(human_size(total_size(entries))) in total")
    states = check_local(entries, root; overwrite=overwrite)
    sources = local_sources(entries, root, states)
    todo = filter(e -> states[local_path(e, root)] != :current, entries)
    to_download = filter(e -> !haskey(sources, local_path(e, root)), todo)
    yes || isempty(todo) || confirm("Get $(length(todo)) files into $root " *
                                    "($(human_size(total_size(to_download))) to download)?") ||
        (println("Nothing downloaded."); return String[])
    return download_records(records, root, states; sources=sources, copy_registry=dir !== nothing,
                            overwrite=overwrite, sandbox=sandbox)
end
