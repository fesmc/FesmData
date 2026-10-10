# Archive of releases on Zenodo, optional, for a DOI (see README.md): a release on the
# store (gitlab.jl) is uploaded to a draft of the next version of its Zenodo record
# (one record per dataset and domain), published, and its DOIs added to the registry
# (`[_ZENODO]`). Uses the deposit API with a personal token (scopes deposit:write and
# deposit:actions) in ZENODO_TOKEN, or ZENODO_SANDBOX_TOKEN for the sandbox, whose
# records archive the test releases (registry/_sandbox/).

include(joinpath(@__DIR__, "release.jl"))

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
        "version" => release_number(version, dataset),
        "license" => common["license"],
        "keywords" => cfg["keywords"],
        "communities" => [Dict("identifier" => common["community"])],
        "related_identifiers" => related,
    )
end

"""
    released_files(domain, dataset; sandbox=false, allow_untagged=false) -> (files, version, tables)

Local files of the release of a dataset on a domain that is registered (released on the
store) at their version, with the release tables of the registry. The local files
must be those of the registry (checksums).
"""
function released_files(domain::AbstractString, dataset::AbstractString; sandbox::Bool=false,
                        allow_untagged::Bool=false)
    files = collect_files(domain, dataset)
    version = release_version(files, dataset; allow_untagged=allow_untagged, what="$domain/$dataset")
    reg = registry_file(domain, dataset; sandbox=sandbox)
    isfile(reg) || error("$domain/$dataset is not released yet (gitlab.jl upload first)")
    tables, entries = read_record(domain, dataset; sandbox=sandbox)
    tables["_RELEASE"]["git_tag"] == version ||
        error("$domain/$dataset: the local files ($version) are not the registered release " *
              "($(tables["_RELEASE"]["git_tag"]))")
    for f in files
        get(get(entries, basename(f), Dict()), "checksum", "") == release_checksum(f.path) ||
            error("$domain/$dataset: $(f.path) differs from the registered release")
    end
    return files, version, tables
end

# ---------------------------------------------------------------------------
# Zenodo API
# ---------------------------------------------------------------------------

zenodo_url(sandbox::Bool) = sandbox ? "https://sandbox.zenodo.org" : "https://zenodo.org"

zenodo_token(sandbox::Bool) = _env(sandbox ? "ZENODO_SANDBOX_TOKEN" : "ZENODO_TOKEN")

api(method, url; token::AbstractString="", kwargs...) =
    request("Zenodo", method, url; headers=isempty(token) ? Pair{String,String}[] : ["Authorization" => "Bearer $token"],
            kwargs...)

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
a new version of the archived record in the registry, else an unpublished draft with
the title of the record (from an upload not recorded here), else a new record.
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
    archived = get(registry_tables(domain, dataset; sandbox=sandbox), "_ZENODO", nothing)
    if archived !== nothing
        id = archived["record_id"]
        println("New version of record $id ($(archived["version"]))")
        # Calling newversion again while a draft exists returns the same draft
        r = api("POST", "$base/api/deposit/depositions/$id/actions/newversion"; token=token)
        return api("GET", r["links"]["latest_draft"]; token=token)
    end
    title = record_title(domain, dataset)
    drafts = filter(d -> get(d["metadata"], "title", "") == title && !d["submitted"],
                    api("GET", "$base/api/deposit/depositions?status=draft&size=100"; token=token))
    length(drafts) > 1 && error("$domain/$dataset: several drafts titled \"$title\" " *
                                "($(join([d["id"] for d in drafts], ", "))); discard all but one")
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
    check_remote_files(files, remote, what)

Check that the files on Zenodo (`remote`: name => md5) are the local files of a release.
"""
function check_remote_files(files::Vector{ProductFile}, remote::AbstractDict, what::AbstractString)
    names = Set(basename(f) for f in files)
    missing_remote = setdiff(names, keys(remote))
    extra_remote = setdiff(keys(remote), names)
    isempty(missing_remote) && isempty(extra_remote) ||
        error("files of $what differ from the local files: missing on Zenodo " *
              "$(join(sort(collect(missing_remote)), ", ")); only on Zenodo $(join(sort(collect(extra_remote)), ", "))")
    for f in files
        remote[basename(f)] == file_md5(f.path) || error("$(basename(f)) of $what differs from the local file $(f.path)")
    end
end

"Files of a draft (deposition) as name => md5."
draft_md5(dep) = Dict(f["filename"] => replace(f["checksum"], "md5:" => "") for f in dep["files"])

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

"""
    upload(dataset, domains=String[]; sandbox=false, allow_untagged=false, dry_run=false)

