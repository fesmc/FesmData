# Basin sets of basins.toml on a grid.

"""
    BasinSet

A basin set of basins.toml.
"""
struct BasinSet
    name::String
    domains::Vector{String}
    region::String
    source::String
    id_field::String
    group_field::Union{Nothing,String}
end

function read_basin_sets(path=joinpath(@__DIR__, "basins.toml"))
    return [BasinSet(b["name"], b["domains"], b["region"], b["source"], b["id_field"],
                     get(b, "group_field", nothing))
            for b in TOML.parsefile(path)["basins"]]
end

"Basin sets of a domain."
basin_sets(dom::Domain) = filter(b -> dom.key in b.domains, read_basin_sets())

# Integer ids of attribute values: integers as they are, names numbered in
# alphabetical order. Returns the ids and their names.
function _ids(values)
    if all(v -> v isa Integer, values)
        ids = Int.(values)
        names = Dict(i => string(i) for i in ids)
    else
        names_sorted = sort(unique(string.(values)))
        num = Dict(n => k for (k, n) in enumerate(names_sorted))
        ids = [num[string(v)] for v in values]
        names = Dict(k => n for (n, k) in num)
    end
    return ids, names
end

_group_value(s::Shape, field) =
    field == "zwally_system" ? s.attrs["basin"] ÷ 10 : s.attrs[field]

"""
    build_basins(g, set, region_codes, zone) -> (fields, varattrib)

Basins of `set` on grid `g`: `basin` (extended up to the shelf break within the region
of the set), `basin_mask` (1 within the original basins) and, for sets with groups,
`basin_group`. `region_codes` is the deepest level of region codes on `g`.
"""
function build_basins(g::ProjGrid, set::BasinSet, region_codes::AbstractMatrix, zone::AbstractMatrix)
    dx, dy = spacing(g)
    shapes = filter(s -> !ismissing(s.attrs[set.id_field]), source_shapes(set.source))
    ids, names = _ids([s.attrs[set.id_field] for s in shapes])

    # Rasterize, the first basin of a cell wins
    B = zeros(Int32, size(g))
    m = zeros(Bool, size(g))
    for (s, id) in zip(shapes, ids)
        fill!(m, false)
        rasterize!(m, g, [s])
        B[m .& (B .== 0)] .= id
    end
    inregion = in_region(region_codes, region_code(set.region))
    B[.!inregion] .= 0
    basin_mask = Int8.(B .!= 0)

    # Extend over land and shelf within the region
    allowed = inregion .& ((zone .== ZONE_LAND) .| (zone .== ZONE_SHELF))
    B = extend_labels(B, allowed, dx, dy)
    @info "$(set.name): $(length(unique(B)) - 1) basins, $(count(basin_mask .== 1)) cells in basins, $(count(B .!= 0)) after extension"

    present = sort(filter(!=(0), unique(B)))
    fields = Dict{String,Any}("basin" => B, "basin_mask" => basin_mask)
    varattrib = Dict{String,Vector{Pair{String,Any}}}(
        "basin" => region_flag_attrib(present, [names[i] for i in present]))

    if set.group_field !== nothing
        gids, gnames = _ids([_group_value(s, set.group_field) for s in shapes])
        group_of = Dict(zip(ids, gids))
        G = Int32[b == 0 ? 0 : group_of[b] for b in B]
        gpresent = sort(filter(!=(0), unique(G)))
        fields["basin_group"] = G
        varattrib["basin_group"] = region_flag_attrib(gpresent, [gnames[i] for i in gpresent])
    end
    return fields, varattrib
end
