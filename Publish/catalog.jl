# Catalogue of the released products, from the registry: the records, and the grids and
# files of a record, for `fesmdata.jl list` and the website, and the records by cropping
# (products of nests and crops, made by `fetch` from the records of their parent domain
# or of a crop that contains them). Standard library only.

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

"Datasets of datasets.toml (without the tables of settings, `_*`)."
read_site_datasets() = filter(p -> !startswith(first(p), "_"), read_datasets())

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
    isempty(records) && (println("Nothing released"); return)
    rows = []
    for (domain, dataset) in records
        tables, files = read_record(domain, dataset; sandbox=sandbox)
        release = tables["_RELEASE"]
        push!(rows, ("$domain/$dataset", release["version"], release["date"], human_size(total_size(values(files))),
                     record_doi(tables), join(first.(record_grids(files)), " ")))
    end
    with_doi = any(r -> !isempty(r[5]), rows)
    w = maximum(length(r[1]) for r in rows) + 2
    println(rpad("Domain/Dataset", w), rpad("Version", 9), rpad("Released", 12), rpad("Size", 10),
            with_doi ? rpad("DOI", 26) : "", "Grids (fine to coarse)")
    for r in rows
        println(rpad(r[1], w), rpad(r[2], 9), rpad(r[3], 12), rpad(r[4], 10), with_doi ? rpad(r[5], 26) : "", r[6])
    end
end

"""
    record_detail(domain, dataset; grids=String[], dir=nothing, sandbox=false)

Print a record: its release, and the files of each grid (all grids, or those of
`grids`) with their sizes and whether they are in \$FESMDATA, or in `dir` (by size;
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
    dataset == GRIDS || domain == RECORDS_FOLDER ||
        println("Grid files: in the record of $GRIDS on $domain (fetch gets them with the products)")
    doi = record_doi(tables)
    isempty(doi) || println("DOI: https://doi.org/$doi")
    have_local = dir !== nothing || has_fesmdata_dir("products")
    have_local || println("(FESMDATA is not set: local files not checked)")
    where = have_local ? local_root(dir) : ""
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

Products of a thematic dataset (made by remapping, e.g. GHF) on a nest or crop (output
folder `folder`, grids named after `key`) cut from the record of another domain that
has them, its source (folder `source`, grids named after `source_key`): its parent
domain, or a crop of its parent that contains it (e.g. Greenland for the nests of
GreenlandPaleo, see `crop_sources`). `fetch` makes them from the files of the source
record, cut to the nest or crop on each of its grids (see crop.jl), so that thematic
products are released once. `products` are the names of the products (files without
the grid, `product_name`). (Topo and Regions are made on every domain from the sources,
nests included.)
"""
struct CropRecord
    folder::String
    dataset::String
    key::String
    source::String
    source_key::String
    products::Vector{String}
end

"""
    sub_domains() -> Dict{String,NamedTuple}

The nests and crops of ../shared/domains.toml (also the crops of nests) by output
folder: their `key`, whether they are a crop (`crop`), the `key` and folder (`parent`)
of their parent domain, their `extent`, the cell edges of their base grid (x0, x1, y0,
y1, km), and whether they are `active` (a nest as its parent unless set, a crop as its
domain).
"""
function sub_domains()
    subs = Dict{String,NamedTuple}()
    function add!(key, d, kinds, active)
        for kind in kinds, (k, sub) in get(d, kind, Dict())
            # The base grid of a nest is its own, that of a crop the base grid of its domain
            h = (kind == "nests" ? sub : d)["resolutions"][1] / 2
            extent = (sub["xlim"][1] - h, sub["xlim"][2] + h, sub["ylim"][1] - h, sub["ylim"][2] + h)
            subs[sub["folder"]] = (key=k, crop=kind == "crops", parent_key=key, parent=d["folder"], extent=extent,
                                   active=kind == "nests" ? get(sub, "active", active) : active)
        end
    end
    for (key, d) in TOML.parsefile(joinpath(REPO_DIR, "shared", "domains.toml"))
        active = get(d, "active", true)
        add!(key, d, ("crops", "nests"), active)
        for (nkey, n) in get(d, "nests", Dict())
            add!(nkey, n, ("crops",), get(n, "active", active))
        end
    end
    return subs
