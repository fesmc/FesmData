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
    release_files(domain, dataset) -> Vector{ProductFile}

Files of a release of a dataset on a domain (its output folder, e.g. Greenland): on
every grid of the domain, the grid files and the files the pipeline of the dataset
defines (`RELEASE_FILES`), present or not.
"""
function release_files(domain::AbstractString, dataset::AbstractString)
    dataset_config(dataset)
    dom, grids = folder_grids(domain)
    files = ProductFile[]
    for og in grids
        g = og.grid.name
        push!(files, ProductFile(g, joinpath(outdir(og), "grid_$g.txt"), true),
                     ProductFile(g, joinpath(outdir(og), "$(g)_grid.nc"), true))
        append!(files, [ProductFile(g, joinpath(outdir(og), name), false) for name in RELEASE_FILES[dataset](dom, og)])
    end
    return files
end

"Whether any file of the dataset itself (not a grid file) is present on a domain."
has_files(domain::AbstractString, dataset::AbstractString) =
    any(f -> !f.is_grid && isfile(f.path), release_files(domain, dataset))

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

"Title of the record of a dataset on a domain."
record_title(domain::AbstractString, dataset::AbstractString) =
    "FesmData $domain $dataset: $(dataset_config(dataset)["title"])"

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
        "title" => record_title(domain, dataset),
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

"HTTP statuses of a busy or failing Zenodo, after which a request is tried again."
const TRANSIENT_STATUS = (429, 500, 502, 503, 504)

"Waits (s) before the retries of a request."
const RETRY_WAITS = (30, 120, 300)

const _DOWNLOADER = Ref{Union{Nothing,Downloads.Downloader}}(nothing)

# Zenodo can take minutes to answer when busy: allow 10 min without data, instead of
# the 20 s of Downloads.
function zenodo_downloader()
    if _DOWNLOADER[] === nothing
        d = Downloads.Downloader()
        d.easy_hook = (easy, info) -> Downloads.Curl.setopt(easy, Downloads.Curl.CURLOPT_LOW_SPEED_TIME, 600)
        _DOWNLOADER[] = d
    end
    return _DOWNLOADER[]
end

"""
    api(method, url; token="", json=nothing, file=nothing, missing_ok=false, retry=method != "POST")

Request to the Zenodo API, with a JSON body or a file as body. Returns the parsed JSON
response (`nothing` if empty, or if not found with `missing_ok`); errors on an HTTP
status other than 2xx. With `retry` (not for POST, which may not be repeatable), a
request that fails on the network or with a transient status is tried again, after
the waits of `RETRY_WAITS`.
"""
function api(method::AbstractString, url::AbstractString; token::AbstractString="", json=nothing,
             file::Union{Nothing,AbstractString}=nothing, missing_ok::Bool=false,
             retry::Bool=method != "POST")
    headers = isempty(token) ? Pair{String,String}[] : ["Authorization" => "Bearer $token"]
    json === nothing || push!(headers, "Content-Type" => "application/json")
    file === nothing || push!(headers, "Content-Type" => "application/octet-stream")
    waits = retry ? RETRY_WAITS : ()
    for attempt in 0:length(waits)
        # a file is passed as its path, so that the upload has a known size (Content-Length)
        input = json !== nothing ? IOBuffer(JSON.json(json)) : file
        output = IOBuffer()
        problem = try
            response = Downloads.request(url; method=method, headers=headers, input=input, output=output,
                                         downloader=zenodo_downloader())
            body = String(take!(output))
            missing_ok && response.status == 404 && return nothing
            200 <= response.status < 300 && return isempty(body) ? nothing : JSON.parse(body)
            msg = "Zenodo $method $url: HTTP $(response.status)\n$body"
            response.status in TRANSIENT_STATUS || error(msg)
            msg
        catch e
            e isa Downloads.RequestError || rethrow()
            "Zenodo $method $url: " * sprint(showerror, e)
        end
        attempt == length(waits) && error(problem)
        println("  $(first(split(problem, '\n'))); trying again in $(waits[attempt+1]) s")
        sleep(waits[attempt+1])
    end
end

"""
    drafts_file(domain, dataset; sandbox=false)

File recording the open draft of a record, written by `upload` and removed by
`register`: registry/_drafts/<Domain>/<Dataset>.toml (local, not tracked).
"""
drafts_file(domain::AbstractString, dataset::AbstractString; sandbox::Bool=false) =
    joinpath(registry_dir(sandbox), "_drafts", domain, "$dataset.toml")

"Recorded draft of a record (`nothing` if none)."
function read_draft(domain::AbstractString, dataset::AbstractString; sandbox::Bool=false)
    path = drafts_file(domain, dataset; sandbox=sandbox)
    return isfile(path) ? TOML.parsefile(path) : nothing
end

function write_draft(domain::AbstractString, dataset::AbstractString, dep, version::AbstractString;
                     sandbox::Bool=false)
    path = drafts_file(domain, dataset; sandbox=sandbox)
    mkpath(dirname(path))
    open(io -> TOML.print(io, Dict("draft_id" => dep["id"], "version" => version,
                                   "url" => dep["links"]["html"])), path, "w")
    return path
end

"Published record of a draft (`nothing` if the draft is not published yet)."
published_record(id::Integer; sandbox::Bool=false) =
    api("GET", "$(zenodo_url(sandbox))/api/records/$id"; missing_ok=true)

"""
    open_draft(domain, dataset; sandbox=false) -> deposition

