# Catalogue of the released products, from the registry: the records, and the grids and
# files of a record, for `fesmdata.jl list` and the website, and the records by cropping
# (datasets of nests and crops, made by `fetch` from the record of their parent domain).
# Standard library only.

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

"Whether a file of a grid is its grid description (grid_<GRID>.txt) or grid file (<GRID>_grid.nc)."
is_grid_file(name::AbstractString) = startswith(name, "grid_") || endswith(name, "_grid.nc")

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

# ---------------------------------------------------------------------------
# Records by cropping
# ---------------------------------------------------------------------------

"""
    CropRecord

The products of a thematic dataset (made by remapping, e.g. GHF) on a nest or crop
(output folder `folder`, grids named after `key`) that are in the record of its parent
domain (folder `parent`, grids named after `parent_key`) and not in a record of its own:
`fetch` makes them from the files of the parent record, cut to the nest or crop on each
of its grids (see crop.jl), so that thematic products are released once, on the parent
domain. A nest or crop may have a record of its own with other products (e.g. a
Greenland-only source on Greenland). `products` are the names of the products (files
without the grid, `product_name`). (Topo and Regions are made on every domain from the
sources, nests included.)
"""
struct CropRecord
    folder::String
    dataset::String
    key::String
    parent::String
    parent_key::String
    products::Vector{String}
end

"""
    sub_domains() -> Dict{String,NTuple{3,String}}

The nests and crops of ../shared/domains.toml (also the crops of nests) by output
folder: their key, and the key and folder of their parent domain.
"""
function sub_domains()
    subs = Dict{String,NTuple{3,String}}()
    add!(key, d, kinds) = for kind in kinds, (k, sub) in get(d, kind, Dict())
        subs[sub["folder"]] = (k, key, d["folder"])
    end
    for (key, d) in TOML.parsefile(joinpath(REPO_DIR, "shared", "domains.toml"))
        add!(key, d, ("crops", "nests"))
        for (nkey, n) in get(d, "nests", Dict())
            add!(nkey, n, ("crops",))
        end
    end
    return subs
end

"""
    crop_records(files_of) -> Vector{CropRecord}

The records by cropping, for the records of the registry (their files by (domain,
dataset), see `read_record`): for each thematic dataset with a record on a domain, on
each of its nests and crops, the products of that record that their own record of the
dataset (if any) does not have.
"""
function crop_records(files_of::AbstractDict)
    crops = CropRecord[]
    for (folder, (key, pkey, parent)) in sort(collect(sub_domains())), (d, s) in sort(collect(keys(files_of)))
        d == parent && is_remap_dataset(s) || continue
        products = setdiff(product_names(files_of[(d, s)]), product_names(get(files_of, (folder, s), Dict())))
        isempty(products) || push!(crops, CropRecord(folder, s, key, parent, pkey, products))
    end
    return crops
end

function _chop_prefix(name::AbstractString, prefix::AbstractString)
    startswith(name, prefix) || error("$name does not start with $prefix")
    return name[ncodeunits(prefix)+1:end]
end

_chop_key(name::AbstractString, key::AbstractString) = "-" * _chop_prefix(name, key * "-")

"Product of a data file of a record: its name without the grid (ANT-4KM_GHF-Davies2013.nc -> GHF-Davies2013.nc)."
product_name(e::AbstractDict) = _chop_prefix(basename(e["storage_path"]), entry_grid(e) * "_")

"Whether a registry entry is of a data file (not a grid file)."
is_data_file(e::AbstractDict) = !is_grid_file(basename(e["storage_path"]))

"Products of a record (files by name), sorted."
product_names(files::AbstractDict) = sort(unique(product_name(e) for e in values(files) if is_data_file(e)))

"Whether a registry entry of the parent record of `c` is of one of its products."
is_crop_product(c, e::AbstractDict) = is_data_file(e) && product_name(e) in c.products

"Grids of a record by cropping, from the files of its parent record (fine to coarse)."
crop_grids(c, pfiles::AbstractDict) =
    [crop_grid_name(c, g) for (g, es) in record_grids(pfiles) if any(p -> is_crop_product(c, last(p)), es)]

"Grid of a record by cropping for a grid of its parent record: ANT-4KM -> THW-4KM."
crop_grid_name(c::CropRecord, grid::AbstractString) = c.key * _chop_key(grid, c.parent_key)

"Grid of the parent record for a grid of a record by cropping: THW-4KM -> ANT-4KM."
parent_grid_name(c::CropRecord, grid::AbstractString) = c.parent_key * _chop_key(grid, c.key)

