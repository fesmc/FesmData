# Sources of the region and basin polygons (entries of datamanifest.toml), read as
# `Shape`s in lon/lat. Each source is read once per run.

using DelimitedFiles

const HYDROBASINS_REGIONS = ("na", "ar", "gr", "eu", "si", "as")

const _SHAPES = Dict{Tuple{String,Int},Vector{Shape}}()

"""
    source_shapes(source; level=0) -> Vector{Shape}

The polygons of a region or basin source:

- `eez_land`: union of countries and EEZs (Marine Regions), with the attributes
  `m49_region` and `m49_subregion` of each territory (UN M49, from `iso3166_m49`)
- `iho`: IHO Sea Areas v3; `goas`: Global Oceans and Seas v1
- `hydrobasins`: HydroBASINS basins of Pfafstetter level `level`, all regions of
  the NH domain, with `PFAF_ID` as an integer
- `imbie`, `imbie_refined`: IMBIE 2016 and refined Antarctic basins (NSIDC-0709)
- `mouginot2019`: Greenland basins of Mouginot & Rignot (2019)
- `zwally2012_antarctica`, `zwally2012_greenland`: GSFC drainage systems, with the
  attribute `basin` (see `read_zwally`)
"""
function source_shapes(source::AbstractString; level::Integer=0)
    return get!(_SHAPES, (String(source), Int(level))) do
        @info "reading $source" * (level > 0 ? " (level $level)" : "")
        _read_source(source, level)
    end
end

"""
    manifest_keys(source) -> Vector{String}

Entries of datamanifest.toml that a region or basin source is read from (none for
"box").
"""
function manifest_keys(source::AbstractString)
    source == "box" && return String[]
    is_glacier_source(source) && return [String(source)]
    source == "eez_land" && return ["marineregions_eez_land_v4", "iso3166_m49"]
    source == "iho" && return ["marineregions_iho_v3"]
    source == "goas" && return ["marineregions_goas_v1"]
    source == "hydrobasins" && return ["hydrobasins_v1c_$r" for r in HYDROBASINS_REGIONS]
    source in ("imbie", "imbie_refined") && return ["nsidc0709_v2_basins"]
    source == "mouginot2019" && return ["mouginot2019_greenland_basins"]
    source in ("zwally2012_antarctica", "zwally2012_greenland") && return [String(source)]
    error("unknown source $source")
end

function _read_source(source, level)
    db = manifest()
    path(key) = get_dataset_path(db, key)
    if source == "eez_land"
        return _with_m49(read_shapes(_only_shp(path("marineregions_eez_land_v4"))), path("iso3166_m49"))
    elseif source == "iho"
        return read_shapes(_only_shp(path("marineregions_iho_v3")))
    elseif source == "goas"
        return read_shapes(_only_shp(path("marineregions_goas_v1")))
    elseif source == "hydrobasins"
        1 <= level <= 12 || error("hydrobasins needs a level in 1..12")
        shapes = Shape[]
        for r in HYDROBASINS_REGIONS
            f = joinpath(path("hydrobasins_v1c_$r"), "hybas_$(r)_lev$(lpad(level, 2, '0'))_v1c.shp")
            for s in read_shapes(f)
                s.attrs["PFAF_ID"] = Int(s.attrs["PFAF_ID"])
                push!(shapes, s)
            end
        end
        return shapes
    elseif source == "imbie"
        return read_shapes(joinpath(path("nsidc0709_v2_basins"), "Basins_IMBIE_Antarctica_v02.shp"))
    elseif source == "imbie_refined"
        return read_shapes(joinpath(path("nsidc0709_v2_basins"), "Basins_Antarctica_v02.shp"))
    elseif source == "mouginot2019"
        return read_shapes(joinpath(path("mouginot2019_greenland_basins"), "Greenland_Basins_PS_v1.4.2.shp"))
    elseif source in ("zwally2012_antarctica", "zwally2012_greenland")
        return read_zwally(path(source))
    end
    error("unknown source $source")
end

function _only_shp(dir)
    files = filter(endswith(".shp"), readdir(dir; join=true))
    length(files) == 1 || error("expected one .shp file in $dir, found $(length(files))")
    return files[1]
