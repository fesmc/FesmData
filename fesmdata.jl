# FesmData products: find, download and release them (see Publish/README.md).
#
#   julia fesmdata.jl <command> [arguments] [options]
#
# Run `julia fesmdata.jl help` for the commands. The commands for everyone (list,
# fetch) use only the Julia standard library, except fetch by cropping (on a nest or
# crop), which, like the commands for releases, activates the Publish environment and
# installs its packages if needed.

const USAGE = """
FesmData products (https://fesmc.github.io/FesmData/), in \$FESMDATA_PRODUCTS (default
\$FESMDATA/products, see https://fesmc.github.io/FesmData/download.html)

Find and download:
  list [<Dataset>] [<Domain>]                  the released datasets on each domain (of a
                                               dataset and/or a domain), and the datasets
                                               by cropping on nests and crops
  list <Domain> <Dataset>                      a dataset on a domain in detail: grids,
                                               files, sizes, files present in
                                               \$FESMDATA_PRODUCTS
  list [<Dataset>] <GRID> ...                  the datasets on grids in detail (a grid
                                               implies its domain, e.g. ANT-32KM)
  search <term> ...                            the products whose dataset, name, sources
                                               (authors, references), variables or domains
                                               contain all terms (ignoring case), with
                                               their sources and domains
  cite <Dataset> [<product> ...]               where the references of the products are:
                                               the READMEs of their sources and dataset
  path <Dataset> [<Domain> | <GRID> ...] [<product> ...]
                                               the files of the products present in
                                               \$FESMDATA_PRODUCTS, one per line (e.g.
                                               ncview \$(julia fesmdata.jl path ...))
  domains                                      the domains, crops and nests: folder, grid
                                               prefix, kind, grids, projection, active
  where <lon> <lat>                            the domains, crops and nests containing a
                                               point, with its position on their grids and
                                               their datasets (installs the Publish
                                               packages once)
  fetch <Dataset> <Domain> | <GRID> ...        download into \$FESMDATA_PRODUCTS/<Domain>/<GRID>/
                                               and verify; files of earlier releases are
                                               updated (--overwrite: also replace files
                                               changed locally). On a nest or crop: also
                                               the products it has no release of, from its
                                               parent domain or a crop containing it, cut
                                               to it (installs the Publish packages once)
  mirror [<Dataset>] [<Domain>]                all released datasets on all domains (or
                                               of a dataset/domain), after one confirmation
                                               with the size; run again to update (--yes:
                                               no confirmation); also the products by
                                               cropping on the active nests and crops
  (arguments in any order; --dir=<folder>: list, path, fetch or mirror in <folder> instead of
  \$FESMDATA_PRODUCTS, e.g. to archive the releases there before updating: files already in
  \$FESMDATA_PRODUCTS are hard linked (--copy: copied), and the registry files go to
  <folder>/registry/; the crops are written there too)

Your own data (see Remap/README.md):
  remap <file.nc> <Domain> | <GRID> | all ...  remap the fields of a prepared NetCDF file
                                               (lon-lat or projected grid) onto the grids,
                                               as \$FESMDATA_PRODUCTS/<Domain>/<GRID>/<GRID>_<name>.nc
                                               (--vars=a,b: only these fields; --name=NAME:
                                               default the file name; --method=con|bilinear;
                                               --smooth=auto|<km>: Gaussian smoothing after,
                                               auto for a coarser source only; --overwrite)
  remap <Dataset> [<product> ...] [<Domain> | <GRID> ...]
                                               make the products of a thematic dataset (e.g.
                                               GHF, defined in GHF/remap.toml), preparing
                                               missing sources first (--overwrite)

Records datasets, non-gridded data (maintainers, see Remap/DATASETS.md):
  record <Dataset> [<product> ...]             make the products of a records dataset
                                               (defined in <Dataset>/records.toml) as
                                               \$FESMDATA_PRODUCTS/Records/<Dataset>/<Dataset>-<product>[-<part>].nc
                                               with their text forms (.txt), preparing
                                               missing sources first (--overwrite)

Figures for the website (maintainers, see Figures/README.md):
  figures <Dataset>                            maps of the products of a dataset and its
                                               gallery page, docs/figures/<Dataset>/
  figures Domains                              overview figure of each Topo product of each
                                               domain, docs/figures/Domains/

Release (maintainers, see Publish/README.md):
  stamp <Dataset> [<Domain> ...]               set the version of the files to the release
                                               tag on the checked-out commit (in place)
  release <Dataset> [<Domain> ...]             upload to the packages (Helmholtz Codebase)
                                               and write the registry (--dry-run: check
                                               and list only)
  status <Dataset> [<Domain> ...]              local files, packages, registered release
  prune [<Dataset>] [<Domain>]                 delete the files in \$FESMDATA_PRODUCTS that no
                                               release refers to (not crops, unreleased
                                               products, grid files in use), after one
                                               confirmation (--yes: none)
  delete <Dataset> <version> [<Domain> ...]    delete the packages of a version
  archive upload|publish|register|status|discard <Dataset> [<Domain> ...]
                                               archive releases on Zenodo, for a DOI
  archive discard <draft id> ...  |  archive drafts
  docs                                         write the generated pages of the website
                                               (docs/_*.md, docs/_downloads/; then quarto
                                               preview docs)

Options: --sandbox (test releases: registry/_sandbox/, test packages, Zenodo sandbox),
--allow-untagged (skip the release checks), --dry-run, --yes (mirror, prune, archive publish),
--overwrite (fetch, remap, record).
"""

const PUBLISH_DIR = joinpath(@__DIR__, "Publish")
const REMAP_DIR = joinpath(@__DIR__, "Remap")
const RECORDS_DIR = joinpath(@__DIR__, "Records")
const FIGURES_DIR = joinpath(@__DIR__, "Figures")

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

