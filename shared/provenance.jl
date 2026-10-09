# Repository paths, machine environment and the provenance attributes written to every
# NetCDF file produced by FesmData. No package dependencies, so that Publish can use it.

using Dates

const REPO_DIR = dirname(@__DIR__)
const REPO_URL = "https://github.com/fesmc/FesmData"

function _env(name)
    haskey(ENV, name) || error("environment variable $name is not set (source shared/machines/<machine>.env)")
    return ENV[name]
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
    script = isempty(PROGRAM_FILE) ? "interactive" : abspath(PROGRAM_FILE)
    startswith(script, REPO_DIR * "/") && (script = relpath(script, REPO_DIR))
    time = Dates.format(now(), dateformat"yyyy-mm-ddTHH:MM:SS")
    return ["source" => "FesmData, $REPO_URL",
            "fesmdata_version" => git_version(dataset),
            "fesmdata_commit" => git_commit(),
            "history" => "$time: " * join([script; ARGS], " ")]
end