end

"""
    crop_sources(folder, subs=sub_domains()) -> Vector{Tuple{String,String}}

Domains whose products a nest or crop (output folder `folder`) gets by cropping, as
(folder, key), by precedence: its parent domain, then the other crops of its parent
whose extent contains its own (e.g. Greenland, a crop of GreenlandPaleo, for its nests
Jakobshavn, NEGIS, ...). Whether these cover it on each grid is checked when cropping
(crop.jl).
"""
function crop_sources(folder::AbstractString, subs::AbstractDict=sub_domains())
    sub = subs[folder]
    inside(a, b) = b[1] <= a[1] && a[2] <= b[2] && b[3] <= a[3] && a[4] <= b[4]
    siblings = sort([(f, s.key) for (f, s) in subs
                     if s.crop && f != folder && s.parent == sub.parent && inside(sub.extent, s.extent)])
    return [(sub.parent, sub.parent_key); siblings]
end

"""
    crop_records(files_of) -> Vector{CropRecord}

The records by cropping, for the records of the registry (their files by (domain,
dataset), see `read_record`): for each thematic dataset on each nest and crop, the
products that its own record of the dataset (if any) does not have, from the records of
its sources (`crop_sources`) in their order of precedence (a product from the first
source that has it).
"""
function crop_records(files_of::AbstractDict)
    crops = CropRecord[]
    subs = sub_domains()
    datasets = sort(unique(s for (_, s) in keys(files_of) if is_remap_dataset(s)))
    for folder in sort(collect(keys(subs))), s in datasets
        have = Set(product_names(get(files_of, (folder, s), Dict())))
        for (source, skey) in crop_sources(folder, subs)
            haskey(files_of, (source, s)) || continue
            products = setdiff(product_names(files_of[(source, s)]), have)
            isempty(products) && continue
            push!(crops, CropRecord(folder, s, subs[folder].key, source, skey, products))
            union!(have, products)
        end
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

"Whether a registry entry of the source record of `c` is of one of its products."
is_crop_product(c, e::AbstractDict) = is_data_file(e) && product_name(e) in c.products

"Grids of a record by cropping, from the files of its source record (fine to coarse)."
crop_grids(c, pfiles::AbstractDict) =
    [crop_grid_name(c, g) for (g, es) in record_grids(pfiles) if any(p -> is_crop_product(c, last(p)), es)]

"Grid of a record by cropping for a grid of its source record: ANT-4KM -> THW-4KM."
crop_grid_name(c::CropRecord, grid::AbstractString) = c.key * _chop_key(grid, c.source_key)

"Grid of the source record for a grid of a record by cropping: THW-4KM -> ANT-4KM."
source_grid_name(c::CropRecord, grid::AbstractString) = c.source_key * _chop_key(grid, c.key)

"File of a record by cropping for a file of its source record: ANT-4KM_GHF-x.nc -> THW-4KM_GHF-x.nc."
crop_file_name(c::CropRecord, name::AbstractString) = c.key * _chop_key(name, c.source_key)

"""
    crop_data_files(c, entries, root) -> Vector

The files of record by cropping `c` for `entries` of its source record, under `root`:
source entry => local path of the file of each of its products (the grid files are
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
    grids_entries(domain, grids; sandbox=false) -> Vector

Entries of the grid files of `grids` in the record of Grids of a domain (those it has;
none without a record).
"""
function grids_entries(domain::AbstractString, grids; sandbox::Bool=false)
    isfile(registry_file(domain, GRIDS; sandbox=sandbox)) || return Any[]
    files = read_record(domain, GRIDS; sandbox=sandbox)[2]
    return [files[name] for name in sort(collect(keys(files))) if entry_grid(files[name]) in grids]
end

