# Store of the released products (see README.md): the generic package registry of a
# GitLab project ([_gitlab] in datasets.toml), with one package per domain, dataset and
# grid (<Domain>_<Dataset>_<GRID>, e.g. Antarctica_Topo_ANT-32KM), versioned by the
# release (2.0.0). Uploads need a token of the project with the scope api in
# GITLAB_TOKEN; downloads need none (public project). Test releases (`sandbox`) go to
# packages named test_<Domain>_<Dataset>_<GRID>, with their registry in
# registry/_sandbox/.

using Dates

include(joinpath(@__DIR__, "release.jl"))

gitlab_config() = read_datasets()["_gitlab"]

# The token, if set; reading the packages of the public project needs none
gitlab(method, url; kwargs...) =
    request("GitLab", method, url; headers=haskey(ENV, "GITLAB_TOKEN") ? ["PRIVATE-TOKEN" => ENV["GITLAB_TOKEN"]] : Pair{String,String}[],
            kwargs...)

const _PROJECT_API = Ref{String}("")

"API URL of the project, by its id (stable if the project is renamed)."
function project_api()
    if isempty(_PROJECT_API[])
        cfg = gitlab_config()
        p = request("GitLab", "GET", "$(cfg["url"])/api/v4/projects/$(replace(cfg["project"], "/" => "%2F"))")
        _PROJECT_API[] = "$(cfg["url"])/api/v4/projects/$(p["id"])"
    end
    return _PROJECT_API[]
end

"Web page of the packages of the project, filtered by `search`."
packages_page(search::AbstractString) =
    "$(gitlab_config()["url"])/$(gitlab_config()["project"])/-/packages?search=$search"

"Package of the files of a dataset on a grid of a domain."
package_name(domain::AbstractString, dataset::AbstractString, grid::AbstractString; sandbox::Bool=false) =
    (sandbox ? "test_" : "") * "$(domain)_$(dataset)_$(grid)"

"Download URL of a file of a package (no token needed for a public project)."
download_url(package::AbstractString, number::AbstractString, name::AbstractString) =
    "$(project_api())/packages/generic/$package/$number/$name"

"Package of a name and version in the project (`nothing` if none)."
function find_package(package::AbstractString, number::AbstractString)
    found = filter(p -> p["name"] == package && p["version"] == number,
                   gitlab("GET", "$(project_api())/packages?package_type=generic&package_name=$package&per_page=100"))
    return isempty(found) ? nothing : only(found)
end

"Files of a package (name, id, file_sha256, size, ...)."
package_files(pkg) = gitlab("GET", "$(project_api())/packages/$(pkg["id"])/package_files?per_page=100")

sha256_of(path::AbstractString) = replace(release_checksum(path), "sha256:" => "")

"""
    sync_package!(package, number, files)

Make the files of a package version those of `files`: keep files with the same name
and checksum, upload new and changed files, and delete the others; then check that
the package holds exactly these files.
"""
function sync_package!(package::AbstractString, number::AbstractString, files::Vector{ProductFile})
    api = project_api()
    names = Dict(basename(f) => f for f in files)
    pkg = find_package(package, number)
    kept = Set{String}()
    for r in (pkg === nothing ? [] : package_files(pkg))
        name = r["file_name"]
        if haskey(names, name) && !(name in kept) && r["file_sha256"] == sha256_of(names[name].path)
            push!(kept, name)
        else
            gitlab("DELETE", "$api/packages/$(pkg["id"])/package_files/$(r["id"])"; missing_ok=true)
        end
    end
    for f in files
        name = basename(f)
        name in kept && (println("  keep      $name"); continue)
        println("  upload    $name ($(round(filesize(f.path) / 1e6; digits=1)) MB)")
        gitlab("PUT", download_url(package, number, name); file=f.path)
    end
    remote = Dict(r["file_name"] => r["file_sha256"] for r in package_files(find_package(package, number)))
    for f in files
        get(remote, basename(f), "") == sha256_of(f.path) ||
            error("$package $number: $(basename(f)) on GitLab differs from the local file $(f.path)")
    end
    length(remote) == length(files) || error("$package $number: other files than the release on GitLab")
end

