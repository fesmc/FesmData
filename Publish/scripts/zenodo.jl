# Archive releases of a dataset on Zenodo, optional, for a DOI: one record per domain
# (see Publish/README.md). The release must be on the store first (gitlab.jl upload).
#
#   julia --project=Publish Publish/scripts/zenodo.jl upload   <Dataset> [<Domain> ...] [options]
#   julia --project=Publish Publish/scripts/zenodo.jl status   <Dataset> [<Domain> ...] [options]
#   julia --project=Publish Publish/scripts/zenodo.jl publish  <Dataset> [<Domain> ...] [options]
#   julia --project=Publish Publish/scripts/zenodo.jl register <Dataset> [<Domain> ...] [options]
#   julia --project=Publish Publish/scripts/zenodo.jl discard  <Dataset> [<Domain> ...] [options]
#   julia --project=Publish Publish/scripts/zenodo.jl discard  <draft id> ... [options]
#   julia --project=Publish Publish/scripts/zenodo.jl drafts [options]
#
# Without domains: all domains with files of the dataset (upload), all domains (status),
# all domains with a draft (publish, register, discard).
#
# `upload` puts the files and metadata of each domain into a draft of the next version
# of its record (a new record the first time); running it again continues the drafts.
# `publish` checks the drafts, publishes them after one confirmation, and registers
# them (adds their DOIs to the registry files). `register` does the latter for drafts
# published on the Zenodo website. `status` shows where each domain is. `discard` deletes
# unpublished drafts, of a dataset or by id; `drafts` lists all unpublished drafts of
# the account.
#
# Options:
#   --sandbox           use the Zenodo sandbox, for test releases (registry/_sandbox/)
#   --allow-untagged    skip the release checks (files made at a release tag)
#   --dry-run           (upload) check and list the files only
#   --yes               (publish) do not ask for confirmation

include(joinpath(@__DIR__, "..", "zenodo.jl"))

opts = filter(startswith("--"), ARGS)
args = filter(!startswith("--"), ARGS)
for o in opts
    o in ("--sandbox", "--allow-untagged", "--dry-run", "--yes") || error("unknown option $o")
end
sandbox = "--sandbox" in opts
allow_untagged = "--allow-untagged" in opts

usage = """usage: zenodo.jl upload|status|publish|register|discard <Dataset> [<Domain> ...] [options]
                  zenodo.jl discard <draft id> ...  |  zenodo.jl drafts"""
isempty(args) && error(usage)
command = args[1]
if command == "drafts"
    list_drafts(; sandbox=sandbox)
elseif command == "discard" && length(args) >= 2 && all(a -> all(isdigit, a), args[2:end])
    discard_drafts(parse.(Int, args[2:end]); sandbox=sandbox)
else
    length(args) >= 2 || error(usage)
    dataset, domains = args[2], args[3:end]
    if command == "upload"
        upload(dataset, domains; sandbox=sandbox, allow_untagged=allow_untagged, dry_run="--dry-run" in opts)
    elseif command == "status"
        status(dataset, domains; sandbox=sandbox)
    elseif command == "publish"
        publish(dataset, domains; sandbox=sandbox, allow_untagged=allow_untagged, yes="--yes" in opts)
    elseif command == "register"
        register(dataset, domains; sandbox=sandbox, allow_untagged=allow_untagged)
    elseif command == "discard"
        discard(dataset, domains; sandbox=sandbox)
    else
        error(usage)
    end
end