"""
    grids_downloads(selected; sandbox=false) -> Vector

The grid files that `fetch` downloads with the records `selected` ((domain, dataset,
grids), see `select_records`), as (domain, "Grids", entries): those of their grids (the
named grids, else all grids of the record) in the record of Grids of their domain.
"""
function grids_downloads(selected; sandbox::Bool=false)
    downloads = Tuple{String,String,Vector}[]
    for (d, s, grids) in selected
        s == GRIDS && continue
        gs = isempty(grids) ? unique(entry_grid(e) for e in values(read_record(d, s; sandbox=sandbox)[2])) : grids
        es = grids_entries(d, gs; sandbox=sandbox)
        isempty(es) || push!(downloads, (d, GRIDS, es))
    end
    return downloads
end

"""
    crop_downloads(cropped; sandbox=false) -> Vector

What `fetch` downloads for records by cropping, `cropped` ((record, grids) of
`select_records`), as (domain, dataset, entries): the files of their products in their
source records on these grids (all if none are named; not the grid files of the source,
which cropping does not need), and the grid files of the nest or crop on these grids, in
its record of Grids, so that these are the released files rather than files written
again. A file may be in several of these (see `unique_files`).
"""
function crop_downloads(cropped; sandbox::Bool=false)
    sources = Tuple{String,String,Vector}[]
    for (c, grids) in cropped
        pentries = filter(e -> is_crop_product(c, e),
                          record_entries(c.source, c.dataset; grids=[source_grid_name(c, g) for g in grids], sandbox=sandbox))
        push!(sources, (c.source, c.dataset, pentries))
        es = grids_entries(c.folder, Set(crop_grid_name(c, entry_grid(e)) for e in pentries); sandbox=sandbox)
        isempty(es) || push!(sources, (c.folder, GRIDS, es))
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

Print the records by cropping, one line per nest or crop: the domains they are cut from
and the datasets.
"""
function list_crops_table(crops)
    folders = unique(c.folder for c in crops)
    from = Dict(f => join(unique(c.source for c in crops if c.folder == f), ", ") for f in folders)
    w = maximum(length, folders) + 2
    wf = maximum(length, values(from)) + 2
    println("By cropping (products of other domains not released on the nest or crop, cut by fetch):")
    println(rpad("Domain", w), rpad("From", wf), "Datasets")
    for f in folders
        println(rpad(f, w), rpad(from[f], wf), join(unique(c.dataset for c in crops if c.folder == f), " "))
    end
end

"""
    crop_detail(c; grids=String[], dir=nothing, sandbox=false)

Print a record by cropping: the release of its source record, and for each grid (all,
or those of `grids`) the source grid, its download size, and the files to crop, with
whether they are in \$FESMDATA, or in `dir` (`fetch` checks that they are the crops of
the current source files).
"""
function crop_detail(c::CropRecord; grids=String[], dir=nothing, sandbox::Bool=false)
    tables, files = read_record(c.source, c.dataset; sandbox=sandbox)
    release = tables["_RELEASE"]
    println("$(c.folder)/$(c.dataset), by cropping $(c.source)/$(c.dataset), version $(release["version"]) ",
            "($(release["git_tag"])), released $(release["date"])")
    println("$(length(c.products)) products not released on $(c.folder): fetch downloads them on $(c.source) ",
            "and cuts them to $(c.folder)")
    have_local = dir !== nothing || has_fesmdata_dir("products")
    have_local || println("(FESMDATA is not set: local files not checked)")
    where = have_local ? local_root(dir) : ""
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
    println("\nTotal: $n files, cut from $(c.source)/$(c.dataset) ($(human_size(size)))",
            have_local ? " (in $where: $(counts["present"]) present, $(counts["missing"]) missing)" : "")
    println("Download: julia fesmdata.jl fetch $(c.folder) $(c.dataset)", isempty(grids) ? " [GRID ...]" : " " * join(grids, " "))
end

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

"Edit distance (Levenshtein) between two strings, ignoring case."
function edit_distance(a::AbstractString, b::AbstractString)
    a, b = collect(lowercase(a)), collect(lowercase(b))
    d = collect(0:length(b))
    for i in eachindex(a)
        prev, d[1] = d[1], i
        for j in eachindex(b)
            prev, d[j+1] = d[j+1], min(d[j+1] + 1, d[j] + 1, prev + (a[i] != b[j]))
        end
    end
    return d[end]
end

"The names of `names` close to `name` (edit distance at most a third of its length), closest first, at most `n`."
function close_names(name::AbstractString, names; n::Integer=5)
    tol = max(1, length(name) ÷ 3)
    found = sort([(edit_distance(name, x), x) for x in unique(names)])
    return first(last.(filter(p -> first(p) <= tol, found)), n)
end

"""
    RegistryCatalog