"File of a record by cropping for a file of its parent record: ANT-4KM_GHF-x.nc -> THW-4KM_GHF-x.nc."
crop_file_name(c::CropRecord, name::AbstractString) = c.key * _chop_key(name, c.parent_key)

"""
    crop_data_files(c, entries, root) -> Vector

The files of record by cropping `c` for `entries` of its parent record, under `root`:
parent entry => local path of the file of each of its products (the grid files are
written for each grid, see crop.jl).
"""
function crop_data_files(c::CropRecord, entries, root::AbstractString)
    files = Pair{Any,String}[]
    for e in filter(e -> is_crop_product(c, e), entries)
        name = basename(e["storage_path"])
        push!(files, e => joinpath(root, c.folder, crop_grid_name(c, entry_grid(e)), crop_file_name(c, name)))
    end
    return files
end

"""
    crop_sources(cropped; sandbox=false) -> Vector

What `fetch` downloads for records by cropping, `cropped` ((record, grids) of
`select_records`), as (domain, dataset, entries): the files of their products in their
parent records on these grids (all if none are named; not the grid files of the parent,
which cropping does not need), and the grid files that the records of the nest or crop
(e.g. Topo) have on these grids, i.e. on the grids of the nest or crop itself, so that
these are the released files rather than files written again. A file may be in several
of these (see `unique_files`).
"""
function crop_sources(cropped; sandbox::Bool=false)
    sources = Tuple{String,String,Vector}[]
    for (c, grids) in cropped
        pentries = filter(e -> is_crop_product(c, e),
                          record_entries(c.parent, c.dataset; grids=[parent_grid_name(c, g) for g in grids], sandbox=sandbox))
        push!(sources, (c.parent, c.dataset, pentries))
        targets = Set(crop_grid_name(c, entry_grid(e)) for e in pentries)
        for (d, s) in list_records(; sandbox=sandbox)
            d == c.folder || continue
            es = filter(e -> entry_grid(e) in targets && !is_data_file(e), record_entries(d, s; sandbox=sandbox))
            isempty(es) || push!(sources, (d, s, es))
        end
    end
    return sources
end

"""
    unique_files(records) -> Vector

Records (domain, dataset, entries) with each local file once, in the first record that
has it (e.g. the grid files of a grid, which all records on it have); records left
without files are dropped.
"""
function unique_files(records)
    seen = Set{String}()
    unique = Tuple{String,String,Vector}[]
    for (d, s, es) in records
        es = filter(e -> !(e["storage_path"] in seen), es)
        union!(seen, e["storage_path"] for e in es)
        isempty(es) || push!(unique, (d, s, es))
    end
    return unique
end

"""
    list_crops_table(crops)

Print the records by cropping, one line per nest or crop: its parent domain and the
datasets.
"""
function list_crops_table(crops)
    folders = unique(c.folder for c in crops)
    w = maximum(length, folders) + 2
    wp = maximum(c -> length(c.parent), crops) + 2
    println("By cropping (products of the parent domain without a record on the nest or crop, cut by fetch):")
    println(rpad("Domain", w), rpad("From", wp), "Datasets")
    for f in folders
        cs = filter(c -> c.folder == f, crops)
        println(rpad(f, w), rpad(first(cs).parent, wp), join((c.dataset for c in cs), " "))
    end
end

"""
    crop_detail(c; grids=String[], dir=nothing, sandbox=false)

Print a record by cropping: the release of its parent record, and for each grid (all,
or those of `grids`) the parent grid, its download size, and the files to crop, with
whether they are in \$ICE_DATA, or in `dir` (`fetch` checks that they are the crops of
the current parent files).
"""
function crop_detail(c::CropRecord; grids=String[], dir=nothing, sandbox::Bool=false)
    tables, files = read_record(c.parent, c.dataset; sandbox=sandbox)
    release = tables["_RELEASE"]
    println("$(c.folder)/$(c.dataset), by cropping $(c.parent)/$(c.dataset), version $(release["version"]) ",
            "($(release["git_tag"])), released $(release["date"])")
    println("$(length(c.products)) products without a record on $(c.folder): fetch downloads them on $(c.parent) ",
            "and cuts them to $(c.folder)")
    have_local = dir !== nothing || haskey(ENV, "ICE_DATA")
    have_local || println("(ICE_DATA is not set: local files not checked)")
    where = dir === nothing ? "\$ICE_DATA" : local_root(dir)
    root = have_local ? local_root(dir) : ""
    counts = Dict("present" => 0, "missing" => 0)
    n, size = 0, 0
    for (pgrid, entries) in record_grids(files)
        grid = crop_grid_name(c, pgrid)
        isempty(grids) || grid in grids || continue
        targets = crop_data_files(c, last.(entries), root)
        isempty(targets) && continue
        n += length(targets)
        size += total_size(first.(targets))
        println("\n", rpad(grid, 16), length(targets), " files, cut from $pgrid (",
                human_size(total_size(first.(targets))), ")")
        for (_, path) in targets
            state = ""
            if have_local
                state = isfile(path) ? "present" : "missing"
                counts[state] += 1
            end
            println("  ", rpad(basename(path), 40), "  ", state)
        end
    end
    println("\nTotal: $n files, cut from $(c.parent)/$(c.dataset) ($(human_size(size)))",
            have_local ? " (in $where: $(counts["present"]) present, $(counts["missing"]) missing)" : "")
    println("Download: julia fesmdata.jl fetch $(c.folder) $(c.dataset)", isempty(grids) ? " [GRID ...]" : " " * join(grids, " "))
