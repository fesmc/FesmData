# Upload of the products of a dataset on a domain to a Zenodo draft, and
# registration of the published record (see README.md). Uses the deposit API of
# Zenodo with a personal token (scopes deposit:write and deposit:actions) in
# ZENODO_TOKEN, or ZENODO_SANDBOX_TOKEN for the sandbox.

using JSON
using MD5
using NCDatasets

include(joinpath(@__DIR__, "registry.jl"))
include(joinpath(REPO_DIR, "shared", "domains.jl"))
include(joinpath(REPO_DIR, "Topo", "files.jl"))
include(joinpath(REPO_DIR, "Regions", "files.jl"))

"Files of a release of each dataset on a grid of a domain, defined by its pipeline."
const RELEASE_FILES = Dict("Topo" => topo_release_files, "Regions" => regions_release_files)

read_datasets() = TOML.parsefile(joinpath(@__DIR__, "datasets.toml"))

function dataset_config(dataset::AbstractString)
    all = read_datasets()
    haskey(all, dataset) && haskey(RELEASE_FILES, dataset) ||
        error("unknown dataset $dataset, available: $(join(sort(collect(keys(RELEASE_FILES))), ", "))")
    return all[dataset]
end

# ---------------------------------------------------------------------------
# Local files
# ---------------------------------------------------------------------------

"""
    ProductFile

A file of a record: its grid, local path, and whether it is a grid file.
"""
struct ProductFile
    grid::String
    path::String
    is_grid::Bool
end

Base.basename(f::ProductFile) = basename(f.path)

"""
    collect_files(domain, dataset) -> Vector{ProductFile}

Files of a release of a dataset on a domain (its output folder, e.g. Greenland): on
every grid of the domain, the grid files and the files the pipeline of the dataset
defines (`RELEASE_FILES`). All of them must be present.
"""
function collect_files(domain::AbstractString, dataset::AbstractString)
    dataset_config(dataset)
    dom, grids = folder_grids(domain)
    files = ProductFile[]
    for og in grids
        g = og.grid.name
        push!(files, ProductFile(g, joinpath(outdir(og), "grid_$g.txt"), true),
                     ProductFile(g, joinpath(outdir(og), "$(g)_grid.nc"), true))
        append!(files, [ProductFile(g, joinpath(outdir(og), name), false) for name in RELEASE_FILES[dataset](dom, og)])
    end
    missing_files = [f.path for f in files if !isfile(f.path)]
    isempty(missing_files) ||
        error("$(length(missing_files)) of $(length(files)) files of $domain/$dataset are missing:\n  " *
              join(missing_files, "\n  "))
    return files
end

"Global attribute of a NetCDF file (`nothing` if absent)."
nc_attrib(path::AbstractString, key::AbstractString) =
    NCDataset(ds -> get(ds.attrib, key, nothing), path)

"""
    release_version(files, dataset; allow_untagged=false) -> String

Version of the files of a release: all files of the dataset must have the same
`fesmdata_version`, a release tag <tag>-vX.Y.Z that exists in the repository, and the
grid files must not be made from uncommitted changes. With `allow_untagged`, no checks
are made and the version is that of the files if they all have the same, else that of
the repository.
"""
function release_version(files::Vector{ProductFile}, dataset::AbstractString; allow_untagged::Bool=false)
    tag = dataset_config(dataset)["tag"]
    data = filter(f -> !f.is_grid && endswith(f.path, ".nc"), files)
    versions = Dict(basename(f) => something(nc_attrib(f.path, "fesmdata_version"), "missing") for f in data)
    found = sort(unique(values(versions)))
    if allow_untagged
        return length(found) == 1 ? only(found) : git_version(tag)
    end
    length(found) == 1 ||
        error("files of $dataset have different versions: " *
              join(["$v ($(count(==(v), values(versions))) files)" for v in found], ", "))
    version = only(found)
    occursin(Regex("^$(tag)-v\\d+\\.\\d+\\.\\d+\$"), version) ||
        error("files of $dataset have version $version, not a release tag $(tag)-vX.Y.Z " *
              "(rerun the pipeline at the tag, or use --allow-untagged)")
    _git("tag", "--list", version) == version || error("tag $version does not exist in the repository")
    for f in filter(f -> f.is_grid && endswith(f.path, ".nc"), files)
        v = something(nc_attrib(f.path, "fesmdata_version"), "missing")
        (v == "missing" || endswith(v, "-dirty")) &&
            error("grid file $(f.path) has version $v (rerun Topo step 1 at a commit)")
    end
    return version