The records of the registry and the names that select them on the command line:
`records` ((domain, dataset) pairs), their files (`files_of`, see `read_record`) and
grids (`grids_of`), the records by cropping (`crops`) and their grids
(`crop_grids_of`), the names of the `datasets` and `domains` (also of the nests and
crops with records by cropping), and the domain of each grid (`grid_domain`; grid
names are unique).
"""
struct RegistryCatalog
    records::Vector{Tuple{String,String}}
    files_of::Dict{Tuple{String,String},Dict{String,Any}}
    grids_of::Dict{Tuple{String,String},Vector{String}}
    crops::Vector{CropRecord}
    crop_grids_of::Dict{CropRecord,Vector{String}}
    datasets::Set{String}
    domains::Set{String}
    grid_domain::Dict{String,String}
end

function RegistryCatalog(; sandbox::Bool=false)
    records = list_records(; sandbox=sandbox)
    files_of = Dict(r => read_record(r...; sandbox=sandbox)[2] for r in records)
    crops = crop_records(files_of)
    grids_of = Dict(r => unique(entry_grid(e) for e in values(files_of[r])) for r in records)
    crop_grids_of = Dict(c => crop_grids(c, files_of[(c.source, c.dataset)]) for c in crops)
    grid_domain = Dict{String,String}()
    foreach(((r, gs),) -> foreach(g -> grid_domain[g] = first(r), gs), grids_of)
    foreach(((c, gs),) -> foreach(g -> grid_domain[g] = c.folder, gs), crop_grids_of)
    return RegistryCatalog(records, files_of, grids_of, crops, crop_grids_of, Set(last.(records)),
                           union(Set(first.(records)), (c.folder for c in crops)), grid_domain)
end

"Whether `name` names a dataset, domain or grid of the registry."
is_registry_name(cat::RegistryCatalog, name::AbstractString) =
    name in cat.datasets || name in cat.domains || haskey(cat.grid_domain, name)

"Error for arguments that name no dataset, domain or grid, with the close names and a hint to search the products."
function unknown_names_error(cat::RegistryCatalog, unknown)
    names = [collect(cat.datasets); collect(cat.domains); collect(keys(cat.grid_domain))]
    lines = map(unknown) do u
        close = close_names(u, names)
        "unknown $u" * (isempty(close) ? "" : ", did you mean $(join(close, ", "))?")
    end
    error(join(lines, "\n"), "\nDatasets: $(join(sort(collect(cat.datasets)), ", "))\n",
          "Domains: $(join(sort(collect(cat.domains)), ", "))\nGrids: e.g. ANT-32KM\n",
          "Search the products (names, sources, references, variables): julia fesmdata.jl search $(join(unknown, " "))")
end

"""
    select_records(args; sandbox=false) -> (selected, cropped, detail)

