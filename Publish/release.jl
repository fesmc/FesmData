# Releases of the products (see README.md): the datasets, the files of a release of a
# dataset on a domain and their checks, and the HTTP requests to the store (GitLab,
# gitlab.jl) and the archive (Zenodo, zenodo.jl).

using JSON
using MD5
using NCDatasets

include(joinpath(@__DIR__, "registry.jl"))
include(joinpath(REPO_DIR, "shared", "domains.jl"))
include(joinpath(REPO_DIR, "shared", "precision.jl"))
include(joinpath(REPO_DIR, "Topo", "files.jl"))
include(joinpath(REPO_DIR, "Regions", "files.jl"))
include(joinpath(REPO_DIR, "Remap", "datasets.jl"))
include(joinpath(REPO_DIR, "Records", "datasets.jl"))
include(joinpath(REPO_DIR, "Records", "text.jl"))

"Output folders of the domains `keys`, with their crops."
key_folders(keys) = sort(unique(og.folder for key in keys for og in Domain(key).grids))

"""
    dataset_pipeline(dataset) -> (files, domains)

What the pipeline of a dataset releases: `files(domain)`, the files of a release on a
domain (output folder, a `Vector{ProductFile}`, present or not), and `domains()`, the
output folders of its domains. Topo and Regions have their own pipelines; thematic
datasets (<Dataset>/remap.toml) are made by remapping, on grids; records datasets
(<Dataset>/records.toml) are not gridded, and released on the domain `Records`; Grids
holds the grid files of the grids of all the others (`grids_files`).
"""
function dataset_pipeline(dataset::AbstractString)
    dataset == "Topo" && return (d -> gridded_files(d, topo_release_files), () -> key_folders(topo_domains()))
    dataset == "Regions" && return (d -> gridded_files(d, regions_release_files), () -> key_folders(regions_domains()))
    dataset == GRIDS && return (grids_files, grids_domains)
    is_remap_dataset(dataset) &&
        return (d -> gridded_files(d, (dom, og) -> remap_release_files(dataset, og)), () -> remap_domains(dataset))
    is_records_dataset(dataset) && return (_ -> records_files(dataset), () -> [RECORDS_FOLDER])
    error("dataset $dataset has no pipeline (no Topo, Regions, Grids, $dataset/remap.toml or $dataset/records.toml)")
end

function dataset_config(dataset::AbstractString)
    all = read_datasets()
    known = sort([k for k in keys(all) if !startswith(k, "_")])
    dataset in known || error("unknown dataset $dataset, available: $(join(known, ", "))")
    dataset_pipeline(dataset)
    return all[dataset]
end

# ---------------------------------------------------------------------------
# Local files
# ---------------------------------------------------------------------------

"""
    ProductFile

A file of a record: its grid (empty for records, which are not gridded) and local path.
"""
struct ProductFile
    grid::String
    path::String
end

Base.basename(f::ProductFile) = basename(f.path)

"Domains (output folders, with the crops) on which a dataset is released."
release_domains(dataset::AbstractString) = dataset_pipeline(dataset)[2]()

"""
    release_files(domain, dataset) -> Vector{ProductFile}

Files of a release of a dataset on a domain (its output folder, e.g. Greenland), as the
pipeline of the dataset defines them (`dataset_pipeline`), present or not.
"""
function release_files(domain::AbstractString, dataset::AbstractString)
    dataset_config(dataset)
    return dataset_pipeline(dataset)[1](domain)
end

"""
    gridded_files(domain, names) -> Vector{ProductFile}

Files of a release of a gridded dataset on a domain: on every grid of the domain,
`names(dom, og)` on grid `og`. Their grid files are released in Grids.
"""
function gridded_files(domain::AbstractString, names)
    dom, grids = folder_grids(domain)
    return [ProductFile(og.grid.name, joinpath(outdir(og), name)) for og in grids for name in names(dom, og)]
end

"Gridded datasets, whose grid files are released in Grids: all but Grids and the records datasets."
gridded_datasets() =
    sort([k for k in keys(read_datasets()) if !startswith(k, "_") && k != GRIDS && !is_records_dataset(k)])

"Domains (output folders) of Grids: those of the gridded datasets."
grids_domains() = sort(unique(d for s in gridded_datasets() for d in release_domains(s)))

"""
    grids_files(domain) -> Vector{ProductFile}

Files of a release of Grids on a domain: the grid files (`grid_file_names`) of each of
its grids with files of a gridded dataset present, released once for all datasets on
the grid.
"""
function grids_files(domain::AbstractString)
    _, grids = folder_grids(domain)
    used = Set(f.grid for s in gridded_datasets() if domain in release_domains(s)
                      for f in release_files(domain, s) if isfile(f.path))
    return [ProductFile(og.grid.name, joinpath(outdir(og), name))
            for og in grids if og.grid.name in used for name in grid_file_names(og.grid.name)]