end

"Version of a record on Zenodo: the release tag without the dataset name (2.0.0)."
zenodo_version(version::AbstractString, tag::AbstractString) =
    replace(version, Regex("^$(tag)-v") => "")

file_md5(path::AbstractString) = open(io -> bytes2hex(md5(io)), path)

# ---------------------------------------------------------------------------
# Metadata
# ---------------------------------------------------------------------------

"DOIs of the original datasets (datamanifest.toml) named in the `sources` attributes."
function source_dois(files::Vector{ProductFile})
    manifest = TOML.parsefile(joinpath(REPO_DIR, "datamanifest.toml"))
    sources = Set{String}()
    for f in files
        (f.is_grid || !endswith(f.path, ".nc")) && continue
        s = nc_attrib(f.path, "sources")
        s === nothing || union!(sources, strip.(split(s, ">")))
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
    record_metadata(domain, dataset, files, version) -> Dict

Zenodo metadata of the record of a dataset on a domain.
"""
function record_metadata(domain::AbstractString, dataset::AbstractString,
                         files::Vector{ProductFile}, version::AbstractString)
    common = read_datasets()["_zenodo"]
    cfg = dataset_config(dataset)
    data = filter(f -> !f.is_grid && endswith(f.path, ".nc"), files)
    commit = something(nc_attrib(first(data).path, "fesmdata_commit"), "unknown")
    ref = _git("tag", "--list", version) == version ? version : commit == "unknown" ? "main" : commit
    grids = unique(f.grid for f in files)
    readme = "$REPO_URL/blob/$ref/$(cfg["readme"])"
    description = """
        <p>$(strip(replace(cfg["description"], '\n' => ' ')))</p>
        <p>Domain: $domain. Grids: $(join(grids, ", ")).</p>
        <p>Produced with <a href="$REPO_URL">FesmData</a> version $version (commit
        $commit); see the <a href="$readme">$dataset README</a> for the sources and methods.
        Each grid has its own files, named after the grid (e.g. <code>$(basename(first(data)))</code>),
        with the grid description for cdo (<code>grid_&lt;GRID&gt;.txt</code>) and the grid
        file (<code>&lt;GRID&gt;_grid.nc</code>). To download into the FesmData layout,
        use <code>Publish/scripts/fetch.jl $domain $dataset</code>.</p>
        """
    related = Any[Dict("identifier" => "$REPO_URL/tree/$ref", "relation" => "isCompiledBy",
                       "resource_type" => "software")]
    for doi in source_dois(files)
        push!(related, Dict("identifier" => doi, "relation" => "isDerivedFrom", "resource_type" => "dataset"))
    end
    return Dict(
        "upload_type" => "dataset",
        "title" => "FesmData $domain $dataset: $(cfg["title"])",
        "creators" => common["creators"],
        "description" => description,
        "version" => zenodo_version(version, cfg["tag"]),
        "license" => common["license"],
        "keywords" => cfg["keywords"],
        "communities" => [Dict("identifier" => common["community"])],
        "related_identifiers" => related,
    )
end

# ---------------------------------------------------------------------------
# Zenodo API
# ---------------------------------------------------------------------------

zenodo_url(sandbox::Bool) = sandbox ? "https://sandbox.zenodo.org" : "https://zenodo.org"

zenodo_token(sandbox::Bool) = _env(sandbox ? "ZENODO_SANDBOX_TOKEN" : "ZENODO_TOKEN")

"""
    api(method, url; token="", json=nothing, file=nothing)

