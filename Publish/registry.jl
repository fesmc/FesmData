# Registry of the released products. Each record (one dataset on one domain) has a
# registry file, registry/<Domain>/<Dataset>.toml, with one entry per file (uri,
# checksum, size, storage_path), the release in a `[_RELEASE]` table (version, tag,
# date, store), and, if the release is archived on Zenodo, its DOIs in a `[_ZENODO]`
# table. The files are DataManifest.jl databases, with `$datasets_dir` = $FESMDATA_PRODUCTS.
# Test releases (test packages, Zenodo sandbox) have their registry in
# registry/_sandbox/, which is not tracked. Uses only the Julia standard library, so
# that fetch.jl runs without a project.

using Downloads
using SHA
using TOML

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))

"Registry folder, of the test releases with `sandbox`."
registry_dir(sandbox::Bool=false) =
    sandbox ? joinpath(REPO_DIR, "registry", "_sandbox") : joinpath(REPO_DIR, "registry")

"Root of the products, \$FESMDATA_PRODUCTS, which `\$datasets_dir` in the registry stands for."
products_dir() = fesmdata_dir("products")

"Registry file of the record of a dataset on a domain."
registry_file(domain::AbstractString, dataset::AbstractString; sandbox::Bool=false) =
    joinpath(registry_dir(sandbox), domain, "$dataset.toml")

"All records in the registry, as (domain, dataset) pairs."
function list_records(; sandbox::Bool=false)
    dir = registry_dir(sandbox)
    records = Tuple{String,String}[]
    isdir(dir) || return records
    for domain in sort(readdir(dir))
        (startswith(domain, "_") || !isdir(joinpath(dir, domain))) && continue
        for f in sort(readdir(joinpath(dir, domain)))
            endswith(f, ".toml") && push!(records, (domain, f[1:end-5]))
        end
    end
    return records
end

"""
    read_record(domain, dataset; sandbox=false) -> (tables, files)

Metadata tables (`_RELEASE`, and `_ZENODO` if archived) and file entries (name =>
entry) of a record.
"""
function read_record(domain::AbstractString, dataset::AbstractString; sandbox::Bool=false)
    path = registry_file(domain, dataset; sandbox=sandbox)
    isfile(path) || error("no record $domain/$dataset, available: " *
                          join(["$d/$s" for (d, s) in list_records(; sandbox=sandbox)], ", "))
    reg = TOML.parsefile(path)
    tables = Dict(k => v for (k, v) in reg if startswith(k, "_"))
    files = Dict(k => v for (k, v) in reg if !startswith(k, "_"))
    return tables, files
end

"Write a registry file: the metadata tables first, then the entries by name."
function write_registry(path::AbstractString, tables::AbstractDict, entries::AbstractDict)
    mkpath(dirname(path))
    open(path, "w") do io
        println(io, "# Registry of a released record, written by Publish (see Publish/README.md).")
        for name in sort(collect(keys(tables)))
            println(io)
            TOML.print(io, Dict(name => tables[name]); sorted=true)
        end
        for name in sort(collect(keys(entries)))
            println(io)
            TOML.print(io, Dict(name => entries[name]); sorted=true)
        end
    end
    return path
end

function confirm(question::AbstractString)
    print(question, " [y/N] ")
    return lowercase(strip(readline())) in ("y", "yes")
end

"Root of the local files: `dir` if given (a folder for a copy, e.g. an archive), else \$FESMDATA_PRODUCTS."
local_root(dir::Nothing=nothing) = products_dir()
local_root(dir::AbstractString) = abspath(expanduser(dir))

"Local path of a registry entry, under `root` (\$FESMDATA_PRODUCTS by default)."
local_path(entry::AbstractDict, root::AbstractString=products_dir()) =
    replace(entry["storage_path"], r"^\$datasets_dir" => root)

"Grid of a registry entry: the folder of its storage path, <Domain>/<GRID>/<file>."
entry_grid(entry::AbstractDict) = basename(dirname(entry["storage_path"]))

"The dataset of the grid files, released once per grid for all datasets on it."
const GRIDS = "Grids"

"Grid files of a grid: its grid description for cdo and its grid file (x, y, lon, lat, area)."
grid_file_names(grid::AbstractString) = ["grid_$grid.txt", "$(grid)_grid.nc"]

file_sha256(path::AbstractString) = open(io -> bytes2hex(sha256(io)), path)

"Checksum of a file in the registry format, sha256:<hex>."
checksum(path::AbstractString) = "sha256:" * file_sha256(path)