end

"Files of a release of a records dataset, in \$FESMDATA_PRODUCTS/Records/<Dataset>/ (no grids)."
records_files(dataset::AbstractString) =
    [ProductFile("", joinpath(records_dir(dataset), name)) for name in records_release_files(dataset)]

"Whether any file of a dataset is present on a domain."
has_files(domain::AbstractString, dataset::AbstractString) = any(f -> isfile(f.path), release_files(domain, dataset))

"""
    collect_files(domain, dataset) -> Vector{ProductFile}

Files of a release of a dataset on a domain (see `release_files`), which must all be
present.
"""
function collect_files(domain::AbstractString, dataset::AbstractString)
    files = release_files(domain, dataset)
    missing_files = [f.path for f in files if !isfile(f.path)]
    isempty(missing_files) ||
        error("$(length(missing_files)) of $(length(files)) files of $domain/$dataset are missing:\n  " *
              join(missing_files, "\n  "))
    return files
end

"Global attribute of a NetCDF file (`nothing` if absent)."
nc_attrib(path::AbstractString, key::AbstractString) =
    NCDataset(ds -> get(ds.attrib, key, nothing), path)

"Whether `version` is a release tag <tag>-vX.Y.Z of the dataset with tag `tag`."
is_release_tag(version::AbstractString, tag::AbstractString) =
    occursin(Regex("^$(tag)-v\\d+\\.\\d+\\.\\d+\$"), version)

"Version number of a release tag (topo-v2.0.0 -> v\"2.0.0\")."
tag_number(version::AbstractString) = VersionNumber(match(r"-v(\d+\.\d+\.\d+)$", version)[1])

"Newest release tag <tag>-vX.Y.Z of a dataset with tag `tag` in the repository (`nothing` if none)."
function newest_tag(tag::AbstractString)
    tags = filter(t -> is_release_tag(t, tag), split(_git("tag", "--list", "$(tag)-v*"), '\n'))
    return isempty(tags) ? nothing : argmax(tag_number, tags)
end

"""
    unchanged(f, old) -> Bool

Whether a file is that of its entry in the registry of the earlier release (`old`, name
=> entry), by its checksum: such a file is kept as released, not stamped or uploaded
again.
"""
unchanged(f::ProductFile, old::AbstractDict) =
    haskey(old, basename(f)) && old[basename(f)]["checksum"] == release_checksum(f.path)

"""
Version of the local files of a dataset (`fesmdata_version`): the newest if all are
release tags of the dataset, else \"mixed versions\".
"""
function files_version(files::Vector{ProductFile}, dataset::AbstractString)
    tag = dataset_config(dataset)["tag"]
    data = filter(f -> endswith(f.path, ".nc"), files)
    versions = unique(something(nc_attrib(f.path, "fesmdata_version"), "missing") for f in data)
    length(versions) == 1 && return only(versions)
    return all(v -> is_release_tag(v, tag), versions) ? argmax(tag_number, versions) : "mixed versions"
end

"""
    release_version(files, dataset; old=Dict(), allow_untagged=false) -> String

Version of a release of the files of a dataset on a domain: the newest release tag
<tag>-vX.Y.Z of the dataset in the repository. The files unchanged since the earlier
release (`unchanged`, by the entries `old` of its registry) keep the version they were
released at, an earlier tag; all other files (new or made again) must have the version
of the release (`fesmdata.jl stamp`). With `allow_untagged`, no checks are made and the
version is that of the files if they all have the same, else that of the repository.
"""
function release_version(files::Vector{ProductFile}, dataset::AbstractString; old::AbstractDict=Dict{String,Any}(),
                         allow_untagged::Bool=false, what::AbstractString=dataset)
    tag = dataset_config(dataset)["tag"]
    data = filter(f -> endswith(f.path, ".nc"), files)
    versions = Dict(basename(f) => something(nc_attrib(f.path, "fesmdata_version"), "missing") for f in data)
    if allow_untagged
        found = unique(values(versions))
        return length(found) == 1 ? only(found) : git_version(tag)
    end
    version = newest_tag(tag)
    version === nothing && error("no release tag $(tag)-vX.Y.Z of $dataset in the repository " *
                                 "(tag the release first, or use --allow-untagged)")
    tags = Set(split(_git("tag", "--list", "$(tag)-v*"), '\n'))
    wrong = String[]
    for f in data
        v = versions[basename(f)]
        if unchanged(f, old)
            (is_release_tag(v, tag) && v in tags && tag_number(v) <= tag_number(version)) ||
                push!(wrong, "$(basename(f)): $v (unchanged since the earlier release)")
        else
            v == version || push!(wrong, "$(basename(f)): $v (new or made again)")
        end
    end
    isempty(wrong) ||
        error("$(length(wrong)) files of $what are not at release $version, or at an earlier release " *
              "if unchanged (stamp the files at the tag, `fesmdata.jl stamp`, or use --allow-untagged):\n  " *
              join(wrong, "\n  "))
    return version