Records named by the arguments of `list` and `fetch`, in any order: a dataset, a
domain, and grids, which imply their domain (grid names are unique). Returns the
(domain, dataset, grids) of each matching record of the registry, the (record, grids)
of each matching record by cropping (`CropRecord`), with the named grids that each
has, and whether a single record or grids were named (to show them in detail).
"""
select_records(args; sandbox::Bool=false) = select_records(RegistryCatalog(; sandbox=sandbox), args)

function select_records(cat::RegistryCatalog, args)
    (; records, grids_of, crops, crop_grids_of, datasets, domains, grid_domain) = cat
    unknown = filter(a -> !is_registry_name(cat, a), args)
    isempty(unknown) || unknown_names_error(cat, unknown)
    domain = filter(in(domains), args)
    dataset = filter(in(datasets), args)
    grids = filter(a -> !(a in domains) && !(a in datasets), args)
    (length(domain) > 1 || length(dataset) > 1) && error("give at most one domain and one dataset")
    isempty(domain) || all(g -> grid_domain[g] == only(domain), grids) ||
        error("grids $(join(grids, ", ")) are not all on $(only(domain))")
    # A record is selected with the named grids it has, if grids are named
    matches(d, s, gs) = (isempty(domain) || d in domain) && (isempty(dataset) || s in dataset) &&
                        (isempty(grids) || any(in(gs), grids))
    selected = [(d, s, filter(in(grids_of[(d, s)]), grids)) for (d, s) in records if matches(d, s, grids_of[(d, s)])]
    cropped = [(c, filter(in(crop_grids_of[c]), grids)) for c in crops if matches(c.folder, c.dataset, crop_grids_of[c])]
    absent = setdiff(grids, (g for (_, _, gs) in selected for g in gs), (g for (_, gs) in cropped for g in gs))
    isempty(absent) || error("nothing released$(isempty(dataset) ? "" : " of " * only(dataset)) on $(join(absent, ", "))")
    return selected, cropped, !isempty(grids) || (length(domain) == 1 && length(dataset) == 1)
end

"""
    list_outdated(selected; dir=nothing, sandbox=false)

`fesmdata.jl list --outdated`: the local files of the records `selected` ((domain,
dataset, grids), see `select_records`) in \$FESMDATA or `dir` that are not of
their release (checksums): of an earlier release, or changed locally, with the commands
to update them. The files missing are not listed, nor the products by cropping (`fetch`
cuts them again from the current files of their source).
"""
function list_outdated(selected; dir=nothing, sandbox::Bool=false)
    root = local_root(dir)
    println("Checking the files in $root (checksums)")
    n = Dict(:current => 0, :older => 0, :changed => 0)
    for (d, s, grids) in selected
        states = [e => local_state(e, root) for e in record_entries(d, s; grids=grids, sandbox=sandbox)
                  if isfile(local_path(e, root))]
        foreach(((_, st),) -> n[st] += 1, states)
        outdated = filter(((_, st),) -> st != :current, states)
        isempty(outdated) && continue
        println("\n$d/$s, version $(read_record(d, s; sandbox=sandbox)[1]["_RELEASE"]["version"])")
        w = maximum(((e, _),) -> length(basename(e["storage_path"])), outdated) + 2
        for (e, st) in outdated
            println("  ", rpad(basename(e["storage_path"]), w), st == :older ? "earlier release" : "changed locally")
        end
        target = d == RECORDS_FOLDER ? d : join(unique(entry_grid(e) for (e, _) in outdated), " ")
        println("Update: julia fesmdata.jl fetch $s $target", any(((_, st),) -> st == :changed, outdated) ? " --overwrite" : "")
    end
    println("\n$(n[:current]) files current, $(n[:older]) of earlier releases, $(n[:changed]) changed locally")
end

"""
    list(args; dir=nothing, sandbox=false, outdated=false)

