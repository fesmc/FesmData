# Archive of releases on Zenodo, optional, for a DOI (see README.md): a release on the
# store (gitlab.jl) is uploaded to a draft of the next version of its Zenodo record
# (one record per dataset and domain, and one per product with a licence of its own, see
# `ArchivePart`), published, and its DOIs added to the registry (`[_ZENODO]`,
# `[_ZENODO_<product>]`). Uses the deposit API with a personal token (scopes deposit:write and
# deposit:actions) in ZENODO_TOKEN, or ZENODO_SANDBOX_TOKEN for the sandbox, whose
# records archive the test releases (registry/_sandbox/).

include(joinpath(@__DIR__, "release.jl"))

"""
    ArchivePart

A Zenodo record of the release of a dataset on a domain: the record of the dataset
(`product` empty), under the licence of the archive (`license` of `_zenodo` in
datasets.toml), with the files of all its products but those with a licence of their
own; and one record per such product (`licenses` of the dataset in datasets.toml,
product => Zenodo licence id, e.g. `licenses = { PaleoMIST_taub = "gpl-3.0-only" }`),
with its files, since a record has one licence. Each record has its draft file and its
table in the registry file of the release (`[_ZENODO]`, `[_ZENODO_<product>]`).
"""
struct ArchivePart
    domain::String
    dataset::String
    product::String          # "" for the record of the dataset
    license::String
end

"Products of a dataset with a licence of their own (product => Zenodo licence id)."
dataset_licenses(dataset::AbstractString) =
    Dict{String,String}(get(dataset_config(dataset), "licenses", Dict{String,Any}()))

"Records of a dataset on a domain: that of the dataset, then one per product with a licence of its own."
archive_parts(domain::AbstractString, dataset::AbstractString) =
    vcat([ArchivePart(domain, dataset, "", read_datasets()["_zenodo"]["license"])],
         [ArchivePart(domain, dataset, p, l) for (p, l) in sort(collect(dataset_licenses(dataset)))])

"Name of a record part, for the messages: <Domain>/<Dataset>[-<product>]."
part_name(part::ArchivePart) = "$(part.domain)/$(part.dataset)" * (isempty(part.product) ? "" : "-$(part.product)")

"Registry table of the DOIs of a record: `_ZENODO`, or `_ZENODO_<product>`."
zenodo_table(part::ArchivePart) = isempty(part.product) ? "_ZENODO" : "_ZENODO_$(part.product)"

"""
    file_product(f, dataset) -> String

Product of a file of a dataset, from its name (`<GRID>_<Dataset>-<product>.nc`, or
`<Dataset>-<product>.nc` and `.txt` for records); empty for other files.
"""
function file_product(f::ProductFile, dataset::AbstractString)
    m = match(Regex("(?:^|_)\\Q$(dataset)\\E-(.+)\\.[a-z]+\$"), basename(f))
    return m === nothing ? "" : String(m[1])
end

"""
    part_files(part, files) -> Vector{ProductFile}

Files of a record among the files of the release of its dataset on its domain: those of
its product, or for the record of the dataset all but those of the products with a
licence of their own.
"""
function part_files(part::ArchivePart, files::Vector{ProductFile})
    isempty(part.product) || return filter(f -> file_product(f, part.dataset) == part.product, files)
    own = keys(dataset_licenses(part.dataset))
    return filter(f -> !(file_product(f, part.dataset) in own), files)
end

"Title of a record: of a dataset on a domain, or of one of its products."
record_title(part::ArchivePart) =
    "FesmData $(part.domain) $(part.dataset)$(isempty(part.product) ? "" : "-" * part.product): " *
    dataset_config(part.dataset)["title"]