Upload the release of a dataset on each domain (all domains with its files by default)
to a draft of the next version of its Zenodo record, with its metadata. Each domain
must be released on the store at the version of its local files; all are checked
first. Running it again continues the recorded drafts. The drafts are then published
with `publish`.
"""
function upload(dataset::AbstractString, domains=String[]; sandbox::Bool=false,
                allow_untagged::Bool=false, dry_run::Bool=false)
    releases = []
    for domain in select_domains(dataset, domains)
        files, version, tables = released_files(domain, dataset; sandbox=sandbox, allow_untagged=allow_untagged)
        if get(get(tables, "_ZENODO", Dict()), "git_tag", "") == version
            println("$domain/$dataset $version: already archived (doi:$(tables["_ZENODO"]["doi"])), skipped")
            continue
        end
        meta = record_metadata(domain, dataset, files, version)
        sandbox && delete!(meta, "communities")   # the community exists only on Zenodo
        total = sum(filesize(f.path) for f in files)
        println("$domain/$dataset $version: $(length(files)) files, $(round(total / 1e9; digits=2)) GB")
        push!(releases, (domain, files, version, meta))
    end
    if dry_run
        for (domain, files, version, meta) in releases
            println("\n$(meta["title"]), version $(meta["version"])")
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
    isempty(releases) && return
    flags = (sandbox ? " --sandbox" : "") * (allow_untagged ? " --allow-untagged" : "")
    println("""

        Review the drafts on $(zenodo_url(sandbox))/me/uploads if needed, then publish them:
            julia --project=Publish Publish/scripts/zenodo.jl publish $dataset$flags""")
end

"Recorded drafts of a dataset that are not published yet, as domain => draft."
function open_drafts(dataset::AbstractString, domains=String[]; sandbox::Bool=false)
    drafts = Pair{String,Any}[]
    for domain in (isempty(domains) ? domain_folders() : domains)
        draft = read_draft(domain, dataset; sandbox=sandbox)
        draft === nothing && continue
        published_record(draft["draft_id"]; sandbox=sandbox) === nothing && push!(drafts, domain => draft)
    end
    return drafts
end

"""
    publish(dataset, domains=String[]; sandbox=false, allow_untagged=false, yes=false)

Publish the recorded drafts of a dataset (all domains by default), then register them.
Each draft is checked first (its files are the local files of the release), and all
are published after one confirmation (none with `yes`). Publishing cannot be undone.
"""
function publish(dataset::AbstractString, domains=String[]; sandbox::Bool=false,
                 allow_untagged::Bool=false, yes::Bool=false)
    dataset_config(dataset)
    drafts = open_drafts(dataset, domains; sandbox=sandbox)
    isempty(drafts) && error("no unpublished drafts of $dataset (run upload first)")
    base, token = zenodo_url(sandbox), zenodo_token(sandbox)
    println("Drafts to publish on $base:")
    for (domain, draft) in drafts
        id = draft["draft_id"]
        dep = api("GET", "$base/api/deposit/depositions/$id"; token=token)
        files, version, _ = released_files(domain, dataset; sandbox=sandbox, allow_untagged=allow_untagged)
        check_remote_files(files, draft_md5(dep), "draft $id ($domain/$dataset, run upload again)")
        println("  ", rpad(domain, 16), rpad(id, 10), get(dep["metadata"], "title", "(no title)"),
                ", $version, $(length(files)) files")
    end
    yes || confirm("Publish these $(length(drafts)) drafts? This cannot be undone.") ||
        (println("Nothing published."); return String[])
    for (domain, draft) in drafts
        api("POST", "$base/api/deposit/depositions/$(draft["draft_id"])/actions/publish"; token=token)
        println("$domain/$dataset: published $(draft["draft_id"])")
    end
    return register(dataset, first.(drafts); sandbox=sandbox, allow_untagged=allow_untagged)
end

"""
    register(dataset, domains=String[]; sandbox=false, allow_untagged=false)

Add the DOIs of the published drafts of a dataset (all recorded drafts by default) to
the registry, and remove their draft files. Drafts that are not published yet (on the
Zenodo website) are skipped.
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
            git add registry && git commit -m "registry: $dataset on Zenodo" && git push""")
    return written
end

"""
    register_record(domain, dataset, rec; sandbox=false, allow_untagged=false)

