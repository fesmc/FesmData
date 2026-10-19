# Prune the products folder: delete the files that no record of the registry refers to,
# except the products by cropping, the products not released and the grid files still in
# use. In the Publish environment (NCDatasets, for the attribute of the crops), with
# catalog.jl included.

using Dates
using NCDatasets

"Dataset of a product file by its name (ANT-8KM_GHF-Davies2013.nc: GHF; _TOPO-: Topo; _REGIONS, _BASINS-, _DOMAINS: Regions)."
function file_dataset(name::AbstractString)
    m = match(r"^[A-Za-z0-9.-]+?_([A-Za-z0-9]+)[-.]", name)
    m === nothing && return nothing
    tag = m.captures[1]
    return tag == "TOPO" ? "Topo" : tag in ("REGIONS", "BASINS", "DOMAINS") ? "Regions" : tag
end

"Products made but not released (`release = false` in <Dataset>/remap.toml), as <Dataset>-<name>."
function unreleased_products(datasets)
    names = Set{String}()
    for s in datasets
        is_remap_dataset(s) || continue
        for (p, spec) in get(TOML.parsefile(remap_spec_file(s)), "products", Dict())
            get(spec, "release", true) == false && push!(names, "$s-$p")
        end
    end
    return names
end

"Whether a file is a product by cropping (made by `fetch` or `mirror`, see crop.jl)."
is_crop_file(path::AbstractString) =
    endswith(path, ".nc") && isfile(path) && NCDataset(ds -> haskey(ds.attrib, "cropped_from"), path)

"Size of a file, or of a link (also a broken one) itself."
file_bytes(path::AbstractString) = lstat(path).size

"""
    prune(args; yes=false, sandbox=false) -> Vector{String}

`fesmdata.jl prune`: delete the files in \$FESMDATA (all, or those of a dataset
and/or a domain, named in any order) that no record of the registry refers to: products
no longer made (e.g. copies on a crop that now gets them by cropping, grids dropped by
the resolution rule) and files of grids that changed. Kept are:

- the files of the records of the registry;
- the products by cropping (with a `cropped_from` attribute), which `fetch` and `mirror`
  make and update;
- the products not released (`release = false` in <Dataset>/remap.toml);
- the grid files of a grid that keeps other files (with a dataset named: all grid files);
- the records datasets (Records/).

The files to delete are listed by domain and dataset with their size, and deleted after
one confirmation (none with `yes`); their list is written to
\$FESMDATA_WORK/prune-<date>.txt. Returns the deleted paths.
"""
function prune(args; yes::Bool=false, sandbox::Bool=false)
    root = products_dir()
    records = list_records(; sandbox=sandbox)
    datasets = sort(unique(last.(records)))
    folders = sort([f for f in readdir(root) if isdir(joinpath(root, f)) && f != RECORDS_FOLDER])
    dataset = filter(in(datasets), args)
    domain = filter(in(folders), args)
    unknown = setdiff(args, dataset, domain)
    isempty(unknown) || error("prune: unknown $(join(unknown, ", ")): give a dataset ($(join(datasets, ", "))) " *
                              "and/or a domain folder ($(join(folders, ", ")))")
    (length(dataset) > 1 || length(domain) > 1) && error("prune: give at most one dataset and one domain")

    registered = Set(local_path(e, root) for r in records for e in values(read_record(r...; sandbox=sandbox)[2]))
    unreleased = unreleased_products(datasets)
    is_unreleased(name) = any(p -> endswith(name, "_$p.nc"), unreleased)

    candidates = String[]
    for folder in (isempty(domain) ? folders : domain)
        for (dir, _, files) in walkdir(joinpath(root, folder))
            data = filter(f -> !is_grid_file(f), files)
            keep = filter(data) do f
                path = joinpath(dir, f)
                path in registered || is_unreleased(f) || is_crop_file(path) ||
                    (!isempty(dataset) && file_dataset(f) != only(dataset))
            end
            append!(candidates, joinpath.(dir, setdiff(data, keep)))
            # Grid files go with the last other file of their grid (not with a dataset named)
            isempty(keep) && isempty(dataset) &&
                append!(candidates, [joinpath(dir, f) for f in files if is_grid_file(f) && !(joinpath(dir, f) in registered)])
        end
    end
    isempty(candidates) && (println("Nothing to prune in $root"); return String[])

    groups = Dict{String,Vector{String}}()
    for path in candidates
        rel = relpath(path, root)
        name = basename(path)
        key = "$(splitpath(rel)[1]) | $(is_grid_file(name) ? "grid files" : something(file_dataset(name), "other"))"
        push!(get!(groups, key, String[]), path)
    end
    println("Files in $root that no record of the registry refers to:")
    for key in sort(collect(keys(groups)))
        println("  ", rpad(key, 44), lpad(length(groups[key]), 6), " files ", lpad(human_size(sum(file_bytes, groups[key])), 10))
    end
    println("$(length(candidates)) files, $(human_size(sum(file_bytes, candidates))) in total")
    yes || confirm("Delete them?") || (println("Nothing deleted."); return String[])

    list = joinpath(fesmdata_dir("work"), "prune-$(Dates.format(now(), "yyyy-mm-ddTHHMM")).txt")
    mkpath(dirname(list))
    write(list, join(relpath.(candidates, root), "\n") * "\n")
    foreach(rm, candidates)
    for folder in (isempty(domain) ? folders : domain), (dir, _, _) in walkdir(joinpath(root, folder); topdown=false)
        isempty(readdir(dir)) && rm(dir)
    end
    println("Deleted $(length(candidates)) files (list: $list)")
    return candidates
end