"""
    upload(dataset, domains=String[]; sandbox=false, allow_untagged=false, dry_run=false)

Release a dataset on each domain (all domains with its files by default): upload the
files of each grid to its package, versioned by the release, and write the registry
file of the domain. All domains are checked first (`collect_files`, `release_version`),
so that nothing is uploaded if one of them is incomplete. Domains already released at
this version are skipped; an interrupted upload is continued by running it again.
"""
function upload(dataset::AbstractString, domains=String[]; sandbox::Bool=false,
                allow_untagged::Bool=false, dry_run::Bool=false)
    releases = []
    for domain in select_domains(dataset, domains)
        files = collect_files(domain, dataset)
        version = release_version(files, dataset; allow_untagged=allow_untagged, what="$domain/$dataset")
        number = release_number(version, dataset)
        grids = unique(f.grid for f in files)
        total = sum(filesize(f.path) for f in files)
        if get(get(registry_tables(domain, dataset; sandbox=sandbox), "_RELEASE", Dict()), "git_tag", "") == version
            println("$domain/$dataset $version: already released, skipped")
            continue
        end
        println("$domain/$dataset $version: $(length(files)) files in $(length(grids)) packages, " *
                "$(round(total / 1e9; digits=2)) GB")
        push!(releases, (domain, files, version, number))
    end
    if dry_run
        for (domain, files, version, number) in releases, grid in unique(f.grid for f in files)
            println("  ", package_name(domain, dataset, grid; sandbox=sandbox), " ", number, ": ",
                    join(basename.(filter(f -> f.grid == grid, files)), ", "))
        end
        return nothing
    end
    isempty(releases) || _env("GITLAB_TOKEN")   # needed to upload
    for (domain, files, version, number) in releases
        entries = Dict{String,Any}()
        for grid in unique(f.grid for f in files)
            package = package_name(domain, dataset, grid; sandbox=sandbox)
            println("$package $number")
            gfiles = filter(f -> f.grid == grid, files)
            sync_package!(package, number, gfiles)
            for f in gfiles
                entries[basename(f)] = Dict("uri" => download_url(package, number, basename(f)),
                                            "checksum" => release_checksum(f.path), "size" => filesize(f.path),
                                            "storage_path" => "\$datasets_dir/$domain/$(f.grid)/$(basename(f))")
            end
        end
        tables = registry_tables(domain, dataset; sandbox=sandbox)   # keeps an earlier _ZENODO
        tables["_RELEASE"] = Dict("version" => number, "git_tag" => version, "date" => string(today()),
                                  "store" => packages_page(package_name(domain, dataset, ""; sandbox=sandbox)))
        path = write_registry(registry_file(domain, dataset; sandbox=sandbox), tables, entries)
        println("$domain/$dataset: released $number, wrote $path")
    end
    isempty(releases) || sandbox || println("""

        Commit and push the registry, which also updates the website:
            git add registry && git commit -m "registry: $dataset" && git push""")
end

"""
    status(dataset, domains=String[]; sandbox=false)

State of the release of a dataset on each domain (all domains by default): the local
files (present, version), the packages of that version on GitLab, and the registered
release (and its DOI if archived on Zenodo).
"""
function status(dataset::AbstractString, domains=String[]; sandbox::Bool=false)
    dataset_config(dataset)
    domains = isempty(domains) ? release_domains(dataset) : domains
    println(rpad("Domain", 16), rpad("Local files", 34), rpad("GitLab packages", 28), "Registered")
    for domain in domains
        files = release_files(domain, dataset)
        present = count(f -> isfile(f.path), files)
        localinfo, gitinfo = "$present/$(length(files))", "-"
        if present == length(files)
            version = files_version(files)
            localinfo *= " " * version
            number = release_number(version, dataset)
            grids = unique(f.grid for f in files)
            n = count(g -> find_package(package_name(domain, dataset, g; sandbox=sandbox), number) !== nothing, grids)
            gitinfo = "$n/$(length(grids)) $number"
        end
        tables = registry_tables(domain, dataset; sandbox=sandbox)
        reginfo = haskey(tables, "_RELEASE") ? "$(tables["_RELEASE"]["version"]) ($(tables["_RELEASE"]["date"]))" : "-"
        if haskey(tables, "_ZENODO")
            z = tables["_ZENODO"]
            reginfo *= z["git_tag"] == get(tables["_RELEASE"], "git_tag", "") ? " doi:$(z["doi"])" : " (archive: $(z["version"]))"
        end
        println(rpad(domain, 16), rpad(localinfo, 34), rpad(gitinfo, 28), reginfo)
    end
end

"""
    delete_release(dataset, number, domains=String[]; sandbox=false)

Delete the packages of a version of a dataset on GitLab (all domains by default), after
one confirmation, e.g. those of a test or of an incomplete upload. A registered release
is not deleted (outside the tests).
"""
function delete_release(dataset::AbstractString, number::AbstractString, domains=String[]; sandbox::Bool=false)
    dataset_config(dataset)
    targets = []
    for domain in (isempty(domains) ? release_domains(dataset) : domains)
        tables = registry_tables(domain, dataset; sandbox=sandbox)
        registered = get(get(tables, "_RELEASE", Dict()), "version", "") == number
        registered && !sandbox && (println("$domain/$dataset $number is registered, not deleted"); continue)
        for og in folder_grids(domain)[2]
            pkg = find_package(package_name(domain, dataset, og.grid.name; sandbox=sandbox), number)
            pkg === nothing || push!(targets, (domain, pkg, registered))
        end
    end
    isempty(targets) && (println("No packages of $dataset $number to delete"); return)
    _env("GITLAB_TOKEN")   # needed to delete
    foreach(((_, pkg, _),) -> println("  ", pkg["name"], " ", pkg["version"]), targets)
    confirm("Delete these $(length(targets)) packages? This cannot be undone.") || (println("Nothing deleted."); return)
    for (domain, pkg, registered) in targets
        gitlab("DELETE", "$(project_api())/packages/$(pkg["id"])"; missing_ok=true)
        println("deleted $(pkg["name"]) $(pkg["version"])")
        registered && rm(registry_file(domain, dataset; sandbox=sandbox); force=true)
    end
end