end

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

"""
    select_records(args; sandbox=false) -> (selected, cropped, detail)

Records named by the arguments of `list` and `fetch`, in any order: a dataset, a
domain, and grids, which imply their domain (grid names are unique). Returns the
(domain, dataset, grids) of each matching record of the registry, the (record, grids)
of each matching record by cropping (`CropRecord`), with the named grids that each
has, and whether a single record or grids were named (to show them in detail).
"""
function select_records(args; sandbox::Bool=false)
    records = list_records(; sandbox=sandbox)
    files_of = Dict(r => read_record(r...; sandbox=sandbox)[2] for r in records)
    crops = crop_records(files_of)
    grids_of = Dict(r => unique(entry_grid(e) for e in values(files_of[r])) for r in records)
    crop_grids_of = Dict(c => crop_grids(c, files_of[(c.parent, c.dataset)]) for c in crops)
    datasets = Set(last.(records))
    domains = union(Set(first.(records)), (c.folder for c in crops))
    grid_domain = Dict{String,String}()
    foreach(((r, gs),) -> foreach(g -> grid_domain[g] = first(r), gs), grids_of)
    foreach(((c, gs),) -> foreach(g -> grid_domain[g] = c.folder, gs), crop_grids_of)
    domain = filter(in(domains), args)
    dataset = filter(in(datasets), args)
    grids = filter(a -> !(a in domains) && !(a in datasets), args)
    unknown = filter(g -> !haskey(grid_domain, g), grids)
    isempty(unknown) || error("unknown $(join(unknown, ", ")): not a dataset ($(join(sort(collect(datasets)), ", "))), " *
                              "domain ($(join(sort(collect(domains)), ", "))) or grid (e.g. ANT-32KM)")
    (length(domain) > 1 || length(dataset) > 1) && error("give at most one domain and one dataset")
    isempty(domain) || all(g -> grid_domain[g] == only(domain), grids) ||
        error("grids $(join(grids, ", ")) are not all on $(only(domain))")
    # A record is selected with the named grids it has, if grids are named
    matches(d, s, gs) = (isempty(domain) || d in domain) && (isempty(dataset) || s in dataset) &&
                        (isempty(grids) || any(in(gs), grids))
    selected = [(d, s, filter(in(grids_of[(d, s)]), grids)) for (d, s) in records if matches(d, s, grids_of[(d, s)])]
    cropped = [(c, filter(in(crop_grids_of[c]), grids)) for c in crops if matches(c.folder, c.dataset, crop_grids_of[c])]
    absent = setdiff(grids, (g for (_, _, gs) in selected for g in gs), (g for (_, gs) in cropped for g in gs))
    isempty(absent) || error("no record$(isempty(dataset) ? "" : " of " * only(dataset)) on $(join(absent, ", "))")
    return selected, cropped, !isempty(grids) || (length(domain) == 1 && length(dataset) == 1)
end

"""
    list(args; dir=nothing, sandbox=false)

`fesmdata.jl list`: all records, or those of a dataset and/or a domain, and the records
by cropping on nests and crops; with a domain and a dataset, or with grids, the records
in detail (for those grids), with the local files in \$ICE_DATA/v2 or `dir`.
"""
function list(args; dir=nothing, sandbox::Bool=false)
    selected, cropped, detail = select_records(args; sandbox=sandbox)
    isempty(selected) && isempty(cropped) && (println("No records"); return)
    if !detail
        isempty(selected) || list_records_table([(d, s) for (d, s, _) in selected]; sandbox=sandbox)
        isempty(selected) || isempty(cropped) || println()
        isempty(cropped) || list_crops_table(first.(cropped))
        return
    end
    shows = [[() -> record_detail(d, s; grids=grids, dir=dir, sandbox=sandbox) for (d, s, grids) in selected];
             [() -> crop_detail(c; grids=grids, dir=dir, sandbox=sandbox) for (c, grids) in cropped]]
    for (k, show) in enumerate(shows)
        k > 1 && println("\n", "-"^60, "\n")
        show()
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
    download_records(records, root, states; sources=Dict(), copy=false, copy_registry=false,
                     overwrite=false, sandbox=false) -> Vector{String}

