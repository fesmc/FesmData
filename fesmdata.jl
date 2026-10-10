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
  list <Domain> <Dataset>                      a record in detail: grids, files, sizes,
                                               files present in \$ICE_DATA
  list [<Dataset>] <GRID> ...                  the records of grids in detail (a grid
                                               implies its domain, e.g. ANT-32KM)
  fetch <Dataset> <Domain> | <GRID> ...        download into \$ICE_DATA/v2/<Domain>/<GRID>/
                                               and verify (--overwrite: replace files
                                               that differ from the registry)
  mirror [<Dataset>] [<Domain>]                all records (or those of a dataset/domain),
                                               after one confirmation with the size; run
                                               again to update (--yes: no confirmation)
  (arguments in any order)

Bring your own data (see Remap/README.md):
  remap <file.nc> <Domain> | <GRID> | all ...  remap the fields of a prepared NetCDF file
                                               (lon-lat or projected grid) onto the grids,
                                               as \$ICE_DATA/v2/<Domain>/<GRID>/<GRID>_<name>.nc
                                               (--vars=a,b: only these fields; --name=NAME:
                                               default the file name; --method=con|bilinear;
                                               --smooth=auto|<km>: Gaussian smoothing after,
                                               auto for a coarser source only; --overwrite)
  remap <Dataset> [<product> ...] [<Domain> | <GRID> ...]
                                               make the products of a thematic dataset (e.g.
                                               GHF, defined in GHF/remap.toml), preparing
                                               missing sources first (--overwrite)

Release (maintainers, see Publish/README.md):
  release <Dataset> [<Domain> ...]             upload to the GitLab packages and write the
                                               registry (--dry-run: check and list only)
  status <Dataset> [<Domain> ...]              local files, packages, registered release
  delete <Dataset> <version> [<Domain> ...]    delete the packages of a version
  archive upload|publish|register|status|discard <Dataset> [<Domain> ...]
                                               archive releases on Zenodo, for a DOI
  archive discard <draft id> ...  |  archive drafts
  docs                                         write the generated pages of the website
                                               (docs/_products.md; then quarto preview docs)

Options: --sandbox (test releases: registry/_sandbox/, test packages, Zenodo sandbox),
--allow-untagged (skip the release checks), --dry-run, --yes (mirror, archive publish),
--overwrite (fetch, remap).
"""

const PUBLISH_DIR = joinpath(@__DIR__, "Publish")
const REMAP_DIR = joinpath(@__DIR__, "Remap")

"Activate the environment in `dir`, with its packages installed if needed (fast if they are)."
function activate_env(dir)
    @eval import Pkg
    pkg = Base.invokelatest(getglobal, Main, :Pkg)
    Base.invokelatest(pkg.activate, dir; io=devnull)
    Base.invokelatest(pkg.instantiate)
end

"Call the function `name` of a file included at run time (in the latest world)."
call(name::Symbol, args...; kwargs...) =
    Base.invokelatest(Base.invokelatest(getglobal, Main, name), args...; kwargs...)

function main(argv)
    opts = filter(o -> startswith(o, "--") && !occursin('=', o), argv)
    args = filter(!startswith("--"), argv)
    known = ("--sandbox", "--allow-untagged", "--dry-run", "--yes", "--overwrite")
    for o in opts
        o in known || error("unknown option $o\n\n$USAGE")
    end
    # Options with a value: --name=value
    valued = Dict(String(k) => String(v) for (k, v) in
                  (split(o[3:end], '='; limit=2) for o in argv if startswith(o, "--") && occursin('=', o)))
    for k in keys(valued)
        k in ("vars", "name", "method", "smooth") || error("unknown option --$k\n\n$USAGE")
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
        include(joinpath(PUBLISH_DIR, "catalog.jl"))
        paths = call(:fetch_files, rest; overwrite="--overwrite" in opts, sandbox=sandbox)
        println("$(length(paths)) files in $(call(:products_dir))")
    elseif command == "mirror"
        include(joinpath(PUBLISH_DIR, "catalog.jl"))
        paths = call(:mirror, rest; overwrite="--overwrite" in opts, sandbox=sandbox, yes="--yes" in opts)
        println("$(length(paths)) files in $(call(:products_dir))")
    elseif command == "remap"
        activate_env(REMAP_DIR)
        include(joinpath(REMAP_DIR, "remap.jl"))
        vars = haskey(valued, "vars") ? split(valued["vars"], ',') : nothing
        paths = call(:remap_command, rest; vars, name=get(valued, "name", nothing),
                     method=get(valued, "method", nothing), smooth=get(valued, "smooth", nothing),
                     overwrite="--overwrite" in opts)
        println("$(length(paths)) files written")
    elseif command == "docs"
        include(joinpath(PUBLISH_DIR, "site.jl"))
        println("Wrote ", call(:write_products, joinpath(@__DIR__, "docs", "_products.md")))
    elseif command in ("release", "status", "delete")
        isempty(rest) && usage("$command: give a dataset")
        activate_env(PUBLISH_DIR)
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
        activate_env(PUBLISH_DIR)
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
