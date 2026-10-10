# Basin sets of basins.toml on a grid (the sets are read in files.jl).

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
    build_basins(g, set, region_codes, zone; grounded=nothing) -> (fields, varattrib)

Basins of `set` on grid `g`: `basin` (extended up to the shelf break within the region
of the set), `basin_mask` (1 within the original basins) and, for sets with groups,
`basin_group`. `region_codes` is the deepest level of region codes on `g`. The NEGIS
sets (`is_negis_source`, see negis.jl) are not extended, and `negis` needs the grounded
ice of the topography (`grounded`).
"""
function build_basins(g::ProjGrid, set::BasinSet, region_codes::AbstractMatrix, zone::AbstractMatrix;
                      grounded=nothing)
    is_negis_source(set.source) && return _negis_fields(g, set, region_codes, grounded)
    dx, dy = spacing(g)
    values, groups, add_cells! = _basin_features(g, set)
    ids, names = _ids(values)

    # Rasterize, the first basin of a cell wins
    B = zeros(Int32, size(g))
    m = zeros(Bool, size(g))
    for (k, id) in enumerate(ids)
        fill!(m, false)
        add_cells!(m, k)
        B[m .& (B .== 0)] .= id
    end
    inregion = in_region(region_codes, region_code(set.region))
    B[.!inregion] .= 0
    basin_mask = Int8.(B .!= 0)

    # Extend over land and shelf within the region, except from the basins in
    # no_extension, which keep their extent and block the extension of the others
    fixed = Set(id for (v, id) in zip(values, ids) if string(v) in set.no_extension)
    isfixed = map(in(fixed), B)
    allowed = inregion .& ((zone .== ZONE_LAND) .| (zone .== ZONE_SHELF)) .& .!isfixed
    E = extend_labels(ifelse.(isfixed, Int32(0), B), allowed, dx, dy)
    B = ifelse.(isfixed, B, E)
    @info "$(set.name): $(length(unique(B)) - 1) basins, $(count(basin_mask .== 1)) cells in basins, $(count(B .!= 0)) after extension"

    present = sort(filter(!=(0), unique(B)))
    fields = Dict{String,Any}("basin" => B, "basin_mask" => basin_mask)
    varattrib = Dict{String,Vector{Pair{String,Any}}}(
        "basin" => region_flag_attrib(present, [names[i] for i in present]))

    if groups !== nothing
        gids, gnames = _ids(groups)
        group_of = Dict(zip(ids, gids))
        G = Int32[b == 0 ? 0 : group_of[b] for b in B]
        gpresent = sort(filter(!=(0), unique(G)))
        fields["basin_group"] = G
        varattrib["basin_group"] = region_flag_attrib(gpresent, [gnames[i] for i in gpresent])
    end
    return fields, varattrib
end

# Parts of a NEGIS set within its region, not extended (basin_mask = basin != 0)
function _negis_fields(g::ProjGrid, set::BasinSet, region_codes::AbstractMatrix, grounded)
    B = negis_basins(g, set, grounded)
    B[.!in_region(region_codes, region_code(set.region))] .= 0
    present = sort(filter(!=(0), unique(B)))
    @info "$(set.name): cells by part $([count(==(k), B) for k in 1:length(NEGIS_PARTS)])"
    return Dict{String,Any}("basin" => B, "basin_mask" => Int8.(B .!= 0)),
           Dict{String,Vector{Pair{String,Any}}}("basin" => vcat(Pair{String,Any}["long_name" => NEGIS_LONG_NAME],
                                                                  region_flag_attrib(present, NEGIS_PARTS[present])))
end

# Features of a basin set (only those in `features`, if given): their values of
# id_field and of group_field (nothing without groups), and a function adding the
# cells of feature k to a mask on grid `g`.
function _basin_features(g::ProjGrid, set::BasinSet)
    if is_glacier_source(set.source)
        set.group_field === nothing || error("$(set.name): glacier basins have no groups")
        isempty(set.features) && error("$(set.name): glacier basins need `features` (RGI ids)")
        values = set.features
        return values, nothing, (m, k) -> (m .|= glacier_mask(g, set.source, values[k]))
    end
    shapes = filter(s -> !ismissing(s.attrs[set.id_field]), source_shapes(set.source))
    isempty(set.features) || filter!(s -> string(s.attrs[set.id_field]) in set.features, shapes)
    values = [s.attrs[set.id_field] for s in shapes]
    groups = set.group_field === nothing ? nothing : [_group_value(s, set.group_field) for s in shapes]
    return values, groups, (m, k) -> rasterize!(m, g, [shapes[k]])
end