Draft of the next version of a record: the draft recorded by an earlier `upload`, else
a new version of the record in the registry, or a new record if there is none.
"""
function open_draft(domain::AbstractString, dataset::AbstractString; sandbox::Bool=false)
    base, token = zenodo_url(sandbox), zenodo_token(sandbox)
    draft = read_draft(domain, dataset; sandbox=sandbox)
    if draft !== nothing
        id = draft["draft_id"]
        published_record(id; sandbox=sandbox) === nothing ||
            error("$domain/$dataset: draft $id is already published; register it first")
        println("Draft $id of an earlier upload")
        return api("GET", "$base/api/deposit/depositions/$id"; token=token)
    end
    if isfile(registry_file(domain, dataset; sandbox=sandbox))
        info, _ = read_record(domain, dataset; sandbox=sandbox)
        id = info["record_id"]
        println("New version of record $id ($(info["version"]))")
        # Calling newversion again while a draft exists returns the same draft
        r = api("POST", "$base/api/deposit/depositions/$id/actions/newversion"; token=token)
        return api("GET", r["links"]["latest_draft"]; token=token)
    end
    # An unpublished draft of the record from an upload not recorded here (e.g. from
    # another checkout), found by its title
    title = record_title(domain, dataset)
    drafts = filter(d -> get(d["metadata"], "title", "") == title && !d["submitted"],
                    api("GET", "$base/api/deposit/depositions?status=draft&size=100"; token=token))
    length(drafts) > 1 && error("$domain/$dataset: several drafts titled \"$title\" " *
                                "($(join([d["id"] for d in drafts], ", "))); delete all but one on Zenodo")
    length(drafts) == 1 && (println("Draft $(only(drafts)["id"]) of an earlier upload"); return only(drafts))
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
        api("DELETE", "$base/api/deposit/depositions/$id/files/$(f["id"])"; token=token, missing_ok=true)
    end
    for f in files
        name = basename(f)
        sum = file_md5(f.path)
        if haskey(remote, name)
            replace(remote[name]["checksum"], "md5:" => "") == sum && (println("keep      $name"); continue)
            api("DELETE", "$base/api/deposit/depositions/$id/files/$(remote[name]["id"])"; token=token, missing_ok=true)
        end
        println("upload    $name ($(round(filesize(f.path) / 1e6; digits=1)) MB)")
        r = api("PUT", "$(dep["links"]["bucket"])/$name"; token=token, file=f.path)
        replace(r["checksum"], "md5:" => "") == sum || error("checksum of uploaded $name differs: $(r["checksum"])")
    end
end

"""
    select_domains(dataset, domains) -> Vector{String}

Domains of a command: `domains` if given, else all domains with files of the dataset.
"""
function select_domains(dataset::AbstractString, domains)
    dataset_config(dataset)
    isempty(domains) || return collect(String, domains)
    found = filter(d -> has_files(d, dataset), domain_folders())
    isempty(found) && error("no files of $dataset in $(products_dir())")
    return found
end

"""
    upload(dataset, domains=String[]; sandbox=false, allow_untagged=false, dry_run=false)

Upload the files of a dataset on each domain (all domains with its files by default)
to a draft of the next version of its record, with its metadata. All domains are
checked first (`collect_files`, `release_version`), so that nothing is uploaded if one
of them is incomplete. Running it again continues the recorded drafts. The drafts are
published on the Zenodo website, after review, and then registered with `register`.
"""
function upload(dataset::AbstractString, domains=String[]; sandbox::Bool=false,
                allow_untagged::Bool=false, dry_run::Bool=false)
    releases = []
    for domain in select_domains(dataset, domains)
        files = collect_files(domain, dataset)
        version = release_version(files, dataset; allow_untagged=allow_untagged)
        meta = record_metadata(domain, dataset, files, version)
        sandbox && delete!(meta, "communities")   # the community exists only on Zenodo
        total = sum(filesize(f.path) for f in files)
        println("$domain/$dataset $version: $(length(files)) files, $(round(total / 1e9; digits=2)) GB")
        push!(releases, (domain, files, version, meta))
    end
    if dry_run
        for (domain, files, version, meta) in releases
            println("\n$(meta["title"]), version $(meta["version"])")
            foreach(f -> println("  ", rpad(basename(f), 40), round(filesize(f.path) / 1e6; digits=1), " MB"), files)
            println("  related: ", join([r["relation"] * " " * r["identifier"] for r in meta["related_identifiers"]], ", "))
        end
        return nothing
    end
    for (domain, files, version, meta) in releases
        println("\n$domain/$dataset")
        dep = open_draft(domain, dataset; sandbox=sandbox)
        write_draft(domain, dataset, dep, version; sandbox=sandbox)
        # Metadata first, so that an interrupted draft has its title (see open_draft)
        api("PUT", "$(zenodo_url(sandbox))/api/deposit/depositions/$(dep["id"])";
            token=zenodo_token(sandbox), json=Dict("metadata" => meta))
        sync_files!(dep, files; sandbox=sandbox)
        println("Draft ready: $(dep["links"]["html"])")
    end
    flags = (sandbox ? " --sandbox" : "") * (allow_untagged ? " --allow-untagged" : "")
    println("""

        Review and publish the drafts on $(zenodo_url(sandbox))/me/uploads, then register them:
            julia --project=Publish Publish/scripts/zenodo.jl register $dataset$flags""")
end

"""
    register(dataset, domains=String[]; sandbox=false, allow_untagged=false)

