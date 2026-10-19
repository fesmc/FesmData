# Repository paths, machine environment, the preparation of sources and the provenance
# attributes written to every NetCDF file produced by FesmData. No package dependencies,
# so that Publish can use it.

using Dates
using TOML

const REPO_DIR = dirname(@__DIR__)
const REPO_URL = "https://github.com/fesmc/FesmData"

"Folder of the records (non-gridded data) under the products folder, next to the domain folders."
const RECORDS_FOLDER = "Records"

function _env(name)
    haskey(ENV, name) || error("environment variable $name is not set (source shared/machines/<machine>.env)")
    return ENV[name]
end

"Storage folders of FesmData (see `fesmdata_dir`)."
const STORAGE_FOLDERS = ("sources", "prepared", "products", "work")

"""
    fesmdata_dir(kind) -> String

Storage folder `kind` of FesmData: `products` (the products and records, as released),
`sources` (the original datasets, `\$datasets_dir` of datamanifest.toml), `prepared`
(the prepared sources, input of remapping and records) or `work` (intermediate files).
The products are `\$FESMDATA` itself; the others are `\$FESMDATA_<KIND>` if set (e.g.
`FESMDATA_WORK` on a scratch file system), else the sibling folder `\$FESMDATA-<kind>`.
"""
function fesmdata_dir(kind::AbstractString)
    kind in STORAGE_FOLDERS || error("unknown storage folder $kind, available: $(join(STORAGE_FOLDERS, ", "))")
    kind == "products" && return _env("FESMDATA")
    var = "FESMDATA_" * uppercase(kind)
    haskey(ENV, var) && return ENV[var]
    haskey(ENV, "FESMDATA") && return rstrip(ENV["FESMDATA"], '/') * "-" * kind
    error("neither $var nor FESMDATA is set (source shared/machines/<machine>.env)")
end

"Whether storage folder `kind` is set (`FESMDATA`, or `FESMDATA_<KIND>` for the others, see `fesmdata_dir`)."
has_fesmdata_dir(kind::AbstractString) = haskey(ENV, "FESMDATA") || (kind != "products" && haskey(ENV, "FESMDATA_" * uppercase(kind)))

"Datasets released by Publish, with their release tags (Publish/datasets.toml)."
read_datasets() = TOML.parsefile(joinpath(REPO_DIR, "Publish", "datasets.toml"))

"Release tag of a dataset (provenance attributes, tags <tag>-vX.Y.Z), from Publish/datasets.toml."
function dataset_tag(dataset::AbstractString)
    all = read_datasets()
    haskey(all, dataset) || error("add $dataset to Publish/datasets.toml (tag, title, readme, keywords, description)")
    return all[dataset]["tag"]
end

"Path of the definition of a thematic dataset (made by remapping, see ../Remap)."
remap_spec_file(dataset::AbstractString) = joinpath(REPO_DIR, dataset, "remap.toml")

"""
    is_remap_dataset(dataset)

Whether `dataset` is a thematic dataset made by remapping (e.g. GHF), rather than by a
pipeline of its own from the sources on every domain (Topo, Regions) or a records
dataset.
"""
is_remap_dataset(dataset::AbstractString) = isfile(remap_spec_file(dataset))

"""
    figure_spec(value, what) -> Union{Nothing,Dict{String,Any}}

The `figure` entry of a product (remap.toml, records.toml): its options (a table, empty
by default), or `nothing` for `figure = false`, a product without a figure on the
website (see ../Figures).
"""
function figure_spec(value, what::AbstractString)
    value === false && return nothing
    value isa AbstractDict || error("$what: figure must be a table of options or false")
    return Dict{String,Any}(value)
end

"Folder of the prepared files of a source (input to remapping or records): <prepared>/<source> (see `fesmdata_dir`)."
prepared_dir(source::AbstractString) = joinpath(fesmdata_dir("prepared"), source)

"""
    run_prepare(source)

Run the preparation of a source, `<source>/prepare.jl` in its own environment (with its
packages installed if needed).
"""
function run_prepare(source::AbstractString)
    dir = joinpath(REPO_DIR, source)
    script = joinpath(dir, "prepare.jl")
    isfile(script) || error("no $script to prepare $source")
    println("Preparing $source: julia --project=$source $source/prepare.jl")
    run(`$(Base.julia_cmd()) --project=$dir -e "import Pkg; Pkg.instantiate()"`)
    run(`$(Base.julia_cmd()) --project=$dir $script`)
end

"""
    git_version(dataset) -> String

Version of the repository for a dataset, from `git describe` against its release tags
`<dataset>-v*`: "topo-v2.0.0" at a release, "topo-v2.0.0-3-gabc1234" after it, with
"-dirty" for uncommitted changes, or the abbreviated commit before the first release.
"unknown" outside a git checkout.
"""
git_version(dataset::AbstractString) =
    _git("describe", "--tags", "--match", "$(dataset)-v*", "--dirty", "--always")

"Commit of the repository (\"unknown\" outside a git checkout)."
git_commit() = _git("rev-parse", "HEAD")

function _git(args...)
    try
        return readchomp(pipeline(`git -C $REPO_DIR $args`; stderr=devnull))
    catch
        return "unknown"
    end
end

"Global attributes set by FesmData on every NetCDF file it writes."
const PROVENANCE_KEYS = ("source", "fesmdata_version", "fesmdata_commit", "history")

"""
    provenance_attrib(dataset) -> Vector{Pair{String,String}}

Global attributes recording how a file of a dataset (e.g. "topo") was made: the
repository, its version and commit, and the script with its arguments and the time.
"""
function provenance_attrib(dataset::AbstractString)
    return ["source" => "FesmData, $REPO_URL",
            "fesmdata_version" => git_version(dataset),
            "fesmdata_commit" => git_commit(),
            "history" => history_entry()]
end

"Entry of this run in the `history` attribute: the time, and the script with its arguments."
function history_entry()
    script = isempty(PROGRAM_FILE) ? "interactive" : abspath(PROGRAM_FILE)
    startswith(script, REPO_DIR * "/") && (script = relpath(script, REPO_DIR))
    time = Dates.format(now(), dateformat"yyyy-mm-ddTHH:MM:SS")
    return "$time: " * join([script; ARGS], " ")
end