Get the files of `records`, (domain, dataset, entries), that are not present under
`root`, with the `states` of `check_local`: from `sources` (see `local_sources`; hard
linked, or copied with `copy`), else downloaded (see `fetch_file`). With
`copy_registry` (a copy in another folder than \$ICE_DATA/v2), the registry files of
the records are copied to `root`/registry/, as a record of the releases it holds.
Returns the local paths.
"""
function download_records(records, root::AbstractString, states::AbstractDict; sources::AbstractDict=Dict(),
                          copy::Bool=false, copy_registry::Bool=false, overwrite::Bool=false,
                          sandbox::Bool=false)
    paths = String[]
    for (d, s, es) in records
        println("\n$d/$s")
        for e in es
            target = local_path(e, root)
            path, status = fetch_file(e, root; overwrite=overwrite, state=states[target],
                                      source=get(sources, target, nothing), copy=copy)
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
    fetch_files(args; dir=nothing, copy=false, overwrite=false, sandbox=false) -> (paths, cropped)

`fesmdata.jl fetch`: download the files of a dataset on a domain, or on grids (which
imply their domain), into \$ICE_DATA/v2 or `dir`. The dataset must be named, and a
domain or grids. The files present are checked first, as by `mirror`, and files in
\$ICE_DATA/v2 are hard linked (or copied with `copy`) into `dir`, as by `mirror`. On a
nest or crop without a record of the dataset, the files of its parent domain are
downloaded (`crop_sources`), and the records by cropping, `cropped`, are left for
`crop_files` (crop.jl, in the Publish environment). Returns the local paths of the
downloaded files, and `cropped`.
"""
function fetch_files(args; dir=nothing, copy::Bool=false, overwrite::Bool=false, sandbox::Bool=false)
    selected, cropped, detail = select_records(args; sandbox=sandbox)
    isempty(selected) && isempty(cropped) && error("fetch: no record of $(join(args, ", "))")
    datasets = unique([[s for (_, s, _) in selected]; [c.dataset for (c, _) in cropped]])
    length(datasets) == 1 && only(datasets) in args || error("fetch: name the dataset (e.g. Topo)")
    detail || error("fetch: name a domain or grids (e.g. Antarctica, ANT-32KM)")
    root = local_root(dir)
    records = unique_files([selected_entries(selected; sandbox=sandbox); crop_sources(cropped; sandbox=sandbox)])
    entries = [e for (_, _, es) in records for e in es]
    states = check_local(entries, root; overwrite=overwrite)
    sources = local_sources(entries, root, states)
    paths = download_records(records, root, states; sources=sources, copy=copy, copy_registry=dir !== nothing,
                             overwrite=overwrite, sandbox=sandbox)
    return paths, cropped
end

"""
    mirror(args; dir=nothing, copy=false, overwrite=false, sandbox=false, yes=false) -> Vector{String}

`fesmdata.jl mirror`: download all records (or those of a dataset and/or a domain)
into \$ICE_DATA/v2, or `dir`; the records of the registry only (the records by
cropping are made by `fetch`). The files present are checked first (checksums): files
of the release are kept, files of an earlier release are updated, and files changed
locally stop the mirror (replaced with `overwrite`). Into `dir`, files of the release
in \$ICE_DATA/v2 are hard linked from there (copied with `copy`, or on another file
system), e.g. to archive the releases there before updating it. Then, after one
confirmation (none with `yes`) showing what is to get, the missing and outdated files are downloaded.
"""
function mirror(args; dir=nothing, copy::Bool=false, overwrite::Bool=false, sandbox::Bool=false, yes::Bool=false)
    selected, cropped, _ = select_records(args; sandbox=sandbox)
    isempty(cropped) || println("Not mirrored: $(length(cropped)) records by cropping, on nests and crops (made by fetch)")
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
    return download_records(records, root, states; sources=sources, copy=copy, copy_registry=dir !== nothing,
                            overwrite=overwrite, sandbox=sandbox)
end