"""
    previous_checksums(old, checksum, registered=String[]) -> Vector{String}

Checksums of the earlier releases of a file, for its entry in a new release with
`checksum`: those of its entry `old` in the previous registry (`nothing` for a new
file), and `registered`, those of the same local file in other records (e.g. the grid
files that each dataset released before Grids), without `checksum`.
"""
previous_checksums(old, checksum::AbstractString, registered=String[]) =
    unique(filter(!=(checksum), vcat(old === nothing ? String[] : get(old, "previous_checksums", String[]),
                                     old === nothing ? String[] : [old["checksum"]], sort(collect(registered)))))

"Checksums, current and earlier, of each local file (`storage_path`) in all records of the registry."
function path_checksums(; sandbox::Bool=false)
    sums = Dict{String,Set{String}}()
    for (d, s) in list_records(; sandbox=sandbox), e in values(read_record(d, s; sandbox=sandbox)[2])
        union!(get!(sums, e["storage_path"], Set{String}()), [e["checksum"]; get(e, "previous_checksums", String[])])
    end
    return sums
end

"""
    local_state(entry, root=products_dir()) -> Symbol

State of the local file of a registry entry under `root`, by its checksum: :missing,
:current (the release of the entry), :older (an earlier release of the file,
`previous_checksums`) or :changed (changed locally, or not of a release).
"""
function local_state(entry::AbstractDict, root::AbstractString=products_dir())
    path = local_path(entry, root)
    isfile(path) || return :missing
    sum = checksum(path)
    sum == entry["checksum"] && return :current
    sum in get(entry, "previous_checksums", String[]) && return :older
    return :changed
end

"""
    link_or_copy(src, dst; copy=false) -> Symbol

Hard link `src` at `dst` (no extra space), or copy it where a link is not possible (on
another file system) or with `copy`: :linked or :copied.
"""
function link_or_copy(src::AbstractString, dst::AbstractString; copy::Bool=false)
    copy && (cp(src, dst; force=true); return :copied)
    try
        hardlink(src, dst)
        return :linked
    catch e
        e isa Base.IOError || rethrow()
        cp(src, dst; force=true)
        return :copied
    end
end

"""
    fetch_file(entry, root=products_dir(); overwrite=false, state=local_state(entry, root),
               source=nothing, copy=false) -> (path, status)

Get the file of a registry entry under `root`: download it and verify its checksum, or,
with `source`, a local file of the same release (checksum verified), hard link it, or
copy it (with `copy`, or where a link is not possible). A file already present is kept if it is of the release of the entry, and replaced
if it is of an earlier release; a file changed locally is an error, or is replaced with
`overwrite`. The new file replaces the old one (a new file, so that hard links to the
old one keep it). `status` is :present, :downloaded, :updated, :linked or :copied.
"""
function fetch_file(entry::AbstractDict, root::AbstractString=products_dir(); overwrite::Bool=false,
                    state::Symbol=local_state(entry, root), source::Union{Nothing,AbstractString}=nothing,
                    copy::Bool=false)
    path = local_path(entry, root)
    state == :current && return path, :present
    state == :changed && !overwrite &&
        error("$path differs from the registry and from the earlier releases (changed locally); " *
              "use --overwrite to replace it")
    mkpath(dirname(path))
    tmp = path * ".part"
    rm(tmp; force=true)
    status = state == :missing ? :downloaded : :updated
    try
        if source === nothing
            Downloads.download(entry["uri"], tmp)
        else
            status = link_or_copy(source, tmp; copy=copy)
        end
        if status != :linked
            sum = checksum(tmp)
            sum == entry["checksum"] || error("checksum of $(something(source, entry["uri"])) is $sum, " *
                                              "expected $(entry["checksum"])")
        end
        mv(tmp, path; force=true)
    finally
        rm(tmp; force=true)
    end
    return path, status
end

"""
    record_entries(domain, dataset; grids=String[], sandbox=false) -> Vector

File entries of a record, by name, only those of `grids` if given.
"""
function record_entries(domain::AbstractString, dataset::AbstractString; grids=String[], sandbox::Bool=false)
    _, files = read_record(domain, dataset; sandbox=sandbox)
    available = sort(unique(entry_grid(e) for e in values(files)))
    unknown = setdiff(grids, available)
    isempty(unknown) || error("$domain/$dataset: no grids $(join(unknown, ", ")), available: $(join(available, ", "))")
    return [files[name] for name in sort(collect(keys(files))) if isempty(grids) || entry_grid(files[name]) in grids]
end