Request to the Zenodo API, with a JSON body or a file as body. Returns the parsed JSON
response (`nothing` if empty, or if not found with `missing_ok`); errors on an HTTP
status other than 2xx.
"""
function api(method::AbstractString, url::AbstractString; token::AbstractString="", json=nothing,
             file::Union{Nothing,AbstractString}=nothing, missing_ok::Bool=false)
    headers = isempty(token) ? Pair{String,String}[] : ["Authorization" => "Bearer $token"]
    input = nothing
    if json !== nothing
        push!(headers, "Content-Type" => "application/json")
        input = IOBuffer(JSON.json(json))
    elseif file !== nothing
        push!(headers, "Content-Type" => "application/octet-stream")
        input = file   # a path, so that the upload has a known size (Content-Length)
    end
    output = IOBuffer()
    response = Downloads.request(url; method=method, headers=headers, input=input, output=output)
    body = String(take!(output))
    missing_ok && response.status == 404 && return nothing
    200 <= response.status < 300 || error("Zenodo $method $url: HTTP $(response.status)\n$body")
    return isempty(body) ? nothing : JSON.parse(body)
end

"""
    open_draft(domain, dataset; sandbox=false, draft=nothing) -> deposition

Draft of the next version of a record: a new version of the record in the registry,
or a new record if there is none. `draft` (an id) continues an existing draft.
"""
function open_draft(domain::AbstractString, dataset::AbstractString; sandbox::Bool=false,
                    draft::Union{Nothing,Integer}=nothing)
    base, token = zenodo_url(sandbox), zenodo_token(sandbox)
    draft === nothing || return api("GET", "$base/api/deposit/depositions/$draft"; token=token)
    if isfile(registry_file(domain, dataset; sandbox=sandbox))
        info, _ = read_record(domain, dataset; sandbox=sandbox)
        id = info["record_id"]
        println("New version of record $id ($(info["version"]))")
        # Calling newversion again while a draft exists returns the same draft
        r = api("POST", "$base/api/deposit/depositions/$id/actions/newversion"; token=token)
        return api("GET", r["links"]["latest_draft"]; token=token)
    end
    println("New record")
    return api("POST", "$base/api/deposit/depositions"; token=token, json=Dict())
end

"""
    sync_files!(deposition, files; sandbox=false)

Make the files of a draft those of `files`: keep files with the same name and
checksum, upload new and changed files, and delete the others.
"""
function sync_files!(dep, files::Vector{ProductFile}; sandbox::Bool=false)
    base, token = zenodo_url(sandbox), zenodo_token(sandbox)
    id = dep["id"]
    remote = Dict(f["filename"] => f for f in api("GET", "$base/api/deposit/depositions/$id/files"; token=token))
    local_names = Set(basename(f) for f in files)
    for (name, f) in remote
        name in local_names && continue
        println("delete    $name")
        api("DELETE", "$base/api/deposit/depositions/$id/files/$(f["id"])"; token=token)
    end
    for f in files
        name = basename(f)
        sum = file_md5(f.path)
        if haskey(remote, name)
            replace(remote[name]["checksum"], "md5:" => "") == sum && (println("keep      $name"); continue)
            api("DELETE", "$base/api/deposit/depositions/$id/files/$(remote[name]["id"])"; token=token)
        end
        println("upload    $name ($(round(filesize(f.path) / 1e6; digits=1)) MB)")
        r = api("PUT", "$(dep["links"]["bucket"])/$name"; token=token, file=f.path)
        replace(r["checksum"], "md5:" => "") == sum || error("checksum of uploaded $name differs: $(r["checksum"])")
    end
end

"""
    upload(domain, dataset; sandbox=false, allow_untagged=false, draft=nothing, dry_run=false)

