# Registry of the published products. Each Zenodo record (one dataset on one domain
# folder) has a registry file, registry/<Domain>/<Dataset>.toml, with one entry per
# file (uri, checksum, size, storage_path) and the record metadata in a `[_ZENODO]`
# table. The files are DataManifest.jl databases, with `$datasets_dir` = $ICE_DATA/v2.

using Downloads
using SHA
using TOML

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))

const REGISTRY_DIR = joinpath(REPO_DIR, "registry")

"Root of the products, \$ICE_DATA/v2, which `\$datasets_dir` in the registry stands for."
products_dir() = joinpath(_env("ICE_DATA"), "v2")

"Registry file of the record of a dataset on a domain folder."
registry_file(domain::AbstractString, dataset::AbstractString) =
    joinpath(REGISTRY_DIR, domain, "$dataset.toml")

"All records in the registry, as (domain, dataset) pairs."
function list_records()
    records = Tuple{String,String}[]
    isdir(REGISTRY_DIR) || return records
    for domain in sort(readdir(REGISTRY_DIR))
        isdir(joinpath(REGISTRY_DIR, domain)) || continue
        for f in sort(readdir(joinpath(REGISTRY_DIR, domain)))
            endswith(f, ".toml") && push!(records, (domain, f[1:end-5]))
        end
    end
    return records
end

"""
    read_record(domain, dataset) -> (info, files)

Record metadata (the `[_ZENODO]` table) and file entries (name => entry) of a record.
"""
function read_record(domain::AbstractString, dataset::AbstractString)
    path = registry_file(domain, dataset)
    isfile(path) || error("no record $domain/$dataset, available: " *
                          join(["$d/$s" for (d, s) in list_records()], ", "))
    reg = TOML.parsefile(path)
    files = Dict(k => v for (k, v) in reg if !startswith(k, "_"))
    return get(reg, "_ZENODO", Dict{String,Any}()), files
end

"Local path of a registry entry, under \$ICE_DATA/v2."
local_path(entry::AbstractDict) =
    replace(entry["storage_path"], r"^\$datasets_dir" => products_dir())

"Grid of a registry entry: the folder of its storage path, <Domain>/<GRID>/<file>."
entry_grid(entry::AbstractDict) = basename(dirname(entry["storage_path"]))

file_sha256(path::AbstractString) = open(io -> bytes2hex(sha256(io)), path)

"Checksum of a file in the registry format, sha256:<hex>."
checksum(path::AbstractString) = "sha256:" * file_sha256(path)

"""
    fetch_file(entry; overwrite=false) -> (path, status)

Download the file of a registry entry and verify its checksum. A file already present
is kept if its checksum matches; otherwise it is an error, or it is replaced with
`overwrite`. `status` is :present or :downloaded.
"""
function fetch_file(entry::AbstractDict; overwrite::Bool=false)
    path = local_path(entry)
    if isfile(path)
        checksum(path) == entry["checksum"] && return path, :present
        overwrite || error("$path exists and differs from the registry (another version, or " *
                           "changed locally); use --overwrite to replace it")
    end
    mkpath(dirname(path))
    tmp = path * ".part"
    try
        Downloads.download(entry["uri"], tmp)
        sum = checksum(tmp)
        sum == entry["checksum"] || error("checksum of $(entry["uri"]) is $sum, expected $(entry["checksum"])")
        mv(tmp, path; force=true)
    finally
        rm(tmp; force=true)
    end
    return path, :downloaded
end

"""
    fetch_record(domain, dataset; grids=String[], overwrite=false) -> Vector{String}

Download the files of a record into \$ICE_DATA/v2/<Domain>/<GRID>/, only those of
`grids` if given (see `fetch_file`). Returns the local paths.
"""
function fetch_record(domain::AbstractString, dataset::AbstractString; grids=String[],
                      overwrite::Bool=false)
    _, files = read_record(domain, dataset)
    available = sort(unique(entry_grid(e) for e in values(files)))
    unknown = setdiff(grids, available)
    isempty(unknown) || error("$domain/$dataset: no grids $(join(unknown, ", ")), available: $(join(available, ", "))")
    paths = String[]
    for name in sort(collect(keys(files)))
        entry = files[name]
        isempty(grids) || entry_grid(entry) in grids || continue
        path, status = fetch_file(entry; overwrite=overwrite)
        println(rpad(string(status), 12), path)
        push!(paths, path)
    end
    return paths
end