end

"""
    check_grids(domain, files; sandbox=false)

Check that the grids of the files of a release of a gridded dataset on a domain are
released in Grids, with the local grid files as released (checksums): the products are
on these grid files, which `fetch` gets from Grids.
"""
function check_grids(domain::AbstractString, files::Vector{ProductFile}; sandbox::Bool=false)
    grids = filter(!isempty, unique(f.grid for f in files))
    isempty(grids) && return
    entries = registry_entries(domain, GRIDS; sandbox=sandbox)
    dir(g) = dirname(first(f.path for f in files if f.grid == g))
    wrong = String[]
    for g in grids, name in grid_file_names(g)
        path = joinpath(dir(g), name)
        if !haskey(entries, name)
            push!(wrong, "$name: not released in Grids")
        elseif !isfile(path) || release_checksum(path) != entries[name]["checksum"]
            push!(wrong, "$path: not the file released in Grids $(registry_tables(domain, GRIDS; sandbox=sandbox)["_RELEASE"]["version"])")
        end
    end
    isempty(wrong) ||
        error("$(length(wrong)) grid files of $domain are not released in Grids (release Grids first, README.md):\n  " *
              join(wrong, "\n  "))
end

"""
    stamp(dataset, domains=String[])

Set the version of the files of a release of a dataset on each domain (all domains with
its files by default) to its release tag, in place: the tag `<tag>-vX.Y.Z` of the
dataset on the checked-out commit, which must have no uncommitted changes. Only the
files new or made again since the earlier release are stamped: those unchanged
(`unchanged`, by the registry of the earlier release, which must be committed) keep the
version they were released at, so that they are not uploaded or downloaded again. Only
the global attributes of the data files change: `fesmdata_version` becomes the tag, and
`history` records the stamp and the version the file was made at; `fesmdata_commit`
stays the commit that made it. The text forms of records (.txt) are written again from
their stamped files. All files must be present (`collect_files`).
"""
function stamp(dataset::AbstractString, domains=String[])
    tag = dataset_config(dataset)["tag"]
    version = _git("describe", "--tags", "--exact-match", "--match", "$(tag)-v*", "--dirty")
    is_release_tag(version, tag) ||
        error("the checkout is not at a release tag $(tag)-vX.Y.Z of $dataset without uncommitted changes " *
              "(git describe: $version); tag the release first (README.md, Release)")
    time = Dates.format(now(), dateformat"yyyy-mm-ddTHH:MM:SS")
    for domain in select_domains(dataset, domains)
        all_files = collect_files(domain, dataset)
        old = registry_entries(domain, dataset)
        files = filter(f -> endswith(f.path, ".nc"), all_files)
        texts = Set(f.path for f in all_files if endswith(f.path, ".txt"))
        n, kept = 0, 0
        for f in files
            unchanged(f, old) && (kept += 1; continue)
            NCDataset(f.path, "a") do ds
                made = get(ds.attrib, "fesmdata_version", "missing")
                made == version && return
                ds.attrib["fesmdata_version"] = version
                ds.attrib["history"] = "$time: fesmdata.jl stamp $dataset, version $version (made at $made)\n" *
                                       get(ds.attrib, "history", "")
                n += 1
            end
            delete!(_CHECKSUMS, f.path)   # changed by the stamp
            text_path(f.path) in texts && write_record_text(f.path, text_path(f.path))
        end
        println("$domain/$dataset: $n of $(length(files)) files stamped $version, $kept unchanged since the earlier release")
    end
end

"""
    release_number(version, dataset) -> String

Version number of a release in the store and the archive: the release tag without the
dataset name (topo-v2.0.0 -> 2.0.0); 0.0.0-<version> for an untagged version.
"""
function release_number(version::AbstractString, dataset::AbstractString)
    m = match(Regex("^$(dataset_config(dataset)["tag"])-v(\\d+\\.\\d+\\.\\d+)\$"), version)
    return m === nothing ? "0.0.0-" * replace(version, r"[^0-9A-Za-z.-]" => "-") : m[1]
end

file_md5(path::AbstractString) = open(io -> bytes2hex(md5(io)), path)

const _CHECKSUMS = Dict{String,String}()

"Checksum (sha256:<hex>) of a local file of a release, computed once per run."
release_checksum(path::AbstractString) = get!(() -> checksum(path), _CHECKSUMS, path)