Upload the files of a dataset on a domain to a draft of the next version of
its record, with its metadata. The draft is published on the Zenodo website, after
review, and then registered with `register`.
"""
function upload(domain::AbstractString, dataset::AbstractString; sandbox::Bool=false,
                allow_untagged::Bool=false, draft=nothing, dry_run::Bool=false)
    files = collect_files(domain, dataset)
    version = release_version(files, dataset; allow_untagged=allow_untagged)
    meta = record_metadata(domain, dataset, files, version)
    sandbox && delete!(meta, "communities")   # the community exists only on Zenodo
    total = sum(filesize(f.path) for f in files)
    println("$domain/$dataset $version: $(length(files)) files, $(round(total / 1e9; digits=2)) GB")
    if dry_run
        foreach(f -> println("  ", rpad(basename(f), 40), round(filesize(f.path) / 1e6; digits=1), " MB"), files)
        JSON.json(stdout, meta; pretty=true)
        println()
        return nothing
    end
    dep = open_draft(domain, dataset; sandbox=sandbox, draft=draft)
    println("Draft $(dep["id"])")
    sync_files!(dep, files; sandbox=sandbox)
    api("PUT", "$(zenodo_url(sandbox))/api/deposit/depositions/$(dep["id"])";
        token=zenodo_token(sandbox), json=Dict("metadata" => meta))
    # The published record keeps the id of its draft
    flags = (sandbox ? " --sandbox" : "") * (allow_untagged ? " --allow-untagged" : "")
    println("""
        Draft ready: $(dep["links"]["html"])
        Review and publish it on Zenodo, then register the published record:
            julia --project=Publish Publish/scripts/zenodo.jl register $domain $dataset $(dep["id"])$flags""")
    return dep
end

"""
    register(domain, dataset, record_id; sandbox=false, allow_untagged=false)

Write the registry file of a published record, after checking that its files are the
local files (names and checksums).
"""
function register(domain::AbstractString, dataset::AbstractString, record_id::Integer;
                  sandbox::Bool=false, allow_untagged::Bool=false)
    base = zenodo_url(sandbox)
    rec = api("GET", "$base/api/records/$record_id"; missing_ok=true)
    rec === nothing && error("record $record_id is not published on $base (publish its draft first)")
    files = collect_files(domain, dataset)
    version = release_version(files, dataset; allow_untagged=allow_untagged)
    remote = Dict(f["key"] => f for f in rec["files"])
    missing_remote = setdiff(Set(basename(f) for f in files), keys(remote))
    extra_remote = setdiff(keys(remote), Set(basename(f) for f in files))
    isempty(missing_remote) && isempty(extra_remote) ||
        error("files of record $record_id differ from the local files: missing on Zenodo " *
              "$(join(sort(collect(missing_remote)), ", ")); only on Zenodo $(join(sort(collect(extra_remote)), ", "))")

    entries = Dict{String,Any}()
    for f in files
        name = basename(f)
        r = remote[name]
        replace(r["checksum"], "md5:" => "") == file_md5(f.path) ||
            error("$name of record $record_id differs from the local file $(f.path)")
        entries[name] = Dict(
            "uri" => "$base/records/$record_id/files/$name?download=1",
            "checksum" => checksum(f.path),
            "size" => filesize(f.path),
            "storage_path" => "\$datasets_dir/$domain/$(f.grid)/$name",
        )
    end
    info = Dict(
        "record_id" => rec["id"],
        "concept_record_id" => parse(Int, string(rec["conceptrecid"])),
        "doi" => rec["doi"],
        "concept_doi" => rec["conceptdoi"],
        "version" => get(rec["metadata"], "version", version),
        "git_tag" => version,
        "publication_date" => rec["metadata"]["publication_date"],
        "url" => "$base/records/$(rec["id"])",
    )
    path = registry_file(domain, dataset; sandbox=sandbox)
    write_registry(path, info, entries)
    println("Wrote $path ($(length(entries)) files, doi:$(info["doi"]))")
    return path
end

"Write a registry file: the record metadata first, then the entries by name."
function write_registry(path::AbstractString, info::AbstractDict, entries::AbstractDict)
    mkpath(dirname(path))
    open(path, "w") do io
        println(io, "# Registry of a Zenodo record, written by Publish/scripts/zenodo.jl register.\n")
        TOML.print(io, Dict("_ZENODO" => info); sorted=true)
        for name in sort(collect(keys(entries)))
            println(io)
            TOML.print(io, Dict(name => entries[name]); sorted=true)
        end
    end
    return path
end
