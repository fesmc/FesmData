#
# Zones on the base grid of a domain: present-day land, continental shelf, open ocean
# (and its buffer along the shelf break), and the distance to the shelf break, from
# the topography product of the domain (see regions.toml, [zone]). Needs step 1.
#
# Usage:
#     julia --project=Regions -t 8 Regions/scripts/02_zone.jl DOMAIN
#
# Writes $FESMDATA_WORK/regions/<BASE>/<BASE>_zone.nc with zone and dist_shelfbreak.
#
include(joinpath(@__DIR__, "..", "common.jl"))

length(ARGS) == 1 || error("usage: 02_zone.jl DOMAIN")
dom = Domain(ARGS[1])
params = read_zone_params()
product = params["products"][dom.key]

gt, T = read_fields(product_file(dom.grids[1], product))
gr, R = read_fields(regions_work_file(dom, "regions"))
(gt.xc ≈ dom.base.xc && gr.xc ≈ dom.base.xc) || error("topography or regions not on the base grid $(dom.base.name)")

z_break = shelf_break_depth(R["region_3"], params)
zone, dist, _ = @time build_zone(dom.base, T["z_bed"], T["mask"], z_break, params)
for (k, name) in enumerate(split(ZONE_ATTRIB[2].second))
    @info "$(rpad(name, 22)) $(round(count(==(k - 1), zone) / length(zone) * 100; digits=1)) % of cells"
end

path = write_fields(regions_work_file(dom, "zone"), dom.base,
                    Dict("zone" => zone, "dist_shelfbreak" => dist); dataset=DATASET,
                    attrib=["title" => "Zones (FesmData/Regions, regions.toml)", "topography" => product],
                    varattrib=Dict("zone" => ZONE_ATTRIB, "dist_shelfbreak" => DIST_ATTRIB))
@info "wrote $path"
