#
# Regions, zones and basins of a domain on all its grids (coarser grids and crops),
# from the base grid (steps 1-3). Region codes, zones and basins are the class covering
# most of each cell (region codes nested level by level, basins in their group),
# dist_shelfbreak the cell mean.
#
# Usage:
#     julia --project=Regions -t 8 Regions/scripts/04_grids.jl DOMAIN
#
# Writes $ICE_DATA/v2/<folder>/<GRID>/<GRID>_REGIONS.nc (region_1-3, zone,
# dist_shelfbreak) and <GRID>_BASINS-<SET>.nc for each basin set of the domain.
#
include(joinpath(@__DIR__, "..", "common.jl"))

length(ARGS) == 1 || error("usage: 04_grids.jl DOMAIN")
dom = Domain(ARGS[1])
defs = read_regions()

_, R = read_fields(regions_work_file(dom, "regions"))
_, Z = read_fields(regions_work_file(dom, "zone"))
nlev = count(startswith("region_"), keys(R))
basins = Dict{String,Any}()
for set in basin_sets(dom)
    path = regions_work_file(dom, "basins-$(set.name)")
    basins[set.name] = (set, read_fields(path)[2], Dict(k => read_flags(path, k) for k in ("basin", "basin_group")))
end

for og in dom.grids
    g = og.grid
    m = AlignedMap(g, dom.base)
    fields = Dict{String,Any}()
    attrib = Dict{String,Vector{Pair{String,Any}}}()
    prev = nothing
    for n in 1:nlev
        k = "region_$n"
        L = n == 1 ? remap_dominant(m, R[k]) : remap_dominant(m, R[k]; parent=(prev, R["region_$(n-1)"]))
        fields[k] = Int32.(L)
        attrib[k] = region_attrib(L, defs)
        prev = L
    end
    fields["zone"] = Int8.(remap_dominant(m, Z["zone"]))
    attrib["zone"] = ZONE_ATTRIB
    fields["dist_shelfbreak"] = remap(m, Z["dist_shelfbreak"])[1]
    write_fields(regions_file(og), g, fields; dataset=DATASET,
                 attrib=["title" => "Regions v2 (FesmData/Regions)", "base_grid" => dom.base.name],
                 varattrib=attrib)

    for (name, (set, B, flags)) in basins
        bf = Dict{String,Any}()
        if haskey(B, "basin_group")
            Gt = remap_dominant(m, B["basin_group"])
            bf["basin_group"] = Int32.(Gt)
            bf["basin"] = Int32.(remap_dominant(m, B["basin"]; parent=(Gt, B["basin_group"])))
        else
            bf["basin"] = Int32.(remap_dominant(m, B["basin"]))
        end
        bf["basin_mask"] = Int8.(remap_dominant(m, B["basin_mask"]))
        ba = Dict(k => flag_attrib(flags[k], bf[k]) for k in keys(flags) if haskey(bf, k))
        write_fields(basins_file(og, set), g, bf; dataset=DATASET,
                     attrib=["title" => "Basins $name (FesmData/Regions)", "basin_source" => set.source,
                             "base_grid" => dom.base.name],
                     varattrib=ba)
    end
    @info "wrote $(g.name)"
end
