# FesmData products: find, download and release them (see Publish/README.md).
#
#   julia fesmdata.jl <command> [arguments] [options]
#
# Run `julia fesmdata.jl help` for the commands. The commands for everyone (list,
# fetch) use only the Julia standard library; the commands for releases activate the
# Publish environment and install its packages if needed.

const USAGE = """
FesmData products (https://fesmc.github.io/FesmData/)

Find and download:
  list [<Dataset>] [<Domain>]                  records, of a dataset and/or a domain
  list <Domain> <Dataset> [<GRID> ...]         one record: grids, files, sizes, local files
  fetch <Domain> <Dataset> [<GRID> ...]        download into \$ICE_DATA/v2/<Domain>/<GRID>/
                                               and verify (--overwrite: replace files
                                               that differ from the registry)

Release (maintainers, see Publish/README.md):
  release <Dataset> [<Domain> ...]             upload to the GitLab packages and write the
                                               registry (--dry-run: check and list only)
  status <Dataset> [<Domain> ...]              local files, packages, registered release
  delete <Dataset> <version> [<Domain> ...]    delete the packages of a version
  archive upload|publish|register|status|discard <Dataset> [<Domain> ...]
                                               archive releases on Zenodo, for a DOI
  archive discard <draft id> ...  |  archive drafts
  site [<dir>]                                 write the website (default _site)

Options: --sandbox (test releases: registry/_sandbox/, test packages, Zenodo sandbox),
--allow-untagged (skip the release checks), --dry-run, --yes (archive publish),
--overwrite (fetch).
"""

const PUBLISH_DIR = joinpath(@__DIR__, "Publish")

"Activate the Publish environment, with its packages installed if needed (fast if they are)."
function publish_env()
    @eval import Pkg
    Base.invokelatest(Pkg.activate, PUBLISH_DIR; io=devnull)
    Base.invokelatest(Pkg.instantiate)
end

"Call the function `name` of a file included at run time (in the latest world)."
call(name::Symbol, args...; kwargs...) =
    Base.invokelatest(Base.invokelatest(getglobal, Main, name), args...; kwargs...)

function main(argv)
    opts = filter(startswith("--"), argv)
    args = filter(!startswith("--"), argv)
    known = ("--sandbox", "--allow-untagged", "--dry-run", "--yes", "--overwrite")
    for o in opts
        o in known || error("unknown option $o\n\n$USAGE")
    end
    sandbox, allow_untagged, dry_run = "--sandbox" in opts, "--allow-untagged" in opts, "--dry-run" in opts
    command = isempty(args) ? "help" : args[1]
    rest = args[2:end]
    usage(msg) = error("$msg\n\n$USAGE")

    if command == "help"
        print(USAGE)
    elseif command == "list"
        include(joinpath(PUBLISH_DIR, "catalog.jl"))
        call(:list, rest; sandbox=sandbox)
    elseif command == "fetch"
        length(rest) >= 2 || usage("fetch: give a domain and a dataset")
        include(joinpath(PUBLISH_DIR, "registry.jl"))
        paths = call(:fetch_record, rest[1], rest[2]; grids=rest[3:end],
                                  overwrite="--overwrite" in opts, sandbox=sandbox)
        println("$(length(paths)) files in $(call(:products_dir))")
    elseif command == "site"
        include(joinpath(PUBLISH_DIR, "site.jl"))
        println("Wrote ", call(:write_site, isempty(rest) ? "_site" : rest[1]))
    elseif command in ("release", "status", "delete")
        isempty(rest) && usage("$command: give a dataset")
        publish_env()
        include(joinpath(PUBLISH_DIR, "gitlab.jl"))
        dataset = rest[1]
        if command == "release"
            call(:upload, dataset, rest[2:end]; sandbox=sandbox, allow_untagged=allow_untagged, dry_run=dry_run)
        elseif command == "status"
            call(:status, dataset, rest[2:end]; sandbox=sandbox)
        else
            length(rest) >= 2 || usage("delete: give a dataset and a version")
            call(:delete_release, dataset, rest[2], rest[3:end]; sandbox=sandbox)
        end
    elseif command == "archive"
        isempty(rest) && usage("archive: give a subcommand")
        sub, rest = rest[1], rest[2:end]
        publish_env()
        include(joinpath(PUBLISH_DIR, "zenodo.jl"))
        if sub == "drafts"
            call(:list_drafts; sandbox=sandbox)
        elseif sub == "discard" && !isempty(rest) && all(a -> all(isdigit, a), rest)
            call(:discard_drafts, parse.(Int, rest); sandbox=sandbox)
        else
            isempty(rest) && usage("archive $sub: give a dataset")
            dataset, domains = rest[1], rest[2:end]
            if sub == "upload"
                call(:upload, dataset, domains; sandbox=sandbox, allow_untagged=allow_untagged, dry_run=dry_run)
            elseif sub == "publish"
                call(:publish, dataset, domains; sandbox=sandbox, allow_untagged=allow_untagged,
                                  yes="--yes" in opts)
            elseif sub == "register"
                call(:register, dataset, domains; sandbox=sandbox, allow_untagged=allow_untagged)
            elseif sub == "status"
                call(:status, dataset, domains; sandbox=sandbox)
            elseif sub == "discard"
                call(:discard, dataset, domains; sandbox=sandbox)
            else
                usage("unknown archive subcommand $sub")
            end
        end
    else
        usage("unknown command $command")
    end
end

main(ARGS)
