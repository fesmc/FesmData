# Publish the products of a dataset on Zenodo, one record per domain (see
# Publish/README.md).
#
#   julia --project=Publish Publish/scripts/zenodo.jl upload   <Dataset> [<Domain> ...] [options]
#   julia --project=Publish Publish/scripts/zenodo.jl status   <Dataset> [<Domain> ...] [options]
#   julia --project=Publish Publish/scripts/zenodo.jl register <Dataset> [<Domain> ...] [options]
#
# Without domains: all domains with files of the dataset (upload), all domains (status),
# all domains with a draft (register).
#
# `upload` puts the files and metadata of each domain into a draft of the next version
# of its record (a new record the first time); running it again continues the drafts.
# The drafts are reviewed and published on the Zenodo website. `register` then writes
# the registry file of each published record. `status` shows where each domain is.
#
# Options:
#   --sandbox           use the Zenodo sandbox (tests); registry in registry/_sandbox/
#   --allow-untagged    skip the release checks (files made at a release tag)
#   --dry-run           (upload) check and list the files only

include(joinpath(@__DIR__, "..", "zenodo.jl"))

opts = filter(startswith("--"), ARGS)
args = filter(!startswith("--"), ARGS)
for o in opts
    o in ("--sandbox", "--allow-untagged", "--dry-run") || error("unknown option $o")
end
sandbox = "--sandbox" in opts
allow_untagged = "--allow-untagged" in opts

usage = "usage: zenodo.jl upload|status|register <Dataset> [<Domain> ...] [--sandbox] [--allow-untagged] [--dry-run]"
length(args) >= 2 || error(usage)
command, dataset, domains = args[1], args[2], args[3:end]
if command == "upload"
    upload(dataset, domains; sandbox=sandbox, allow_untagged=allow_untagged, dry_run="--dry-run" in opts)
elseif command == "status"
    status(dataset, domains; sandbox=sandbox)
elseif command == "register"
    register(dataset, domains; sandbox=sandbox, allow_untagged=allow_untagged)
else
    error(usage)
end
