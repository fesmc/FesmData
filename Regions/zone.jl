# Zones of a domain: present-day land, continental shelf and open ocean, from the bed
# elevation and surface types of the topography product (see regions.toml, [zone]).

const ZONE_OCEAN = Int8(0)       # open ocean
const ZONE_BUFFER = Int8(1)      # open ocean within `buffer` of the shelf break
const ZONE_SHELF = Int8(2)       # continental shelf, including floating ice
const ZONE_LAND = Int8(3)        # present-day land: ice-free land and grounded ice

const ZONE_ATTRIB = Pair{String,Any}["flag_values" => Int8[0, 1, 2, 3],
    "flag_meanings" => "open_ocean shelf_break_buffer continental_shelf land"]

const DIST_ATTRIB = Pair{String,Any}["comment" =>
    "-Inf everywhere on a domain without open ocean (no ocean connected to depths below z_abyss within the domain)"]

read_zone_params(path=joinpath(@__DIR__, "regions.toml")) = TOML.parsefile(path)["zone"]

"""
    shelf_break_depth(codes, params) -> Matrix{Float64}

Shelf-break depth of each cell, from the region codes of the deepest level and the
depths given per region path in `params["z_break"]` (the most specific path wins).
"""
function shelf_break_depth(codes::AbstractMatrix{<:Integer}, params)
    zb = Dict(region_code(k) => Float64(v) for (k, v) in params["z_break"])
    lookup = Dict{Int,Float64}()
    function depth(c)
        get!(lookup, c) do
            for lev in region_level(c):-1:1
                a = region_ancestor(c, lev)
                haskey(zb, a) && return zb[a]
            end
            error("no shelf-break depth for region $(region_path(c))")
        end
    end
    return map(depth, codes)
end

"""
    build_zone(g, z_bed, mask, z_break, params) -> (zone, dist_shelfbreak, open_ocean)

Zones on grid `g` from the bed elevation `z_bed`, the surface type `mask` of the
topography product (0 ocean, 1 ice-free land, 2 grounded ice, 3 floating ice) and the
shelf-break depth of each cell. `dist_shelfbreak` (km) is the distance to the shelf
break, positive in the open ocean and negative on the shelf and land, and -Inf
everywhere if the domain has no open ocean (e.g. small mountain domains).
"""
function build_zone(g::ProjGrid, z_bed::AbstractMatrix, mask::AbstractMatrix, z_break::AbstractMatrix, params)
    dx, dy = spacing(g)
    r = Float64(params["r_open"])
    land = (mask .== 1) .| (mask .== 2)
    deep = (mask .== 0) .& (z_bed .< z_break)
    core = erode(deep, r, dx, dy)
    seeds = core .& (z_bed .< params["z_abyss"])
    open_ocean = dilate(flood_fill(core, seeds), r, dx, dy) .& deep
    dist = Float32.(distance_to(.!open_ocean, dx, dy) .- distance_to(open_ocean, dx, dy))
    zone = fill(ZONE_SHELF, size(g))
    zone[land] .= ZONE_LAND
    zone[open_ocean] .= ZONE_OCEAN
    zone[open_ocean .& (dist .<= params["buffer"])] .= ZONE_BUFFER
    return zone, dist, open_ocean
end
