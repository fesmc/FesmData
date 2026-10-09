# Publish the products of a dataset on a domain folder on Zenodo (see Publish/README.md).
#
#   julia --project=Publish Publish/scripts/zenodo.jl upload <Domain> <Dataset> [options]
#   julia --project=Publish Publish/scripts/zenodo.jl register <Domain> <Dataset> <record id> [options]
#
# `upload` puts the files and metadata into a draft of the next version of the record
# (a new record the first time); the draft is reviewed and published on the Zenodo
# website. `register` then writes the registry file of the published record.
#
# Options:
#   --sandbox           use the Zenodo sandbox (tests); registry in registry/_sandbox/
#   --allow-untagged    skip the release checks (files made at a release tag)
#   --dry-run           (upload) list the files and metadata only
#   --draft=<id>        (upload) continue an existing draft

include(joinpath(@__DIR__, "..", "zenodo.jl"))

opts = filter(startswith("--"), ARGS)
args = filter(!startswith("--"), ARGS)
known = ("--sandbox", "--allow-untagged", "--dry-run")
for o in opts
    o in known || startswith(o, "--draft=") || error("unknown option $o")
end
sandbox = "--sandbox" in opts
allow_untagged = "--allow-untagged" in opts
draft_opt = filter(startswith("--draft="), opts)
draft = isempty(draft_opt) ? nothing : parse(Int, split(only(draft_opt), "=")[2])

usage = "usage: zenodo.jl upload <Domain> <Dataset> | register <Domain> <Dataset> <record id>  [options]"
length(args) >= 3 || error(usage)
if args[1] == "upload" && length(args) == 3
    upload(args[2], args[3]; sandbox=sandbox, allow_untagged=allow_untagged, draft=draft,
           dry_run="--dry-run" in opts)
elseif args[1] == "register" && length(args) == 4
    register(args[2], args[3], parse(Int, args[4]); sandbox=sandbox, allow_untagged=allow_untagged)
else
    error(usage)
end
