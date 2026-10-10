#
# Regions, zones and basins of a domain on all its grids (coarser grids and crops),
# from the base grid (steps 1-3). Region codes, zones and basins are the class covering
# most of each cell (region codes nested level by level, basins in their group),
# dist_shelfbreak the cell mean.
#
# Usage:
#     julia --project=Regions -t 8 Regions/scripts/04_grids.jl DOMAIN [SET]
#
# Writes $ICE_DATA/v2/<folder>/<GRID>/<GRID>_REGIONS.nc (region_1-3, zone,
# dist_shelfbreak) and <GRID>_BASINS-<SET>.nc for each basin set of the domain, or only
# the files of basin set SET.
#
include(joinpath(@__DIR__, "..", "common.jl"))

1 <= length(ARGS) <= 2 || error("usage: 04_grids.jl DOMAIN [SET]")
dom = Domain(ARGS[1])
only_set = length(ARGS) == 2 ? ARGS[2] : nothing
sets = filter(set -> only_set === nothing || set.name == only_set, basin_sets(dom))
isempty(sets) && only_set !== nothing && error("no basin set $only_set for domain $(dom.key)")
defs = read_regions()

_, R = read_fields(regions_work_file(dom, "regions"))
_, Z = read_fields(regions_work_file(dom, "zone"))
# Original datasets (datamanifest.toml) of the regions and of the topography of the zones
topography = NCDataset(ds -> ds.attrib["topography"], regions_work_file(dom, "zone"))
region_keys = vcat(manifest_keys.(region_sources(defs))..., product_sources(dom)[topography])
nlev = count(startswith("region_"), keys(R))
basins = Dict{String,Any}()
for set in sets
    path = regions_work_file(dom, "basins-$(set.name)")
    basins[set.name] = (set, read_fields(path)[2], Dict(k => read_flags(path, k) for k in ("basin", "basin_group")))
end

# Region codes, zone and distance to the shelf break on grid og (map m from the base grid)
function write_regions(og, m)
    g = og.grid
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
    attrib["dist_shelfbreak"] = DIST_ATTRIB
    write_fields(regions_file(og), g, fields; dataset=DATASET,
                 attrib=["title" => "Regions v2 (FesmData/Regions)", "base_grid" => dom.base.name,
                         "sources" => join(sort(unique(region_keys)), ", ")],
                 varattrib=attrib)
end

for og in dom.grids
    g = og.grid
    m = AlignedMap(g, dom.base)
    only_set === nothing && write_regions(og, m)

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
        keys_set = manifest_keys(set.source)
        set.source == "negis" && append!(keys_set, product_sources(dom)[topography])
        battrib = ["title" => "Basins $name (FesmData/Regions)", "basin_source" => set.source,
                   "sources" => join(unique(keys_set), ", "), "base_grid" => dom.base.name]
        if is_negis_source(set.source)
            push!(battrib, "comment" => negis_comment(set))
            ba["basin"] = vcat(Pair{String,Any}["long_name" => NEGIS_LONG_NAME], ba["basin"])
        end
        write_fields(basins_file(og, set), g, bf; dataset=DATASET, attrib=battrib, varattrib=ba)
    end
    @info "wrote $(g.name)"
end