"""
    crop_downloaded(cropped, dir; sandbox=false) -> Vector{String}

Cut the products by cropping on nests and crops, `cropped` (left by `fetch` or
`mirror`), from the files just downloaded into \$FESMDATA_PRODUCTS or `dir`, in the
Publish environment (crop.jl). Returns the paths of the crops and their grid files.
"""
function crop_downloaded(cropped, dir; sandbox::Bool=false)
    isempty(cropped) && return String[]
    activate_env(PUBLISH_DIR)
    include(joinpath(PUBLISH_DIR, "crop.jl"))
    return call(:crop_files, cropped, call(:local_root, dir); sandbox=sandbox)
end

function main(argv)
    opts = filter(o -> startswith(o, "--") && !occursin('=', o), argv)
    args = filter(!startswith("--"), argv)
    known = ("--sandbox", "--allow-untagged", "--dry-run", "--yes", "--overwrite", "--copy")
    for o in opts
        o in known || error("unknown option $o\n\n$USAGE")
    end
    # Options with a value: --name=value
    valued = Dict(String(k) => String(v) for (k, v) in
                  (split(o[3:end], '='; limit=2) for o in argv if startswith(o, "--") && occursin('=', o)))
    for k in keys(valued)
        k in ("vars", "name", "method", "smooth", "dir") || error("unknown option --$k\n\n$USAGE")
    end
    sandbox, allow_untagged, dry_run = "--sandbox" in opts, "--allow-untagged" in opts, "--dry-run" in opts
    command = isempty(args) ? "help" : args[1]
    rest = args[2:end]
    usage(msg) = error("$msg\n\n$USAGE")

    if command == "help"
        print(USAGE)
    elseif command == "list"
        include(joinpath(PUBLISH_DIR, "catalog.jl"))
        call(:list, rest; dir=get(valued, "dir", nothing), sandbox=sandbox)
    elseif command == "search"
        isempty(rest) && usage("search: give a term")
        include(joinpath(PUBLISH_DIR, "discover.jl"))
        call(:search, rest; sandbox=sandbox)
    elseif command == "cite"
        include(joinpath(PUBLISH_DIR, "discover.jl"))
        call(:cite, rest; sandbox=sandbox)
    elseif command == "path"
        include(joinpath(PUBLISH_DIR, "discover.jl"))
        call(:product_paths, rest; dir=get(valued, "dir", nothing), sandbox=sandbox)
    elseif command == "domains"
        include(joinpath(PUBLISH_DIR, "discover.jl"))
        call(:list_domains)
    elseif command == "where"
        length(rest) == 2 || usage("where: give a longitude and a latitude")
        lon, lat = tryparse.(Float64, rest)
        (lon === nothing || lat === nothing) && usage("where: give a longitude and a latitude (degrees)")
        activate_env(PUBLISH_DIR)
        include(joinpath(PUBLISH_DIR, "where.jl"))
        call(:domains_at, lon, lat; sandbox=sandbox)
    elseif command == "fetch"
        include(joinpath(PUBLISH_DIR, "catalog.jl"))
        dir = get(valued, "dir", nothing)
        paths, cropped = call(:fetch_files, rest; dir=dir, copy="--copy" in opts, overwrite="--overwrite" in opts,
                              sandbox=sandbox)
        append!(paths, crop_downloaded(cropped, dir; sandbox=sandbox))
        println("$(length(paths)) files in $(call(:local_root, dir))")
    elseif command == "mirror"
        include(joinpath(PUBLISH_DIR, "catalog.jl"))
        dir = get(valued, "dir", nothing)
        paths, cropped = call(:mirror, rest; dir=dir, copy="--copy" in opts, overwrite="--overwrite" in opts,
                              sandbox=sandbox, yes="--yes" in opts)
        append!(paths, crop_downloaded(cropped, dir; sandbox=sandbox))
        println("$(length(paths)) files in $(call(:local_root, dir))")
    elseif command == "remap"
        activate_env(REMAP_DIR)
        include(joinpath(REMAP_DIR, "remap.jl"))
        vars = haskey(valued, "vars") ? split(valued["vars"], ',') : nothing
        paths = call(:remap_command, rest; vars, name=get(valued, "name", nothing),
                     method=get(valued, "method", nothing), smooth=get(valued, "smooth", nothing),
                     overwrite="--overwrite" in opts)
        println("$(length(paths)) files written")
    elseif command == "record"
        activate_env(RECORDS_DIR)
        include(joinpath(RECORDS_DIR, "records.jl"))
        paths = call(:record_command, rest; overwrite="--overwrite" in opts)
        println("$(length(paths)) files written")
    elseif command == "figures"
        activate_env(FIGURES_DIR)
        include(joinpath(FIGURES_DIR, "figures.jl"))
        paths = call(:figures_command, rest)
        println("$(length(paths)) files written")
    elseif command == "docs"
        include(joinpath(PUBLISH_DIR, "site.jl"))
        paths = call(:write_site, joinpath(@__DIR__, "docs"))
        println("$(length(paths)) files written in docs/")
    elseif command == "stamp"
        isempty(rest) && usage("stamp: give a dataset")
        activate_env(PUBLISH_DIR)
        include(joinpath(PUBLISH_DIR, "release.jl"))
        call(:stamp, rest[1], rest[2:end])
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
    elseif command == "prune"
        include(joinpath(PUBLISH_DIR, "catalog.jl"))
        activate_env(PUBLISH_DIR)
        include(joinpath(PUBLISH_DIR, "prune.jl"))
        call(:prune, rest; yes="--yes" in opts, sandbox=sandbox)
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