end

# UN M49 region and subregion of each territory, by its ISO code, or that of its
# sovereign state for territories without one (e.g. Alaska, Hawaii, Canary Islands).
# North America is the M49 subregion "Northern America", Latin America and the
# Caribbean the intermediate level below "Americas".
function _with_m49(shapes, csvpath)
    tab, hdr = readdlm(csvpath, ','; header=true, quotes=true)
    col(name) = findfirst(==(name), vec(hdr))
    m49 = Dict{String,Tuple{String,String}}()
    for r in eachrow(tab)
        region = string(r[col("region")])
        isempty(region) && continue
        sub = string(r[col("sub-region")])
        sub = sub == "Latin America and the Caribbean" || sub == "Northern America" ? sub :
              region == "Americas" ? "Latin America and the Caribbean" : sub
        m49[string(r[col("alpha-3")])] = (region, sub)
    end
    for s in shapes
        iso = coalesce(s.attrs["iso_ter1"], "")
        haskey(m49, iso) || (iso = coalesce(s.attrs["iso_sov1"], ""))
        region, sub = get(m49, iso, ("", ""))
        s.attrs["m49_region"] = region
        s.attrs["m49_subregion"] = sub
    end
    return shapes
end

"""
    read_zwally(path) -> Vector{Shape}

GSFC drainage systems (Zwally et al., 2012): outlines as consecutive lat/lon points
per system, after a header ending with "END OF HEADER". The Antarctic file has
`lat lon id` per line, the Greenland file `id lat lon` with sub-system ids such as
1.1 (5.0 for a system without sub-systems). The attribute `basin` is the system id
(Antarctica: 1-27; Greenland: 10 system + sub-system, e.g. 1.1 => 11, 5.0 => 50).
"""
function read_zwally(path)
    lines = readlines(path)
    k = findfirst(l -> occursin("END OF HEADER", l), lines)
    greenland = occursin("grn", lowercase(basename(path)))
    pts = Dict{String,Vector{NTuple{2,Float64}}}()
    order = String[]
    for l in lines[k+1:end]
        v = split(strip(l))
        length(v) == 3 || continue
        id, lat, lon = greenland ? (v[1], v[2], v[3]) : (v[3], v[1], v[2])
        haskey(pts, id) || (pts[id] = NTuple{2,Float64}[]; push!(order, id))
        lonv = parse(Float64, lon)
        p = (lonv > 180 ? lonv - 360 : lonv, parse(Float64, lat))
        # The same point on either side of 180 degrees (an edge spanning all
        # longitudes would follow the parallel, see shapes.jl)
        q = pts[id]
        isempty(q) || (q[end][2] == p[2] && abs(q[end][1] - p[1]) == 360) || push!(q, p)
        isempty(q) && push!(q, p)
    end
    return [Shape([pts[id]], Dict{String,Any}("basin" => greenland ? round(Int, 10 * parse(Float64, id)) : parse(Int, id)))
            for id in order]
end

"True for glacier outlines of IceBoost v2 (`iceboost_v2_rgiNN`, see `glacier_mask`)."
is_glacier_source(source::AbstractString) = startswith(source, "iceboost_v2_rgi")

"""
    glacier_mask(g, source, rgi_id) -> BitMatrix

Cells of grid `g` at least half covered by a glacier of IceBoost v2 (`source`
`iceboost_v2_rgiNN`, `rgi_id` e.g. "RGI2000-v7.0-G-17-12835"): the footprint of its
thickness tile (see ../Topo/sources.jl), whose pixels include those touched by the RGI
7.0 outline.
"""
function glacier_mask(g::ProjGrid, source::AbstractString, rgi_id::AbstractString)
    dir = get_dataset_path(manifest(), source)
    for (root, _, fs) in walkdir(dir)
        "$rgi_id.tif" in fs || continue
        tg, H, _, _ = read_tile(joinpath(root, "$rgi_id.tif"))
        n = max(1, ceil(Int, 2 * spacing(g)[1] / spacing(tg)[1]))
        _, f = remap(g, tg, H; nsub=n)
        return BitMatrix(f .>= 0.5)
    end
    error("no IceBoost tile $rgi_id.tif in $dir")
end
