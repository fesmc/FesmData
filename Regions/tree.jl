# The region tree of regions.toml, evaluated on a grid.

using TOML

"""
    RegionDef

A region of regions.toml: its path ("1.3.1"), code (10301), level, name, rules,
and whether cells not covered by its subregions get the nearest subregion (`fill`).
"""
struct RegionDef
    path::String
    code::Int
    level::Int
    name::String
    rules::Vector{Dict{String,Any}}
    fill::Bool
end

parent_path(r::RegionDef) = r.level == 1 ? "" : join(split(r.path, '.')[1:end-1], '.')

"Regions of regions.toml, in the order of the file."
function read_regions(path=joinpath(@__DIR__, "regions.toml"))
    defs = RegionDef[]
    for r in TOML.parsefile(path)["region"]
        code = region_code(r["path"])
        push!(defs, RegionDef(r["path"], code, region_level(code), r["name"],
                              Vector{Dict{String,Any}}(r["rules"]), get(r, "fill", false)))
    end
    paths = Set(d.path for d in defs)
    length(paths) == length(defs) || error("duplicate region paths in $path")
    for d in defs
        d.level == 1 || parent_path(d) in paths || error("region $(d.path) has no parent region")
    end
    return defs
end

"Region and basin sources used by the rules of the regions (see sources.jl)."
function region_sources(defs)
    sources = Set{String}()
    add!(rule) = (push!(sources, rule["source"]);
                  foreach(add!, vcat(get(rule, "within", []), get(rule, "without", []))))
    foreach(d -> foreach(add!, d.rules), defs)
    return sort(collect(sources))
end

"""
    RuleContext(g)

Grid `g` with the lon/lat of its cells, for evaluating rules.
"""
struct RuleContext
    g::ProjGrid
    lon::Matrix{Float64}
    lat::Matrix{Float64}
end
RuleContext(g::ProjGrid) = RuleContext(g, lonlat(g)...)

"""
    rule_mask(ctx, rule) -> BitMatrix

Cells of the grid covered by a rule of regions.toml (see its header).
"""
function rule_mask(ctx::RuleContext, rule::AbstractDict)
    g = ctx.g
    src = rule["source"]
    if src == "box"
        lon = get(rule, "lon", [-180, 180])
        lat = get(rule, "lat", [-90, 90])
        m = BitMatrix((lon[1] .<= ctx.lon .<= lon[2]) .& (lat[1] .<= ctx.lat .<= lat[2]))
    else
        level = get(rule, "level", 0)
        shapes = filter(s -> _matches(s, rule), source_shapes(src; level=level))
        isempty(shapes) && @warn "rule matches no features" rule
        m = rasterize(g, shapes)
    end
    get(rule, "fill_holes", false) && (m = fill_holes(m))
    if haskey(rule, "within")
        m .&= reduce(.|, (rule_mask(ctx, r) for r in rule["within"]))
    end
    if haskey(rule, "without")
        m .&= .!reduce(.|, (rule_mask(ctx, r) for r in rule["without"]))
    end
    return m
end

# Feature selection: by `values` of `field`; for hydrobasins, PFAF_ID values or
# their prefixes (a basin of a coarser level).
function _matches(s::Shape, rule)
    if rule["source"] == "hydrobasins"
        id = string(s.attrs["PFAF_ID"])
        return any(v -> startswith(id, string(v)), rule["values"])
    end
    v = s.attrs[rule["field"]]
    return !ismissing(v) && v in rule["values"]
end

"Mask with the areas it encloses (not connected to the grid edge) filled in."
function fill_holes(m::AbstractMatrix{Bool})
    edge = falses(size(m))
    edge[[1, end], :] .= true
    edge[:, [1, end]] .= true
    return m .| .!flood_fill(.!m, edge)
end

"""
    build_regions(g; defs=read_regions()) -> Vector{Matrix{Int32}}

Region codes of each level on grid `g`: element `n` holds, for each cell, the code
of the deepest region at or above level `n` that covers it.
"""
function build_regions(g::ProjGrid; defs=read_regions())
    ctx = RuleContext(g)
    dx, dy = spacing(g)
    nlev = maximum(d.level for d in defs)
    levels = Matrix{Int32}[]
    prev = zeros(Int32, size(g))
    for n in 1:nlev
        L = copy(prev)
        parents = n == 1 ? [nothing] : filter(d -> d.level == n - 1, defs)
        for p in parents
            inparent = p === nothing ? trues(size(g)) : prev .== p.code
            any(inparent) || continue
            children = filter(d -> d.level == n && parent_path(d) == (p === nothing ? "" : p.path), defs)
            free = copy(inparent)
            for c in children
                m = rule_mask(ctx, c.rules[1])
                for r in c.rules[2:end]
                    m .|= rule_mask(ctx, r)
                end
                m .&= free
                L[m] .= c.code
                free .&= .!m
                @info "$(rpad(c.path, 7)) $(rpad(c.name, 42)) $(count(m)) cells"
            end
            if p !== nothing && p.fill && any(free) && !isempty(children)
                seeds = Matrix{Int32}(ifelse.(inparent .& .!free, L, Int32(0)))
                E = extend_labels(seeds, free, dx, dy)
                filled = free .& (E .!= 0)
                L[filled] .= E[filled]
                @info "$(rpad(p.path, 7)) $(count(filled)) cells filled with the nearest subregion, $(count(free .& .!filled)) unreached"
            end
        end
        push!(levels, L)
        prev = L
    end
    return levels
end

"Flag attributes (codes and names) of the regions that occur in a field of codes."
function region_attrib(L::AbstractMatrix{<:Integer}, defs)
    present = Set(L)
    ds = filter(d -> d.code in present, defs)
    sort!(ds; by=d -> d.code)
    return region_flag_attrib([d.code for d in ds], [d.name for d in ds])
end