Add the DOIs of a published record `rec` (from the records API) to the registry file of
its release (`[_ZENODO]`), after checking that its files are the released files.
"""
function register_record(domain::AbstractString, dataset::AbstractString, rec;
                         sandbox::Bool=false, allow_untagged::Bool=false)
    files, version, tables = released_files(domain, dataset; sandbox=sandbox, allow_untagged=allow_untagged)
    check_remote_files(files, Dict(f["key"] => replace(f["checksum"], "md5:" => "") for f in rec["files"]),
                       "record $(rec["id"])")
    base = zenodo_url(sandbox)
    tables["_ZENODO"] = Dict(
        "record_id" => rec["id"],
        "concept_record_id" => parse(Int, string(rec["conceptrecid"])),
        "doi" => rec["doi"],
        "concept_doi" => rec["conceptdoi"],
        "version" => get(rec["metadata"], "version", release_number(version, dataset)),
        "git_tag" => version,
        "publication_date" => rec["metadata"]["publication_date"],
        "url" => "$base/records/$(rec["id"])",
    )
    path = registry_file(domain, dataset; sandbox=sandbox)
    write_registry(path, tables, read_record(domain, dataset; sandbox=sandbox)[2])
    println("$domain/$dataset: doi:$(rec["doi"]) added to $path")
    return path
end

"""
    status(dataset, domains=String[]; sandbox=false)

State of the archive of a dataset on each domain (all domains by default): the
registered release, the recorded draft (and whether it is published), and the
archived version with its DOI.
"""
function status(dataset::AbstractString, domains=String[]; sandbox::Bool=false)
    dataset_config(dataset)
    println(rpad("Domain", 16), rpad("Released", 22), rpad("Draft", 26), "Archived")
    for domain in (isempty(domains) ? domain_folders() : domains)
        tables = registry_tables(domain, dataset; sandbox=sandbox)
        relinfo = haskey(tables, "_RELEASE") ? tables["_RELEASE"]["git_tag"] : "-"
        draft = read_draft(domain, dataset; sandbox=sandbox)
        draftinfo = draft === nothing ? "-" :
            "$(draft["draft_id"]) " * (published_record(draft["draft_id"]; sandbox=sandbox) === nothing ? "(not published)" : "(published)")
        archinfo = haskey(tables, "_ZENODO") ? "$(tables["_ZENODO"]["git_tag"]) doi:$(tables["_ZENODO"]["doi"])" : "-"
        println(rpad(domain, 16), rpad(relinfo, 22), rpad(draftinfo, 26), archinfo)
    end
end

"""
    discard(dataset, domains=String[]; sandbox=false)

Delete the recorded unpublished drafts of a dataset (all domains by default) on Zenodo,
and their draft files. Published records are not touched.
"""
function discard(dataset::AbstractString, domains=String[]; sandbox::Bool=false)
    dataset_config(dataset)
    drafts = open_drafts(dataset, domains; sandbox=sandbox)
    isempty(drafts) && (println("No unpublished drafts of $dataset"); return)
    discard_drafts([d["draft_id"] for (_, d) in drafts]; sandbox=sandbox)
    foreach(((domain, _),) -> rm(drafts_file(domain, dataset; sandbox=sandbox)), drafts)
end

"""
    discard_drafts(ids; sandbox=false)

Delete unpublished drafts on Zenodo by id (e.g. from `list_drafts`). Published records
are not touched.
"""
function discard_drafts(ids; sandbox::Bool=false)
    base, token = zenodo_url(sandbox), zenodo_token(sandbox)
    for id in ids
        dep = api("GET", "$base/api/deposit/depositions/$id"; token=token, missing_ok=true)
        dep === nothing && (println("draft $id: not found"); continue)
        dep["submitted"] && (println("$id is published, not discarded"); continue)
        api("DELETE", "$base/api/deposit/depositions/$id"; token=token, missing_ok=true)
        println("discarded draft $id ($(get(dep["metadata"], "title", "no title")))")
    end
end

"List the unpublished drafts of the account of the token."
function list_drafts(; sandbox::Bool=false)
    base, token = zenodo_url(sandbox), zenodo_token(sandbox)
    deps = filter(d -> !d["submitted"], api("GET", "$base/api/deposit/depositions?status=draft&size=100"; token=token))
    isempty(deps) && (println("No unpublished drafts on $base"); return)
    println(rpad("Draft", 10), rpad("Created", 12), rpad("Files", 7), "Title")
    for d in deps
        println(rpad(d["id"], 10), rpad(first(d["created"], 10), 12), rpad(length(d["files"]), 7),
                get(d["metadata"], "title", "(no title)"))
    end
end