Register the published drafts of a dataset (all recorded drafts by default): write the
registry file of each published record and remove its draft file. Drafts that are not
published yet are skipped.
"""
function register(dataset::AbstractString, domains=String[]; sandbox::Bool=false,
                  allow_untagged::Bool=false)
    dataset_config(dataset)
    domains = isempty(domains) ? filter(d -> read_draft(d, dataset; sandbox=sandbox) !== nothing, domain_folders()) : domains
    isempty(domains) && error("no drafts of $dataset to register (run upload first)")
    written = String[]
    for domain in domains
        draft = read_draft(domain, dataset; sandbox=sandbox)
        draft === nothing && (println("$domain/$dataset: no draft"); continue)
        id = draft["draft_id"]
        rec = published_record(id; sandbox=sandbox)
        rec === nothing && (println("$domain/$dataset: draft $id is not published yet, skipped ($(draft["url"]))"); continue)
        push!(written, register_record(domain, dataset, rec; sandbox=sandbox, allow_untagged=allow_untagged))
        rm(drafts_file(domain, dataset; sandbox=sandbox))
    end
    isempty(written) || sandbox || println("""

        Commit and push the registry, which also updates the website:
            git add registry && git commit -m "registry: $dataset" && git push""")
    return written
end

"""
    register_record(domain, dataset, rec; sandbox=false, allow_untagged=false)

Write the registry file of a published record `rec` (from the records API), after
checking that its files are the local files (names and checksums).
"""
function register_record(domain::AbstractString, dataset::AbstractString, rec;
                         sandbox::Bool=false, allow_untagged::Bool=false)
    base = zenodo_url(sandbox)
    record_id = rec["id"]
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
        replace(remote[name]["checksum"], "md5:" => "") == file_md5(f.path) ||
            error("$name of record $record_id differs from the local file $(f.path)")
        entries[name] = Dict(
            "uri" => "$base/records/$record_id/files/$name?download=1",
            "checksum" => checksum(f.path),
            "size" => filesize(f.path),
            "storage_path" => "\$datasets_dir/$domain/$(f.grid)/$name",
        )
    end
    info = Dict(
        "record_id" => record_id,
        "concept_record_id" => parse(Int, string(rec["conceptrecid"])),
        "doi" => rec["doi"],
        "concept_doi" => rec["conceptdoi"],
        "version" => get(rec["metadata"], "version", version),
        "git_tag" => version,
        "publication_date" => rec["metadata"]["publication_date"],
        "url" => "$base/records/$record_id",
    )
    path = registry_file(domain, dataset; sandbox=sandbox)
    write_registry(path, info, entries)
    println("$domain/$dataset: wrote $path ($(length(entries)) files, doi:$(info["doi"]))")
    return path
end

"""
    status(dataset, domains=String[]; sandbox=false)

State of the release of a dataset on each domain (all domains by default): the local
files (present, version), the recorded draft and whether it is published, and the
registered version.
"""
function status(dataset::AbstractString, domains=String[]; sandbox::Bool=false)
    dataset_config(dataset)
    domains = isempty(domains) ? domain_folders() : domains
    println(rpad("Domain", 16), rpad("Local files", 36), rpad("Draft", 26), "Registered")
    for domain in domains
        files = release_files(domain, dataset)
        present = count(f -> isfile(f.path), files)
        localinfo = "$present/$(length(files))"
        if present == length(files)
            data = filter(f -> !f.is_grid && endswith(f.path, ".nc"), files)
            versions = unique(something(nc_attrib(f.path, "fesmdata_version"), "missing") for f in data)
            localinfo *= " " * (length(versions) == 1 ? only(versions) : "mixed versions")
        end
        draft = read_draft(domain, dataset; sandbox=sandbox)
        draftinfo = draft === nothing ? "-" :
            "$(draft["draft_id"]) " * (published_record(draft["draft_id"]; sandbox=sandbox) === nothing ? "(not published)" : "(published)")
        reg = registry_file(domain, dataset; sandbox=sandbox)
        reginfo = isfile(reg) ? (r = read_record(domain, dataset; sandbox=sandbox)[1]; "$(r["git_tag"]) doi:$(r["doi"])") : "-"
        println(rpad(domain, 16), rpad(localinfo, 36), rpad(draftinfo, 26), reginfo)
    end
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
