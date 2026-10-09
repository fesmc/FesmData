#
# Basin sets of a domain on its base grid (see basins.toml). Needs steps 1 and 2.
#
# Usage:
#     julia --project=Regions -t 8 Regions/scripts/03_basins.jl DOMAIN [SET]
#
# Writes $FESMDATA_WORK/regions/<BASE>/<BASE>_basins-<SET>.nc with basin, basin_mask
# and, for sets with groups, basin_group.
#
include(joinpath(@__DIR__, "..", "common.jl"))

1 <= length(ARGS) <= 2 || error("usage: 03_basins.jl DOMAIN [SET]")
dom = Domain(ARGS[1])
sets = basin_sets(dom)
if length(ARGS) == 2
    sets = filter(b -> b.name == ARGS[2], sets)
    isempty(sets) && error("no basin set $(ARGS[2]) for domain $(dom.key)")
end
isempty(sets) && @info "$(dom.key) has no basin sets"

_, R = read_fields(regions_work_file(dom, "regions"))
_, Z = read_fields(regions_work_file(dom, "zone"))
codes = R["region_$(length(filter(startswith("region_"), keys(R))))"]

for set in sets
    fields, varattrib = @time build_basins(dom.base, set, codes, Z["zone"])
    path = write_fields(regions_work_file(dom, "basins-$(set.name)"), dom.base, fields; dataset=DATASET,
                        attrib=["title" => "Basins $(set.name) (FesmData/Regions, basins.toml)",
                                "basin_source" => set.source],
                        varattrib=varattrib)
    @info "wrote $path"
end