`fesmdata.jl list`: all records, or those of a dataset and/or a domain, and the records
by cropping on nests and crops; with a domain and a dataset, or with grids, the records
in detail (for those grids), with the local files in \$FESMDATA or `dir`. With
`outdated`, the local files of these records that are not of their release
(`list_outdated`).
"""
function list(args; dir=nothing, sandbox::Bool=false, outdated::Bool=false)
    selected, cropped, detail = select_records(args; sandbox=sandbox)
    outdated && return list_outdated(selected; dir=dir, sandbox=sandbox)
    isempty(selected) && isempty(cropped) && (println("Nothing released"); return)
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

For a copy in another folder than \$FESMDATA (`root`): the files of `entries` to get
that are in \$FESMDATA at the same release (checksums), to hard link or copy from
there instead of downloading them (local path under `root` => path in \$FESMDATA).
"""
function local_sources(entries, root::AbstractString, states::AbstractDict)
    sources = Dict{String,String}()
    has_fesmdata_dir("products") && root != products_dir() || return sources
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
`copy_registry` (a copy in another folder than \$FESMDATA), the registry files of
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
imply their domain), with the grid files of these grids (`grids_downloads`), into
\$FESMDATA or `dir`. The dataset must be named, and a domain or grids. The files present are checked first, as by `mirror`, and files in
\$FESMDATA are hard linked (or copied with `copy`) into `dir`, as by `mirror`. On a
nest or crop, the files of the products it gets by cropping are downloaded on their
source domains (`crop_downloads`), and the records by cropping, `cropped`, are left for
`crop_files` (crop.jl, in the Publish environment). Returns the local paths of the
downloaded files, and `cropped`.
"""
function fetch_files(args; dir=nothing, copy::Bool=false, overwrite::Bool=false, sandbox::Bool=false)
    selected, cropped, detail = select_records(args; sandbox=sandbox)
    isempty(selected) && isempty(cropped) && error("fetch: nothing released of $(join(args, ", "))")
    datasets = unique([[s for (_, s, _) in selected]; [c.dataset for (c, _) in cropped]])
    length(datasets) == 1 && only(datasets) in args || error("fetch: name the dataset (e.g. Topo)")
    detail || error("fetch: name a domain or grids (e.g. Antarctica, ANT-32KM)")
    root = local_root(dir)
    records = unique_files([grids_downloads(selected; sandbox=sandbox); selected_entries(selected; sandbox=sandbox);
                            crop_downloads(cropped; sandbox=sandbox)])
    entries = [e for (_, _, es) in records for e in es]
    states = check_local(entries, root; overwrite=overwrite)
    sources = local_sources(entries, root, states)
    paths = download_records(records, root, states; sources=sources, copy=copy, copy_registry=dir !== nothing,
                             overwrite=overwrite, sandbox=sandbox)
    return paths, cropped
end

"""
    mirror(args; dir=nothing, copy=false, overwrite=false, sandbox=false, yes=false) -> (paths, cropped)

`fesmdata.jl mirror`: download all records (or those of a dataset and/or a domain)
into \$FESMDATA, or `dir`, with the grid files of their grids (`grids_downloads`)
and the files that the records by cropping on the active nests and crops need
(`crop_downloads`). The files present are checked first
(checksums): files of the release are kept, files of an earlier release are updated,
and files changed locally stop the mirror (replaced with `overwrite`). Into `dir`, files
of the release in \$FESMDATA are hard linked from there (copied with `copy`, or
on another file system), e.g. to archive the releases there before updating it. Then,
after one confirmation (none with `yes`) showing what is to get, the missing and
outdated files are downloaded. Returns their local paths, and the records by cropping,
`cropped`, left for `crop_files` (crop.jl, in the Publish environment), as by `fetch`.
"""
function mirror(args; dir=nothing, copy::Bool=false, overwrite::Bool=false, sandbox::Bool=false, yes::Bool=false)
    selected, cropped, _ = select_records(args; sandbox=sandbox)
    subs = sub_domains()
    filter!(((c, _),) -> subs[c.folder].active, cropped)
    isempty(selected) && isempty(cropped) && (println("Nothing released"); return String[], cropped)
    root = local_root(dir)
    records = unique_files([grids_downloads(selected; sandbox=sandbox); selected_entries(selected; sandbox=sandbox);
                            crop_downloads(cropped; sandbox=sandbox)])
    entries = [e for (_, _, es) in records for e in es]
    println("$(length(selected)) datasets on domains and $(length(cropped)) by cropping on nests and crops, ",
            "$(length(entries)) files to keep, $(human_size(total_size(entries))) in total")
    states = check_local(entries, root; overwrite=overwrite)
    sources = local_sources(entries, root, states)
    todo = filter(e -> states[local_path(e, root)] != :current, entries)
    to_download = filter(e -> !haskey(sources, local_path(e, root)), todo)
    yes || isempty(todo) || confirm("Get $(length(todo)) files into $root " *
                                    "($(human_size(total_size(to_download))) to download)?") ||
        (println("Nothing downloaded."); return String[], empty(cropped))
    paths = download_records(records, root, states; sources=sources, copy=copy, copy_registry=dir !== nothing,
                             overwrite=overwrite, sandbox=sandbox)
    return paths, cropped
end