"""
    record_metadata(part, files, version; others=String[]) -> Dict

Zenodo metadata of a record (`part`) with its `files`; `others`, the products of the
dataset on the domain in records of their own (named in the record of the dataset).
"""
function record_metadata(part::ArchivePart, files::Vector{ProductFile}, version::AbstractString;
                         others=String[])
    domain, dataset = part.domain, part.dataset
    common = read_datasets()["_zenodo"]
    cfg = dataset_config(dataset)
    data = filter(f -> endswith(f.path, ".nc"), files)
    commit = something(nc_attrib(first(data).path, "fesmdata_commit"), "unknown")
    ref = _git("tag", "--list", version) == version ? version : commit == "unknown" ? "main" : commit
    grids = filter(!isempty, unique(f.grid for f in files))
    readme = "$REPO_URL/blob/$ref/$(cfg["readme"])"
    layout = isempty(grids) ?
        """Non-gridded data (time series, sites, profiles) as NetCDF files following the CF
        conventions for discrete sampling geometries (e.g. <code>$(basename(first(data)))</code>).""" :
        """<p>Domain: $domain. Grids: $(join(grids, ", ")).</p>
        Each grid has its own files, named after the grid (e.g. <code>$(basename(first(data)))</code>).
        """ * (dataset == GRIDS ? "" :
        """The grid description for cdo (<code>grid_&lt;GRID&gt;.txt</code>) and the grid
        file (<code>&lt;GRID&gt;_grid.nc</code>) of each grid are in the record of the
        dataset Grids on the domain.""")
    own = isempty(part.product) ?
        (isempty(others) ? "" :
         """<p>The products $(join(("$dataset-$p" for p in others), ", ")) are in records of their own,
         for their licences (see the README).</p>""") :
        """<p>This record holds the product $dataset-$(part.product) of the dataset $dataset, in a
        record of its own for its licence ($(part.license)); the other products are in the
        record "$(record_title(ArchivePart(domain, dataset, "", common["license"])))".</p>"""
    description = """
        <p>$(strip(replace(cfg["description"], '\n' => ' ')))</p>
        $own
        <p>Produced with <a href="$REPO_URL">FesmData</a> version $version (commit
        $commit); see the <a href="$readme">$dataset README</a> for the sources and methods.
        $layout To download into the FesmData layout,
        use <code>julia fesmdata.jl fetch $domain $dataset</code>.</p>
        """
    related = Any[Dict("identifier" => "$REPO_URL/tree/$ref", "relation" => "isCompiledBy",
                       "resource_type" => "software")]
    for doi in source_dois(files)
        push!(related, Dict("identifier" => doi, "relation" => "isDerivedFrom", "resource_type" => "dataset"))
    end
    return Dict(
        "upload_type" => "dataset",
        "title" => record_title(part),
        "creators" => common["creators"],
        "description" => description,
        "version" => release_number(version, dataset),
        "license" => part.license,
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
    reg = registry_file(domain, dataset; sandbox=sandbox)
    isfile(reg) || error("$domain/$dataset is not released yet (fesmdata.jl release first)")
    tables, entries = read_record(domain, dataset; sandbox=sandbox)
    version = release_version(files, dataset; old=entries, allow_untagged=allow_untagged, what="$domain/$dataset")
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
    drafts_file(part; sandbox=false)

File recording the open draft of a record, written by `upload` and removed by
`register`: registry/_drafts/<Domain>/<Dataset>[-<product>].toml (local, not tracked).
"""
drafts_file(part::ArchivePart; sandbox::Bool=false) =
    joinpath(registry_dir(sandbox), "_drafts", part.domain,
             part.dataset * (isempty(part.product) ? "" : "-$(part.product)") * ".toml")

"Recorded draft of a record (`nothing` if none)."
function read_draft(part::ArchivePart; sandbox::Bool=false)
    path = drafts_file(part; sandbox=sandbox)
    return isfile(path) ? TOML.parsefile(path) : nothing
end

function write_draft(part::ArchivePart, dep, version::AbstractString; sandbox::Bool=false)
    path = drafts_file(part; sandbox=sandbox)
    mkpath(dirname(path))
    open(io -> TOML.print(io, Dict("draft_id" => dep["id"], "version" => version,
                                   "url" => dep["links"]["html"])), path, "w")
    return path
end

"Published record of a draft (`nothing` if the draft is not published yet)."
published_record(id::Integer; sandbox::Bool=false) =
    api("GET", "$(zenodo_url(sandbox))/api/records/$id"; missing_ok=true)

"""
    open_draft(part; sandbox=false) -> deposition

Draft of the next version of a record: the draft recorded by an earlier `upload`, else
a new version of the archived record in the registry, else an unpublished draft with
the title of the record (from an upload not recorded here), else a new record.
"""
function open_draft(part::ArchivePart; sandbox::Bool=false)
    base, token = zenodo_url(sandbox), zenodo_token(sandbox)
    draft = read_draft(part; sandbox=sandbox)
    if draft !== nothing
        id = draft["draft_id"]
        published_record(id; sandbox=sandbox) === nothing ||
            error("$(part_name(part)): draft $id is already published; register it first")
        println("Draft $id of an earlier upload")
        return api("GET", "$base/api/deposit/depositions/$id"; token=token)
    end
    archived = get(registry_tables(part.domain, part.dataset; sandbox=sandbox), zenodo_table(part), nothing)
    if archived !== nothing
        id = archived["record_id"]
        println("New version of record $id ($(archived["version"]))")
        # Calling newversion again while a draft exists returns the same draft
        r = api("POST", "$base/api/deposit/depositions/$id/actions/newversion"; token=token)
        return api("GET", r["links"]["latest_draft"]; token=token)
    end
    title = record_title(part)
    drafts = filter(d -> get(d["metadata"], "title", "") == title && !d["submitted"],
                    api("GET", "$base/api/deposit/depositions?status=draft&size=100"; token=token))
    length(drafts) > 1 && error("$(part_name(part)): several drafts titled \"$title\" " *
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
    archive_releases(domain, dataset, files, version, tables; sandbox=false) -> [(part, files, version, meta)]

The records of the release (`files` at `version`, registry `tables`) of a dataset on a
domain to upload: each record (`archive_parts`) with files there and not archived at
this version yet, with its files and metadata.
"""
function archive_releases(domain::AbstractString, dataset::AbstractString, files::Vector{ProductFile},
                          version::AbstractString, tables::AbstractDict; sandbox::Bool=false)
    parts = [(part, part_files(part, files)) for part in archive_parts(domain, dataset)]
    others = [part.product for (part, fs) in parts if !isempty(part.product) && !isempty(fs)]
    releases = []
    for (part, fs) in parts
        isempty(fs) && continue
        z = get(tables, zenodo_table(part), Dict())
        if get(z, "git_tag", "") == version
            println("$(part_name(part)) $version: already archived (doi:$(z["doi"])), skipped")
            continue
        end
        meta = record_metadata(part, fs, version; others=others)
        sandbox && delete!(meta, "communities")   # the community exists only on Zenodo
        total = sum(filesize(f.path) for f in fs)
        println("$(part_name(part)) $version: $(length(fs)) files, $(round(total / 1e9; digits=2)) GB, $(part.license)")
        push!(releases, (part, fs, version, meta))
    end
    return releases
end

"The records of `archive_releases` (dry run): title, version, licence, files and related identifiers."
function print_releases(releases)
    for (part, files, version, meta) in releases
        println("\n$(meta["title"]), version $(meta["version"]), licence $(meta["license"])")
        println("  files: ", join(basename.(files), ", "))
        println("  related: ", join([r["relation"] * " " * r["identifier"] for r in meta["related_identifiers"]], ", "))
    end
end

"""
    upload(dataset, domains=String[]; sandbox=false, allow_untagged=false, dry_run=false)

Upload the release of a dataset on each domain (all domains with its files by default)
to drafts of the next versions of its Zenodo records (see `ArchivePart`), with their
metadata. Each domain must be released on the store at the version of its local files;
all are checked first. Running it again continues the recorded drafts. The drafts are
then published with `publish`. With `dry_run`, only the records are listed.
"""
function upload(dataset::AbstractString, domains=String[]; sandbox::Bool=false,
                allow_untagged::Bool=false, dry_run::Bool=false)
    releases = []
    for domain in select_domains(dataset, domains)
        all_files, version, tables = released_files(domain, dataset; sandbox=sandbox, allow_untagged=allow_untagged)
        append!(releases, archive_releases(domain, dataset, all_files, version, tables; sandbox=sandbox))
    end
    if dry_run
        print_releases(releases)
        return nothing
    end
    for (part, files, version, meta) in releases
        println("\n$(part_name(part))")
        dep = open_draft(part; sandbox=sandbox)
        write_draft(part, dep, version; sandbox=sandbox)
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
            julia fesmdata.jl archive publish $dataset$flags""")
end

"Recorded drafts of a dataset that are not published yet, as part => draft."
function open_drafts(dataset::AbstractString, domains=String[]; sandbox::Bool=false)
    drafts = Pair{ArchivePart,Any}[]
    for domain in (isempty(domains) ? release_domains(dataset) : domains), part in archive_parts(domain, dataset)
        draft = read_draft(part; sandbox=sandbox)
        draft === nothing && continue
        published_record(draft["draft_id"]; sandbox=sandbox) === nothing && push!(drafts, part => draft)
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
    for (part, draft) in drafts
        id = draft["draft_id"]
        dep = api("GET", "$base/api/deposit/depositions/$id"; token=token)
        all_files, version, _ = released_files(part.domain, dataset; sandbox=sandbox, allow_untagged=allow_untagged)
        files = part_files(part, all_files)
        check_remote_files(files, draft_md5(dep), "draft $id ($(part_name(part)), run upload again)")
        println("  ", rpad(part.domain, 16), rpad(id, 10), get(dep["metadata"], "title", "(no title)"),
                ", $version, $(length(files)) files, $(part.license)")
    end
    yes || confirm("Publish these $(length(drafts)) drafts? This cannot be undone.") ||
        (println("Nothing published."); return String[])
    for (part, draft) in drafts
        api("POST", "$base/api/deposit/depositions/$(draft["draft_id"])/actions/publish"; token=token)
        println("$(part_name(part)): published $(draft["draft_id"])")
    end
    return register(dataset, unique(p.domain for p in first.(drafts)); sandbox=sandbox, allow_untagged=allow_untagged)
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
    parts = [part for domain in (isempty(domains) ? release_domains(dataset) : domains)
             for part in archive_parts(domain, dataset) if read_draft(part; sandbox=sandbox) !== nothing]
    isempty(parts) && error("no drafts of $dataset to register (run upload first)")
    written = String[]
    for part in parts
        draft = read_draft(part; sandbox=sandbox)
        id = draft["draft_id"]
        rec = published_record(id; sandbox=sandbox)
        rec === nothing && (println("$(part_name(part)): draft $id is not published yet, skipped ($(draft["url"]))"); continue)
        push!(written, register_record(part, rec; sandbox=sandbox, allow_untagged=allow_untagged))
        rm(drafts_file(part; sandbox=sandbox))
    end
    isempty(written) || sandbox || println("""

        Commit and push the registry, which also updates the website:
            git add registry && git commit -m "registry: $dataset on Zenodo" && git push""")
    return written
end

"""
    register_record(part, rec; sandbox=false, allow_untagged=false)

Add the DOIs of a published record `rec` (from the records API) to the registry file of
its release (`[_ZENODO]`, or `[_ZENODO_<product>]`), after checking that its files are
the released files of the record.
"""
function register_record(part::ArchivePart, rec; sandbox::Bool=false, allow_untagged::Bool=false)
    domain, dataset = part.domain, part.dataset
    all_files, version, tables = released_files(domain, dataset; sandbox=sandbox, allow_untagged=allow_untagged)
    files = part_files(part, all_files)
    check_remote_files(files, Dict(f["key"] => replace(f["checksum"], "md5:" => "") for f in rec["files"]),
                       "record $(rec["id"])")
    base = zenodo_url(sandbox)
    tables[zenodo_table(part)] = Dict(
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
    println("$(part_name(part)): doi:$(rec["doi"]) added to $path")
    return path
end

"""
    status(dataset, domains=String[]; sandbox=false)

State of the archive of a dataset on each domain (all domains by default), per record
(see `ArchivePart`): the registered release, the recorded draft (and whether it is
published), and the archived version with its DOI.
"""
function status(dataset::AbstractString, domains=String[]; sandbox::Bool=false)
    dataset_config(dataset)
    println(rpad("Record", 36), rpad("Released", 22), rpad("Draft", 26), "Archived")
    for domain in (isempty(domains) ? release_domains(dataset) : domains), part in archive_parts(domain, dataset)
        tables = registry_tables(domain, dataset; sandbox=sandbox)
        relinfo = haskey(tables, "_RELEASE") ? tables["_RELEASE"]["git_tag"] : "-"
        draft = read_draft(part; sandbox=sandbox)
        draftinfo = draft === nothing ? "-" :
            "$(draft["draft_id"]) " * (published_record(draft["draft_id"]; sandbox=sandbox) === nothing ? "(not published)" : "(published)")
        z = get(tables, zenodo_table(part), nothing)
        archinfo = z === nothing ? "-" : "$(z["git_tag"]) doi:$(z["doi"])"
        println(rpad(part_name(part), 36), rpad(relinfo, 22), rpad(draftinfo, 26), archinfo)
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
    foreach(((part, _),) -> rm(drafts_file(part; sandbox=sandbox)), drafts)
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