"DOIs of the original datasets (datamanifest.toml) named in the `sources` attributes."
function source_dois(files::Vector{ProductFile})
    manifest = TOML.parsefile(joinpath(REPO_DIR, "datamanifest.toml"))
    sources = Set{String}()
    for f in files
        endswith(f.path, ".nc") || continue
        s = nc_attrib(f.path, "sources")
        s === nothing || union!(sources, strip.(split(s, r"[>,]")))   # Topo "a > b", Regions "a, b"
    end
    dois = String[]
    for s in sort(collect(sources))
        keys_s = filter(k -> k == s || startswith(k, s * "_"), collect(keys(manifest)))
        found = unique([manifest[k]["doi"] for k in keys_s if haskey(manifest[k], "doi")])
        isempty(found) && @warn "no DOI in datamanifest.toml for source $s"
        append!(dois, found)
    end
    return unique(dois)
end

"""
    select_domains(dataset, domains) -> Vector{String}

Domains of a command: `domains` if given, else all domains with files of the dataset.
"""
function select_domains(dataset::AbstractString, domains)
    dataset_config(dataset)
    isempty(domains) || return collect(String, domains)
    found = filter(d -> has_files(d, dataset), release_domains(dataset))
    isempty(found) && error("no files of $dataset in $(products_dir())")
    return found
end

"Release tables (`_RELEASE`, `_ZENODO`) of a registered record (empty if none)."
function registry_tables(domain::AbstractString, dataset::AbstractString; sandbox::Bool=false)
    isfile(registry_file(domain, dataset; sandbox=sandbox)) || return Dict{String,Any}()
    return read_record(domain, dataset; sandbox=sandbox)[1]
end

"File entries (name => entry) of a registered record (empty if none)."
function registry_entries(domain::AbstractString, dataset::AbstractString; sandbox::Bool=false)
    isfile(registry_file(domain, dataset; sandbox=sandbox)) || return Dict{String,Any}()
    return read_record(domain, dataset; sandbox=sandbox)[2]
end

# ---------------------------------------------------------------------------
# HTTP requests
# ---------------------------------------------------------------------------

"HTTP statuses of a busy or failing server, after which a request is tried again."
const TRANSIENT_STATUS = (429, 500, 502, 503, 504)

"Waits (s) before the retries of a request."
const RETRY_WAITS = (30, 120, 300)

const _DOWNLOADER = Ref{Union{Nothing,Downloads.Downloader}}(nothing)

# A busy server can take minutes to answer: allow 10 min without data, instead of the
# 20 s of Downloads.
function patient_downloader()
    if _DOWNLOADER[] === nothing
        d = Downloads.Downloader()
        d.easy_hook = (easy, info) -> Downloads.Curl.setopt(easy, Downloads.Curl.CURLOPT_LOW_SPEED_TIME, 600)
        _DOWNLOADER[] = d
    end
    return _DOWNLOADER[]
end

"""
    request(service, method, url; headers=[], json=nothing, file=nothing, missing_ok=false,
            retry=method != "POST")

Request to the API of a service (for messages), with a JSON body or a file as body.
Returns the parsed JSON response (`nothing` if empty, or if not found with
`missing_ok`); errors on an HTTP status other than 2xx. With `retry` (not for POST,
which may not be repeatable), a request that fails on the network or with a transient
status is tried again, after the waits of `RETRY_WAITS`.
"""
function request(service::AbstractString, method::AbstractString, url::AbstractString;
                 headers=Pair{String,String}[], json=nothing, file::Union{Nothing,AbstractString}=nothing,
                 missing_ok::Bool=false, retry::Bool=method != "POST")
    headers = collect(Pair{String,String}, headers)
    json === nothing || push!(headers, "Content-Type" => "application/json")
    file === nothing || push!(headers, "Content-Type" => "application/octet-stream")
    waits = retry ? RETRY_WAITS : ()
    for attempt in 0:length(waits)
        # a file is passed as its path, so that the upload has a known size (Content-Length)
        input = json !== nothing ? IOBuffer(JSON.json(json)) : file
        output = IOBuffer()
        problem = try
            response = Downloads.request(url; method=method, headers=headers, input=input, output=output,
                                         downloader=patient_downloader())
            body = String(take!(output))
            missing_ok && response.status == 404 && return nothing
            200 <= response.status < 300 && return isempty(body) ? nothing : JSON.parse(body)
            msg = "$service $method $url: HTTP $(response.status)\n$body"
            response.status in TRANSIENT_STATUS || error(msg)
            msg
        catch e
            e isa Downloads.RequestError || rethrow()
            "$service $method $url: " * sprint(showerror, e)
        end
        attempt == length(waits) && error(problem)
        println("  $(first(split(problem, '\n'))); trying again in $(waits[attempt+1]) s")
        sleep(waits[attempt+1])
    end
end
