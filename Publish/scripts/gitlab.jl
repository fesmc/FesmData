# Release the products of a dataset on the store, the package registry of the GitLab
# project (see Publish/README.md): one package per domain, dataset and grid.
#
#   julia --project=Publish Publish/scripts/gitlab.jl upload <Dataset> [<Domain> ...] [options]
#   julia --project=Publish Publish/scripts/gitlab.jl status <Dataset> [<Domain> ...] [options]
#   julia --project=Publish Publish/scripts/gitlab.jl delete <Dataset> <version> [<Domain> ...] [options]
#
# Without domains: all domains with files of the dataset (upload), all domains (status,
# delete).
#
# `upload` uploads the files of each grid to its package, versioned by the release
# (e.g. 2.0.0), and writes the registry file of each domain; running it again
# continues an interrupted upload. `status` shows where each domain is. `delete`
# removes the packages of a version (e.g. a test), after one confirmation.
#
# Options:
#   --sandbox           test release: packages test_<Domain>_<Dataset>_<GRID>, registry
#                       in registry/_sandbox/
#   --allow-untagged    skip the release checks (files made at a release tag)
#   --dry-run           (upload) check and list the packages and files only

include(joinpath(@__DIR__, "..", "gitlab.jl"))

opts = filter(startswith("--"), ARGS)
args = filter(!startswith("--"), ARGS)
for o in opts
    o in ("--sandbox", "--allow-untagged", "--dry-run") || error("unknown option $o")
end
sandbox = "--sandbox" in opts

usage = "usage: gitlab.jl upload|status <Dataset> [<Domain> ...]  |  gitlab.jl delete <Dataset> <version> [<Domain> ...]  [options]"
length(args) >= 2 || error(usage)
command, dataset = args[1], args[2]
if command == "upload"
    upload(dataset, args[3:end]; sandbox=sandbox, allow_untagged="--allow-untagged" in opts,
           dry_run="--dry-run" in opts)
elseif command == "status"
    status(dataset, args[3:end]; sandbox=sandbox)
elseif command == "delete" && length(args) >= 3
    delete_release(dataset, args[3], args[4:end]; sandbox=sandbox)
else
    error(usage)
end
