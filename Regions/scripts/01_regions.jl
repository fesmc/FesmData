#
# Region codes on the base grid of a domain, from the region tree of regions.toml.
#
# Usage:
#     julia --project=Regions -t 8 Regions/scripts/01_regions.jl DOMAIN
#
# Writes $FESMDATA_WORK/regions/<BASE>/<BASE>_regions.nc with region_1, region_2 and
# region_3 (codes of the deepest region at or above each level, see regions.toml).
#
include(joinpath(@__DIR__, "..", "common.jl"))

length(ARGS) == 1 || error("usage: 01_regions.jl DOMAIN")
dom = Domain(ARGS[1])
defs = read_regions()
@info "regions on $(dom.base.name) $(size(dom.base))"

levels = @time build_regions(dom.base; defs)
fields = Dict("region_$n" => L for (n, L) in enumerate(levels))
varattrib = Dict("region_$n" => region_attrib(L, defs) for (n, L) in enumerate(levels))
path = write_fields(regions_work_file(dom, "regions"), dom.base, fields; dataset=DATASET,
                    attrib=["title" => "Region codes (FesmData/Regions, regions.toml)"], varattrib=varattrib)
@info "wrote $path"
