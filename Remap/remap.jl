# Remap a prepared NetCDF file (fields on their native lon-lat or projected grid) onto
# the grids of the domains, or all products of a thematic dataset (see README.md).
#
#     julia fesmdata.jl remap <file.nc> <Domain|GRID|all> ... [--vars=a,b] [--name=NAME]
#     julia fesmdata.jl remap <Dataset> [<product> ...] [<Domain|GRID> ...]

include(joinpath(@__DIR__, "..", "shared", "io.jl"))
include(joinpath(@__DIR__, "..", "shared", "domains.jl"))
include(joinpath(@__DIR__, "datasets.jl"))

# ---------------------------------------------------------------------------
# Prepared files
# ---------------------------------------------------------------------------

"Global attributes of a prepared file copied to the remapped files."
const COPIED_ATTRIB = ("title", "references", "doi", "license", "institution", "comment")

"Variable attributes of a prepared file copied to the remapped files."
const COPIED_VARATTRIB = ("units", "long_name", "standard_name", "comment")

"""
    RegionField

A field of a prepared file given by region rather than on the grid: one value per
region of a Regions product (e.g. a mean over each drainage basin). In the file, a
float variable on one dimension, whose coordinate variable holds the region numbers,
with the attribute `regions`, the Regions product (e.g. "BASINS-Zwally2012"): on each
grid, every cell gets the value of its region in `<GRID>_<regions>.nc`, the field of
that file named as the dimension (e.g. `basin`), see `region_field`.
"""
struct RegionField
    name::String
    regions::String                         # Regions product, e.g. BASINS-Zwally2012
    label::String                           # its field of region numbers, e.g. basin
    ids::Vector{Int}
    values::Vector{Float32}
    varattrib::Vector{Pair{String,Any}}
end

"""
    Prepared

The fields of a prepared file on their grid (`LonLatGrid` or `ProjGrid`), with their
extra dimensions (e.g. month, depth), the vector fields among them, their attributes
and the global attributes of the file. A field has size `(nx, ny, extra...)`: Float32
with NaN as missing, or integer (with `missing`). The fields given by region instead
(see `RegionField`) are apart.
"""
struct Prepared
    path::String
    grid::Union{LonLatGrid,ProjGrid}
    fields::Dict{String,Array}
    dims::Dict{String,Vector{Dim}}          # extra dimensions of each field
    vectors::Vector{Tuple{String,String}}   # (eastward, northward) components
    varattrib::Dict{String,Vector{Pair{String,Any}}}
    attrib::Vector{Pair{String,String}}
    aux::Vector{AuxVar}                     # variables on extra dimensions only (e.g. labels)
    regional::Vector{RegionField}           # fields given by region
end

const LON_UNITS = ("degrees_east", "degree_east", "degree_e", "degrees_e", "degreee", "degreese")
const LAT_UNITS = ("degrees_north", "degree_north", "degree_n", "degrees_n", "degreen", "degreesn")

# Kind of a coordinate variable: :lon, :lat, :x, :y or nothing.
function _axis_kind(name::AbstractString, v)
    units = lowercase(get(v.attrib, "units", ""))
    std = get(v.attrib, "standard_name", "")
    n = lowercase(name)
    (std == "longitude" || units in LON_UNITS || n in ("lon", "longitude")) && return :lon
    (std == "latitude" || units in LAT_UNITS || n in ("lat", "latitude")) && return :lat
    (std == "projection_x_coordinate" || n in ("x", "xc")) && return :x
    (std == "projection_y_coordinate" || n in ("y", "yc")) && return :y
    return nothing
end

# Uniform axis from coordinates `c` (ascending), rebuilt from its first value and
# mean spacing so that rounding in the file (e.g. Float32) does not matter.
function _uniform(c::AbstractVector, name)
    d = (c[end] - c[1]) / (length(c) - 1)
    all(k -> isapprox(c[k] - c[k-1], d; rtol=1e-3), 2:length(c)) ||
        error("$name is not uniformly spaced: only regular grids are supported")
    return c[1] .+ d .* (0:length(c)-1)
end

# Latitudes (ascending): rebuilt as a uniform axis when they are uniformly spaced up to
# rounding, kept as they are otherwise (e.g. a Gaussian grid).
function _latitudes(c::AbstractVector)
    d = (c[end] - c[1]) / (length(c) - 1)
    uniform = all(k -> isapprox(c[k] - c[k-1], d; rtol=1e-3), 2:length(c))
    return uniform ? _uniform(c, "lat") : Float64.(c)
end

# Latitude edges from the bounds variable of the latitudes (CF `bounds`, e.g. lat_bnds),
# in the order `iy`; nothing if there is none (edges halfway between the latitudes).
function _lat_edges(ds, ydim, iy)
    haskey(ds[ydim].attrib, "bounds") || return nothing
    b = Float64.(Array(ds[ds[ydim].attrib["bounds"]]))[:, iy]       # (2, nlat)
    lo, hi = vec(minimum(b; dims=1)), vec(maximum(b; dims=1))
    all(k -> isapprox(hi[k], lo[k+1]; atol=1e-6), 1:length(lo)-1) || return nothing
    return clamp.(vcat(lo, hi[end]), -90.0, 90.0)
end

# Order of the longitudes `lon` (any range, e.g. -180:180 or 0:360, in any order)
# that makes them ascending, and the ascending longitudes, starting in [-180, 180).
# A regional grid across the 180° meridian keeps its cells together (e.g. 170:190).
function _lon_order(lon::AbstractVector)
    l = mod.(Float64.(lon) .+ 180, 360) .- 180
    ix = sortperm(l)
    s = l[ix]
    gaps = diff(s)
    k = argmax(gaps)
    if gaps[k] > 1.5 * sort(gaps)[cld(length(gaps), 2)]    # a gap: the grid is regional
        ix = vcat(ix[k+1:end], ix[1:k])
        s = vcat(s[k+1:end], s[1:k] .+ 360)
    end
    return ix, s
end

# Grid of a prepared file: the names of its coordinate variables by kind (:lon, :lat,
# :x, :y), its x and y dimensions, and the fields on the grid (variables with both).
function _grid_vars(ds, path)
    coords = Dict{Symbol,String}()
    for name in keys(ds)
        v = ds[name]
        dimnames(v) == (name,) || continue
        kind = _axis_kind(name, v)
        kind === nothing || haskey(coords, kind) || (coords[kind] = name)
    end
    if haskey(coords, :lon) && haskey(coords, :lat)
        xdim, ydim = coords[:lon], coords[:lat]
    elseif haskey(coords, :x) && haskey(coords, :y)
        xdim, ydim = coords[:x], coords[:y]
    else
        error("$path: no lon/lat or x/y coordinate variables found")
    end
    ongrid = String[]
    for (name, v) in ds
        name in (xdim, ydim) && continue
        dn = dimnames(v)
        xdim in dn && ydim in dn && push!(ongrid, name)
    end
    return coords, xdim, ydim, ongrid
end

# Fields of a prepared file given by region (see `RegionField`): float variables on one
# dimension with a coordinate variable, with the attribute `regions`.
function _region_vars(ds)
    names = String[]
    for (name, v) in ds
        dn = dimnames(v)
        (length(dn) == 1 && dn[1] != name && haskey(v.attrib, "regions")) || continue
        haskey(ds, dn[1]) && dimnames(ds[dn[1]]) == (dn[1],) ||
            error("$name: its dimension $(dn[1]) has no coordinate variable (the region numbers)")
        push!(names, name)
    end
    return names
end

"Names of the fields of a prepared file (the variables on its grid, and those given by region)."
prepared_fields(path::AbstractString) = NCDataset(ds -> vcat(_grid_vars(ds, path)[4], _region_vars(ds)), path)

"""
    read_prepared(path; vars=nothing) -> Prepared

Read the fields of a prepared file: all fields on the grid of the file, or the fields
`vars`. The grid is given by 1D coordinate variables, lon and lat (degrees, -180:180
or 0:360, in any order) or x and y (m or km) with a `grid_mapping` variable holding a
PROJ string (`proj_params` or `proj4`). Latitudes and y may be descending, and
latitudes may be unevenly spaced (e.g. a Gaussian grid; their cell edges are taken
from a CF `bounds` variable if there is one). Fields may
have extra dimensions (with or without coordinate variables), and may be integer.
Vector fields are pairs with the standard names `eastward_*` and `northward_*`.
Missing values (_FillValue, NaN) become NaN, or `missing` in integer fields. Fields
given by region (see `RegionField`) are read too, but at least one field must be on the
grid.
"""
function read_prepared(path::AbstractString; vars=nothing)
    NCDataset(path) do ds
        coords, xdim, ydim, ongrid = _grid_vars(ds, path)
        byregion = _region_vars(ds)
        chosen = vars === nothing ? vcat(ongrid, byregion) : collect(String, vars)
        for name in chosen
            name in ongrid || name in byregion ||
                error("$path: no field $name, available: $(join(vcat(ongrid, byregion), ", "))")
        end
        selected = filter(in(ongrid), chosen)
        isempty(selected) && error("$path: no fields on the grid")

        # Grid, and the reordering of the data to ascending axes
        xr, yr = ds[xdim][:], ds[ydim][:]
        iy = sortperm(yr)
        if haskey(coords, :lon) && xdim == coords[:lon]
            ix, lon = _lon_order(xr)
            grid = LonLatGrid(_uniform(lon, "lon"), _latitudes(yr[iy]); latedges=_lat_edges(ds, ydim, iy))
        else
            ix = sortperm(xr)
            grid = ProjGrid(splitext(basename(path))[1], _km(ds[xdim], xr[ix], xdim),
                            _km(ds[ydim], yr[iy], ydim), _proj(ds, selected[1]))
        end

        fields = Dict{String,Array}()
        dims = Dict{String,Vector{Dim}}()
        varattrib = Dict{String,Vector{Pair{String,Any}}}()
        for name in selected
            v = ds[name]
            dn = collect(dimnames(v))
            extra = filter(d -> !(d in (xdim, ydim)), dn)
            perm = [findfirst(==(xdim), dn), findfirst(==(ydim), dn), (findfirst(==(d), dn) for d in extra)...]
            A = permutedims(Array(v), perm)
            A = A[ix, iy, ntuple(_ -> Colon(), length(extra))...]
            isint = _integer_field(v)
            fields[name] = isint ? _integers(A) : Float32.(nomissing(A, NaN))
            dims[name] = [_dim(ds, d) for d in extra]
            keys_ = isint ? (COPIED_VARATTRIB..., "flag_values", "flag_meanings") : COPIED_VARATTRIB
            varattrib[name] = [k => v.attrib[k] for k in keys_ if haskey(v.attrib, k)]
        end
        attrib = [k => string(ds.attrib[k]) for k in COPIED_ATTRIB if haskey(ds.attrib, k)]
        regional = [_region_field(ds, name) for name in filter(in(byregion), chosen)]
        return Prepared(abspath(path), grid, fields, dims, _vectors(path, fields, dims, varattrib), varattrib, attrib,
                        _aux(ds, dims), regional)
    end
end

# Field `name` of a prepared file given by region (see `RegionField`)
function _region_field(ds, name)
    v = ds[name]
    label = dimnames(v)[1]
    nonmissingtype(eltype(v)) <: AbstractFloat || error("$name: a field given by region must be float")
    ids = Int.(ds[label][:])
    allunique(ids) || error("$name: the region numbers of $label are not unique")
    return RegionField(name, string(v.attrib["regions"]), label, ids, Float32.(nomissing(v[:], NaN)),
                       [k => v.attrib[k] for k in COPIED_VARATTRIB if haskey(v.attrib, k)])
end

# Variables on extra dimensions of the fields only (e.g. label(time)), other than the
# coordinate and bounds variables of these dimensions, copied as they are.
function _aux(ds, dims)
    extra = Set(d.name for ds_ in values(dims) for d in ds_)
    bounds = Set(v.attrib["bounds"] for (_, v) in ds if haskey(v.attrib, "bounds"))
    aux = AuxVar[]
    for (name, v) in ds
        dn = collect(dimnames(v))
        (isempty(dn) || !issubset(dn, extra) || dn == [name] || name in bounds) && continue
        push!(aux, AuxVar(name, Array(v.var), dn, Pair{String,Any}[k => v.attrib[k] for k in keys(v.attrib)]))
    end
    return aux
end

# Extra dimension `name` of a prepared file, with the raw values and attributes of its
# coordinate variable (indices 1:n if it has none) and its bounds, if any.
function _dim(ds, name)
    if haskey(ds, name) && dimnames(ds[name]) == (name,)
        v = ds[name]
        attrib = Pair{String,Any}[k => v.attrib[k] for k in keys(v.attrib)]
        b = get(v.attrib, "bounds", nothing)
        b !== nothing && !haskey(ds, b) && (filter!(p -> first(p) != "bounds", attrib); b = nothing)
        bounds = b === nothing ? nothing : _bounds(ds[b], name)
        return Dim(name, Array(v.var), attrib, bounds)
    end
    return Dim(name, collect(1:ds.dim[name]), Pair{String,Any}[])
end

# Bounds variable of dimension `name` as a 2 x n matrix (raw values)
function _bounds(v, name)
    B = Array(v.var)
    return dimnames(v)[1] == name ? permutedims(B) : B
end

# Standard name of field `name` ("" if none)
_standard_name(varattrib, name) = string(get(Dict(varattrib[name]), "standard_name", ""))

# Vector fields: pairs of fields with the standard names eastward_<x> and northward_<x>,
# both read, on the same dimensions.
function _vectors(path, fields, dims, varattrib)
    std(name) = _standard_name(varattrib, name)
    pairs = Tuple{String,String}[]
    for e in sort(collect(keys(fields)))
        startswith(std(e), "eastward_") || continue
        target = "northward_" * chopprefix(std(e), "eastward_")
        k = findfirst(n -> std(n) == target, collect(keys(fields)))
        k === nothing && error("$path: $e ($(std(e))) has no $target component among the fields read")
        n = collect(keys(fields))[k]
        [d.name for d in dims[e]] == [d.name for d in dims[n]] || error("$path: $e and $n differ in dimensions")
        push!(pairs, (e, n))
    end
    for n in keys(fields)
        startswith(std(n), "northward_") && !any(p -> p[2] == n, pairs) &&
            error("$path: $n ($(std(n))) has no eastward component among the fields read")
    end
    return pairs
end

# Integer fields: integer variables, and flag (class) variables stored as floats
_integer_field(v) = nonmissingtype(eltype(v)) <: Integer || haskey(v.attrib, "flag_values")

_integers(A::AbstractArray{<:Union{Missing,Integer}}) = A
_integers(A::AbstractArray) = map(a -> ismissing(a) || isnan(a) ? missing : Int32(a), A)

# Projected coordinates in km
function _km(v, c, name)
    units = lowercase(get(v.attrib, "units", "m"))
    units in ("km", "kilometre", "kilometer") && return Float64.(c)
    units in ("m", "metre", "meter") && return Float64.(c) ./ 1000
    error("unsupported units $units of projected coordinate $name")
end

# PROJ string (km) of the grid mapping of field `name`
function _proj(ds, name)
    haskey(ds[name].attrib, "grid_mapping") ||
        error("$name has no grid_mapping attribute: projected grids need one with a PROJ string")
    gm = ds[ds[name].attrib["grid_mapping"]].attrib
    key = findfirst(k -> haskey(gm, k), ("proj_params", "proj4", "proj4text", "proj4_params"))
    key === nothing && error("grid mapping of $name has no PROJ string (proj_params or proj4); " *
                             "CF parameters and WKT are not supported yet")
    p = gm[("proj_params", "proj4", "proj4text", "proj4_params")[key]]
    p = replace(p, r"\+units=\S+" => "")
    return strip(p) * " +units=km"
end

"""
    read_prepared_files(paths; vars=nothing) -> Vector{Prepared}

Read the prepared files of a product (see `read_prepared`): all their fields, or the
fields `vars`, each from the files that have it. Every field of `vars` must be in one
of the files, and every file must have one of them.
"""
function read_prepared_files(paths::AbstractVector{<:AbstractString}; vars=nothing)
    vars === nothing && return [read_prepared(path) for path in paths]
    available = Dict(path => prepared_fields(path) for path in paths)
    nowhere = filter(v -> !any(path -> v in available[path], paths), vars)
    isempty(nowhere) || error("no field $(join(nowhere, ", ")) in $(join(basename.(paths), ", "))")
    ps = Prepared[]
    for path in paths
        sel = filter(in(available[path]), vars)
        isempty(sel) && error("$path: none of the fields $(join(vars, ", "))")
        push!(ps, read_prepared(path; vars=sel))
    end
    return ps
end

"""
    PreparedFields

The fields of one or more prepared files (`Prepared`) remapped together into one
product: their names, the integer ones, their extra dimensions, the vector fields and
their attributes (of the first file with the field). A field in several files must
have the same units and extra dimensions, and be a vector component in all or none.
"""
struct PreparedFields
    names::Vector{String}
    integer::Set{String}
    dims::Dict{String,Vector{Dim}}
    vectors::Vector{Tuple{String,String}}
    varattrib::Dict{String,Vector{Pair{String,Any}}}
end

function PreparedFields(ps::AbstractVector{Prepared})
    names = sort(unique(f for p in ps for f in keys(p.fields)))
    integer = Set{String}()
    dims = Dict{String,Vector{Dim}}()
    varattrib = Dict{String,Vector{Pair{String,Any}}}()
    for f in names
        has = [p for p in ps if haskey(p.fields, f)]
        p1 = has[1]
        isint(p) = nonmissingtype(eltype(p.fields[f])) <: Integer
        units(p) = get(Dict(p.varattrib[f]), "units", nothing)
        shape(p) = [(d.name, length(d.values)) for d in p.dims[f]]
        for p in has[2:end]
            what = "$f in $(basename(p1.path)) and $(basename(p.path))"
            isint(p) == isint(p1) || error("$what: integer in one only")
            units(p) == units(p1) || error("$what: different units ($(units(p1)), $(units(p)))")
            shape(p) == shape(p1) || error("$what: different extra dimensions")
        end
        isint(p1) && push!(integer, f)
        dims[f] = p1.dims[f]
        varattrib[f] = p1.varattrib[f]
    end
    vectors = sort(unique(v for p in ps for v in p.vectors))
    for (e, n) in vectors, p in ps
        (haskey(p.fields, e) || haskey(p.fields, n)) && !((e, n) in p.vectors) &&
            error("$(basename(p.path)): $e and $n are not a vector field, as in the other files")
    end
    return PreparedFields(names, integer, dims, vectors, varattrib)
end

"""
    combine_remapped(outs, pf) -> Dict

The fields of several prepared files remapped onto one grid (`outs`, by file: field =>
(Ft, f_valid)) combined, for files covering separate areas (e.g. the grounded and the
floating ice of an ice sheet, on grids of their own): a field in one file as it is; a
field in several files from the sum of their contributions, S = Σ v_i f_i, and of the
fractions of the cell they cover, F = Σ f_i: f_valid = min(F, 1), and the value S / F,
or S where F > 1 (where their remapped coverage overlaps, e.g. offset source grids at a
boundary), so that value × f_valid = S and the total of each file is kept. Of integer
fields, the class of the file covering most of the cell.
"""
function combine_remapped(outs::AbstractVector, pf::PreparedFields)
    length(outs) == 1 && return outs[1]
    out = Dict{String,Tuple{Array,Array{Float32}}}()
    for f in pf.names
        parts = [o[f] for o in outs if haskey(o, f)]
        if length(parts) == 1
            out[f] = parts[1]
            continue
        end
        fv = sum(last, parts)
        if f in pf.integer
            Ft, best = copy(parts[1][1]), copy(parts[1][2])
            for (F, v) in parts[2:end]
                k = v .> best
                Ft[k] .= F[k]
                best[k] .= v[k]
            end
        else
            S, W = zeros(size(fv)), zeros(size(fv))
            for (F, v) in parts, i in eachindex(F)
                (v[i] > 0 && !isnan(F[i])) || continue
                S[i] += v[i] * F[i]
                W[i] += v[i]
            end
            Ft = map((s, w) -> w > 1 ? Float32(s) : w > 0 ? Float32(s / w) : NaN32, S, W)
        end
        out[f] = (Ft, min.(fv, 1.0f0))
    end
    return out
end

"""
Global attributes of several files (`attribs`, of each file): of each, its distinct
values joined, by their parts separated by "; " (e.g. the references shared by files
listed once).
"""
function merged_attrib(attribs::AbstractVector{<:AbstractVector{<:Pair}})
    attrib = Pair{String,String}[]
    for k in unique(first(a) for at in attribs for a in at)
        vals = unique(part for at in attribs if haskey(Dict(at), k) for part in split(Dict(at)[k], "; "))
        push!(attrib, k => join(vals, "; "))
    end
    return attrib
end

"Global attributes of the prepared files of a product (see `merged_attrib`)."
merged_attrib(ps::AbstractVector{Prepared}) = merged_attrib([p.attrib for p in ps])

# ---------------------------------------------------------------------------
# Target grids
# ---------------------------------------------------------------------------

"""
    select_grids(args) -> Vector{OutGrid}

Output grids named by `args`: domains (output folders, e.g. Antarctica, their standard
grids), grids (e.g. ANT-8KM, or a grid made on request such as GLOBAL-T170), or "all"
(the standard grids of all active domains).
"""
function select_grids(args)
    isempty(args) && error("give the target domains or grids (e.g. Antarctica ANT-8KM, or all)")
    grids = [og for key in domain_keys(; inactive=true) for og in Domain(key).grids]
    active = Set(og.folder for key in domain_keys() for og in Domain(key).grids)
    standard = filter(og -> !og.on_request, grids)
    folders = sort(unique(og.folder for og in grids))
    sel = OutGrid[]
    for a in args
        if a == "all"
            append!(sel, filter(og -> og.folder in active, standard))
        elseif a in folders
            append!(sel, filter(og -> og.folder == a, standard))
        else
            k = findfirst(og -> og.grid.name == a, grids)
            k === nothing && error("unknown domain or grid $a, domains: $(join(folders, ", "))")
            push!(sel, grids[k])
        end
    end
    return unique(og -> og.grid.name, sel)
end

# ---------------------------------------------------------------------------
# Remapping
# ---------------------------------------------------------------------------

"Remapping methods: conservative and bilinear."
const METHODS = ("con", "bilinear")


# Samples per cell side for conservative remapping from `src` onto `tgt` (`nothing`:
# exact). Sampled remapping uses samples spaced at most half the source spacing; a
# source on the same projection, or a lon-lat source on a lon-lat grid, is remapped
# exactly. The spacing of a lon-lat source is the smallest over the target, where its
# cells are narrowest (up to 85°, nearer the pole the samples are coarser than its cells).
function con_nsub(tgt::ProjGrid, src::LonLatGrid)
    latmax = min(maximum(abs, lat_bounds(tgt)), 85.0)
    ds = 111.195 * min(src.dlat, src.dlon * cosd(latmax))
    return max(1, ceil(Int, 2 * spacing_km(tgt) / ds))
end

con_nsub(tgt::ProjGrid, src::ProjGrid) =
    same_projection(tgt, src) ? nothing : max(1, ceil(Int, 2 * spacing_km(tgt) / minimum(spacing(src))))

con_nsub(::LonLatGrid, ::LonLatGrid) = nothing

con_nsub(tgt::LonLatGrid, src::ProjGrid) = max(1, ceil(Int, 2 * spacing_km(tgt) / minimum(spacing(src))))

"Largest number of samples of a `SampledMap` (about 16 bytes each while it is built)."
const MAX_MAP_SAMPLES = 200_000_000

"""
    con_map(tgt, src, nsub) -> AlignedMap, SampledMap or nothing

Conservative remapping from `src` onto `tgt` (see `con_nsub`) prepared once, to remap
many fields (e.g. time steps, classes): exact, or sampled if it is not too large
(`nothing` otherwise).
"""
con_map(tgt, src, nsub) = nsub === nothing ? AlignedMap(tgt, src) :
                          prod(size(tgt)) * nsub^2 <= MAX_MAP_SAMPLES ? SampledMap(tgt, src, nsub) : nothing

"""
    remap_con(tgt, src, F; nsub, conmap=nothing)

Conservative remapping of `F` onto `tgt`, exact or with `nsub` samples per cell side
(see `con_nsub`), or by `conmap` (see `con_map`) if given.
"""
remap_con(tgt, src, F; nsub=con_nsub(tgt, src), conmap=nothing) =
    conmap !== nothing ? remap(conmap, F) : nsub === nothing ? remap(tgt, src, F) : remap(tgt, src, F; nsub)

"""
    smoothing_sigma(method, smooth, tgt, src) -> Float64

Standard deviation (km) of the Gaussian smoothing after remapping from `src` onto
`tgt`: `smooth` in km, or with `smooth = "auto"`, half the source spacing when a
coarser source is remapped conservatively (which removes the steps between its
cells), and no smoothing otherwise.
"""
function smoothing_sigma(method::AbstractString, smooth, tgt, src)
    smooth == "auto" || return Float64(smooth)
    return method == "con" && spacing_km(src) > spacing_km(tgt) ? spacing_km(src) / 2 : 0.0
end

"""
    remap_field(tgt, src, F; method="con", sigma=0, nsub, conmap=nothing) -> (Ft, f_valid)

2D field `F` on `src` remapped onto `tgt` by `method` (see `METHODS`), then smoothed
with a Gaussian of standard deviation `sigma` (km) if `sigma > 0`. `f_valid` is the
fraction of each cell covered by the source, before smoothing.
"""
function remap_field(tgt, src, F::AbstractMatrix; method::AbstractString="con", sigma::Real=0,
                     nsub=con_nsub(tgt, src), conmap=nothing)
    Ft, fv = method == "con" ? remap_con(tgt, src, F; nsub, conmap) :
             method == "bilinear" ? remap_bilinear(tgt, src, F) :
             error("unknown method $method, available: $(join(METHODS, ", "))")
    return (sigma > 0 ? smooth(tgt, Ft, sigma) : Ft), fv
end

"Largest number of distinct values of an integer field (classes) remapped by dominant class."
const MAX_CLASSES = 1000

"""
    remap_classes(tgt, src, M; nsub, classes, conmap=nothing) -> (Mt, f_valid)

Class of the 2D integer field `M` covering the largest area of each target cell, from
the conservatively remapped area fraction of each class (ties go to the smaller
class), `missing` where the source has no data; `f_valid` is the fraction of each
cell covered by the source.
"""
function remap_classes(tgt, src, M::AbstractMatrix; nsub=con_nsub(tgt, src), classes=sort(unique(skipmissing(M))),
                       conmap=nothing)
    Mt = Matrix{Union{Missing,nonmissingtype(eltype(M))}}(missing, size(tgt))
    best = fill(-1.0f0, size(tgt))
    fv = zeros(Float32, size(tgt))
    ind = Matrix{Float32}(undef, size(M))
    for c in classes
        @. ind = ifelse(ismissing(M), NaN32, Float32(coalesce(M == c, false)))
        fr, fv = remap_con(tgt, src, ind; nsub, conmap)
        for k in eachindex(fr)
            if fr[k] > best[k] + 1.0f-6
                best[k] = fr[k]
                Mt[k] = c
            end
        end
    end
    return Mt, fv
end

"""
    remap_array(tgt, src, F; method, sigma, nsub, conmap=nothing) -> (Ft, f_valid)

Field `F` (size `(nx, ny, extra...)`) remapped onto `tgt` slice by slice: by
`remap_field`, or by `remap_classes` if `F` is integer, conservatively by `conmap` if
given (see `con_map`). `f_valid` has the size of `Ft`.
"""
function remap_array(tgt, src, F::AbstractArray; method::AbstractString, sigma::Real, nsub, conmap=nothing)
    extra = size(F)[3:end]
    isint = nonmissingtype(eltype(F)) <: Integer
    if isint
        classes = sort(unique(skipmissing(F)))
        length(classes) <= MAX_CLASSES ||
            error("integer field with $(length(classes)) values: integers are remapped as classes " *
                  "(dominant class), store quantities as floats")
        Ft = Array{Union{Missing,nonmissingtype(eltype(F))}}(missing, size(tgt)..., extra...)
    else
        Ft = Array{Float32}(undef, size(tgt)..., extra...)
    end
    fv = Array{Float32}(undef, size(tgt)..., extra...)
    for I in CartesianIndices(extra)
        S = view(F, :, :, I)
        Ft[:, :, I], fv[:, :, I] = isint ? remap_classes(tgt, src, S; nsub, classes, conmap) :
                                   remap_field(tgt, src, S; method, sigma, nsub, conmap)
    end
    return Ft, fv
end

# Vector fields remapped onto a projected grid: the eastward and northward components
# rotated to the axes of the grid, slice by slice; their attributes say so.
function rotate_vectors!(out, varattrib, vectors, g::ProjGrid)
    isempty(vectors) && return
    α = grid_angle(g)
    for (e, n) in vectors
        ue, vn = out[e][1], out[n][1]
        for I in CartesianIndices(size(ue)[3:end])
            ue[:, :, I], vn[:, :, I] = rotate_to_grid(α, ue[:, :, I], vn[:, :, I])
        end
        for (name, axis, dir) in ((e, "x", "eastward"), (n, "y", "northward"))
            atts = Dict(varattrib[name])
            ln = string(get(atts, "long_name", name))
            ln = occursin(Regex("\\b$dir\\b", "i"), ln) ? replace(ln, Regex("\\b$dir\\b", "i") => "grid $axis") :
                 "$ln (along the grid $axis axis)"
            varattrib[name] = vcat(filter(p -> !(first(p) in ("standard_name", "long_name")), varattrib[name]),
                                   ["long_name" => ln, "vector_component" => "along the $axis axis of the grid"])
        end
    end
end

rotate_vectors!(out, varattrib, vectors, ::LonLatGrid) = nothing

# Fraction covered by the source of a remapped field, without the extra dimensions
# along which it does not change (e.g. month, for ocean data at depth); returns it and
# the extra dimensions kept (indices into the extra dimensions of the field).
function _collapse(fv::AbstractArray)
    kept = collect(1:ndims(fv)-2)
    for k in reverse(kept)
        d = k + 2
        first_ = selectdim(fv, d, 1:1)
        if all(i -> selectdim(fv, d, i:i) == first_, axes(fv, d))
            fv = dropdims(first_; dims=d)
            deleteat!(kept, k)
        end
    end
    return fv, kept
end

# Field `name` from the arrays `A` of each field (e.g. f_valid), without the extra
# dimensions along which it does not change (`pdims`: the extra dimensions of each
# field): one field if it is the same for all fields, else `<name>_<field>` for each.
# `attrib(f)` gives the attributes of the field of `f` (nothing: the single field).
function _per_field!(fields, dims, varattrib, A::AbstractDict, pdims, name, attrib)
    names = sort(collect(keys(A)))
    c = Dict(f => _collapse(A[f]) for f in names)
    cdims(f) = pdims[f][c[f][2]]
    if allequal(c[f][1] for f in names) && allequal([d.name for d in cdims(f)] for f in names)
        fields[name] = c[names[1]][1]
        dims[name] = cdims(names[1])
        a = attrib(nothing)
        isempty(a) || (varattrib[name] = a)
    else
        for f in names
            fields["$(name)_$f"] = c[f][1]
            dims["$(name)_$f"] = cdims(f)
            varattrib["$(name)_$f"] = attrib(f)
        end
    end
end

# ---------------------------------------------------------------------------
# Fields given by region
# ---------------------------------------------------------------------------

"""
    region_field(og, r::RegionField) -> Matrix{Float32}

Field `r` on grid `og`: each cell gets the value of its region, the field `r.label`
(e.g. `basin`) of the Regions product `r.regions` on the grid (`<GRID>_<regions>.nc` in
its output folder). Cells outside the regions (e.g. the open ocean, beyond the extent of
the basins) get the nearest region (`extend_labels`, by distance along the grid), so that
the field covers the whole grid; regions without a value in `r` are missing.
"""
function region_field(og::OutGrid, r::RegionField)
    path = remap_file(og, r.regions)
    isfile(path) || error("$(og.grid.name): no $path, the regions of $(r.name): make Regions first")
    L = NCDataset(path) do ds
        haskey(ds, r.label) || error("$path: no $(r.label)")
        Int.(coalesce.(ds[r.label][:, :], 0))
    end
    size(L) == size(og.grid) || error("$path: $(r.label) has size $(size(L)), not that of $(og.grid.name)")
    L[L .< 0] .= 0
    dx, dy = og.grid isa ProjGrid ? spacing(og.grid) : (1.0, 1.0)
    L = extend_labels(L, trues(size(L)), dx, dy)
    value = Dict(zip(r.ids, r.values))
    return map(l -> get(value, l, NaN32), L)
end

"Attributes of a field given by region on the grids."
region_attrib(r::RegionField) = vcat(filter(p -> first(p) != "comment", r.varattrib), [
    "regions" => r.regions,
    "comment" => join(filter(!isempty, [string(get(Dict(r.varattrib), "comment", "")),
        "one value per region: the value of the region ($(r.label) of $(r.regions)) of each cell; cells " *
        "outside the regions get the nearest region"]), "; ")])

# ---------------------------------------------------------------------------
# Gaps filled
# ---------------------------------------------------------------------------

"Where the gaps of `fill` are filled, for the descriptions in the files and the log."
fill_where(fill::GapFill) = fill.mask == "all" ? "everywhere" : "over the ice (H_ice > 0 in $(fill.mask))"

"How the gaps of `fill` are filled, for the descriptions in the files and the log."
function fill_how(fill::GapFill)
    fill.method == "harmonic" && return "harmonic (Laplace) interpolation from the cells around"
    fill.method == "elevation" && return "the surface elevation (z_srf of $(fill.elevation), 0 over the ocean)"
    d = "linear regression on the surface elevation (z_srf of $(fill.elevation), 0 over the ocean) of the " *
        "cells with data within $(fill.radius) km (grown by $(fill.radius / 2) km until there are at least " *
        "$(fill.min_points)), at the elevation of the cell clamped to the range of their elevations"
    isempty(fill.cap) && return d
    caps = join(("$f <= $c (of the annual mean for monthly fields, all months shifted by the same " *
                 "amount)" for (f, c) in sort(collect(fill.cap))), ", ")
    return "$d; at most $caps"
end

"Cells of grid `og` whose gaps `fill` fills: those with ice in its Topo product (`ice_mask`), or all."
fill_mask(og::OutGrid, fill::GapFill) = fill.mask == "all" ? trues(size(og.grid)) : ice_mask(og, fill.mask)

"""
    ice_mask(og, product) -> BitMatrix

Cells with ice (H_ice > 0) on grid `og` in the Topo product `product` (e.g.
"TOPO-BedMachine-v4"), from `<GRID>_<product>.nc` in its output folder.
"""
function ice_mask(og::OutGrid, product::AbstractString)
    path = remap_file(og, product)
    isfile(path) || error("$(og.grid.name): no $path, the ice mask of the gap filling: make Topo first " *
                          "(thematic datasets depend on Topo, and some on Regions)")
    H = NCDataset(path) do ds
        haskey(ds, "H_ice") || error("$path: no H_ice")
        ds["H_ice"][:, :]
    end
    size(H) == size(og.grid) || error("$path: H_ice has size $(size(H)), not that of $(og.grid.name)")
    return coalesce.(H .> 0, false)
end

# Speed of the vector field with eastward component `e`: the field with the standard
# name <x>_speed for eastward_<x>_velocity or eastward_<x> (e.g. land_ice_surface_speed,
# wind_speed), nothing if there is none.
function _speed_field(pf::PreparedFields, e)
    target = chopsuffix(chopprefix(_standard_name(pf.varattrib, e), "eastward_"), "_velocity") * "_speed"
    k = findfirst(f -> _standard_name(pf.varattrib, f) == target, pf.names)
    return k === nothing ? nothing : pf.names[k]
end

"""
    topo_elevation(og, product) -> Matrix{Float64}

Surface elevation `z_srf` (m) on grid `og` in the Topo product `product`, 0 over the
ocean (and where it is missing or negative).
"""
function topo_elevation(og::OutGrid, product::AbstractString)
    path = remap_file(og, product)
    isfile(path) || error("$(og.grid.name): no $path, the elevations of the gap filling: make Topo first")
    z = NCDataset(path) do ds
        haskey(ds, "z_srf") || error("$path: no z_srf")
        ds["z_srf"][:, :]
    end
    size(z) == size(og.grid) || error("$path: z_srf has size $(size(z)), not that of $(og.grid.name)")
    return max.(Float64.(coalesce.(z, 0.0)), 0.0)
end

# The variables of the `fills` among the fields `pf`, as floats, with both components of
# each vector in the same fill, by harmonic interpolation; the field `gaps_of` among them.
function check_fill(pf::PreparedFields, fills::AbstractVector{GapFill})
    for fill in fills, f in fill.variables
        f in pf.names || error("fill: no field $f, available: $(join(pf.names, ", "))")
        f in pf.integer && error("fill: $f is an integer field")
    end
    for fill in fills
        isempty(fill.gaps_of) || fill.gaps_of in pf.names || error("fill: no field $(fill.gaps_of) (gaps_of)")
    end
    for fill in fills, (e, n) in pf.vectors
        (e in fill.variables) == (n in fill.variables) || error("fill: give both components $e and $n of the vector")
        e in fill.variables && fill.method != "harmonic" && error("fill: vectors are filled by harmonic interpolation")
    end
end

"""
    RangeTable(z, valid)

Minima and maxima of `z` over the cells `valid` of the ranges of each row (along x), in
constant time (sparse tables of the ranges of 2^k cells).
"""
struct RangeTable
    lo::Vector{Matrix{Float32}}
    hi::Vector{Matrix{Float32}}
end

function RangeTable(z::AbstractMatrix, valid::AbstractMatrix{Bool})
    nx, ny = size(z)
    lo = [Float32[valid[i, j] ? z[i, j] : Inf32 for i in 1:nx, j in 1:ny]]
    hi = [Float32[valid[i, j] ? z[i, j] : -Inf32 for i in 1:nx, j in 1:ny]]
    w = 1
    while 2w <= nx
        a, b = lo[end], hi[end]
        A, B = fill(Inf32, nx, ny), fill(-Inf32, nx, ny)
        for j in 1:ny, i in 1:nx-2w+1
            A[i, j] = min(a[i, j], a[i+w, j])
            B[i, j] = max(b[i, j], b[i+w, j])
        end
        push!(lo, A)
        push!(hi, B)
        w *= 2
    end
    return RangeTable(lo, hi)
end

"Minimum and maximum of the valid elevations of cells `i1:i2` of row `j`."
function range_extrema(t::RangeTable, i1::Int, i2::Int, j::Int)
    k = floor(Int, log2(i2 - i1 + 1))
    a, b = i1, i2 - (1 << k) + 1
    return min(t.lo[k+1][a, j], t.lo[k+1][b, j]), max(t.hi[k+1][a, j], t.hi[k+1][b, j])
end

"""
    regression_fill!(F, gaps, valid, z, dx, dy, gf, table) -> (nfilled, ngrown, slopes)

Fill the cells `gaps` of the 2D field `F` by the linear regression of `F` on the
elevation `z` over the cells `valid` (with finite values) within `gf.radius` km of the
cell (a disk, cell spacing `dx`, `dy` in km), grown by `gf.radius / 2` until there are at
least `gf.min_points`, at the elevation of the cell clamped to the range of the
elevations of these points (`table`, the `RangeTable` of `z` and `valid`), so that the
regression is never extrapolated (the mean where the elevations of the points hardly
differ). Cells with fewer points within the whole grid stay missing. Returns the cells
filled, those whose radius was grown, and the slopes (per m).
"""
function regression_fill!(F::AbstractMatrix, gaps::AbstractMatrix{Bool}, valid::AbstractMatrix{Bool},
                          z::AbstractMatrix, dx::Real, dy::Real, gf::GapFill, table::RangeTable)
    nx, ny = size(F)
    # Sums along x (prefix sums by row) of 1, z, z^2, F, z F over the valid cells
    P = zeros(nx + 1, ny, 5)
    for j in 1:ny, i in 1:nx
        v = valid[i, j]
        zi, f = z[i, j], v ? Float64(F[i, j]) : 0.0
        q = v ? (1.0, zi, zi^2, f, zi * f) : (0.0, 0.0, 0.0, 0.0, 0.0)
        for k in 1:5
            P[i+1, j, k] = P[i, j, k] + q[k]
        end
    end
    rmax = hypot(nx * dx, ny * dy)
    cells = findall(gaps)
    value = fill(NaN, length(cells))
    slope = fill(NaN, length(cells))
    grown = falses(length(cells))
    Threads.@threads for c in eachindex(cells)
        i, j = Tuple(cells[c])
        R = gf.radius
        S = zeros(5)
        while true
            S .= 0
            nr = floor(Int, R / dy)
            for dj in -nr:nr
                jj = j + dj
                1 <= jj <= ny || continue
                ni = floor(Int, sqrt(max(R^2 - (dj * dy)^2, 0.0)) / dx)
                lo, hi = max(i - ni, 1), min(i + ni, nx)
                for k in 1:5
                    S[k] += P[hi+1, jj, k] - P[lo, jj, k]
                end
            end
            (S[1] >= gf.min_points || R >= rmax) && break
            R += gf.radius / 2
            grown[c] = true
        end
        n = S[1]
        n >= gf.min_points || continue
        zm, fm = S[2] / n, S[4] / n
        var = S[3] / n - zm^2
        b = var > 1.0 ? (S[5] / n - zm * fm) / var : 0.0       # 1 m2: elevations hardly differ
        # Range of the elevations of the points within R
        zlo, zhi = Inf32, -Inf32
        nr = floor(Int, R / dy)
        for dj in -nr:nr
            jj = j + dj
            1 <= jj <= ny || continue
            ni = floor(Int, sqrt(max(R^2 - (dj * dy)^2, 0.0)) / dx)
            a, h = range_extrema(table, max(i - ni, 1), min(i + ni, nx), jj)
            zlo, zhi = min(zlo, a), max(zhi, h)
        end
        value[c] = fm + b * (clamp(z[i, j], zlo, zhi) - zm)
        slope[c] = b
    end
    for (c, I) in enumerate(cells)
        F[I] = value[c]
    end
    return count(isfinite, value), count(grown), filter(isfinite, slope)
end

"Mean lengths of the months (days), the weights of the annual mean of a monthly field."
const MONTH_DAYS = [31, 28.25, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

# Upper bound `cap` of the filled values of field `Ft` (cells `filled`): for a monthly
# field (extra dimension month of 12 only), of the annual mean (months weighted by their
# mean length), all months of a cell shifted by the same amount; else of each value.
function cap_filled!(Ft, filled, cap, monthly::Bool)
    if !monthly
        k = (filled .== 1) .& (Ft .> cap)
        Ft[k] .= cap
        return
    end
    size(Ft, 3) == 12 || error("fill: cap of a monthly field needs 12 months")
    w = MONTH_DAYS ./ sum(MONTH_DAYS)
    for j in axes(Ft, 2), i in axes(Ft, 1)
        all(==(1), view(filled, i, j, :)) || continue
        m = sum(w[k] * Ft[i, j, k] for k in 1:12)
        m > cap && (Ft[i, j, :] .-= Float32(m - cap))
    end
end

"""
    fill_gaps!(out, pf, og, fills) -> Dict{String,Array{Int8}}

Fill the gaps of the remapped fields `out` (field => (Ft, f_valid)) of `pf` on grid
`og` (see `GapFill`): in each variable of each fill, slice by slice, the cells of
`fill_mask` (with ice, or all) with no source data (f_valid = 0), by harmonic
interpolation from the cells around them (`laplace_fill!`; gaps not connected to data
stay missing), by the regression on the elevation (`regression_fill!`, then `cap`), or by
the elevation itself (`topo_elevation`; with `gaps_of`, in the cells of `fill_mask` where
that field has no source data in any slice, instead of the gaps of the variable).
The speed of a filled vector (see `_speed_field`) is the magnitude of the filled
components in the cells filled. Returns the cells filled (1) in each variable.
"""
function fill_gaps!(out, pf::PreparedFields, og::OutGrid, fills::AbstractVector{GapFill})
    filled = Dict{String,Array{Int8}}()
    for fill in fills
        cells = fill_mask(og, fill)
        regression = fill.method == "elevation_regression"
        fill.method == "harmonic" || (z = topo_elevation(og, fill.elevation))
        if !isempty(fill.gaps_of)
            fv_of = out[fill.gaps_of][2]
            cells = cells .& reshape(any(==(0), fv_of; dims=3:max(ndims(fv_of), 3)), size(cells))
        end
        if regression
            og.grid isa ProjGrid || error("fill: elevation_regression needs a projected grid")
            dx, dy = spacing(og.grid)
        end
        for f in fill.variables
            Ft, fv = out[f]
            filled[f] = zeros(Int8, size(Ft))
            nleft, ngrown, slopes = 0, 0, Float64[]
            valid0, table = nothing, nothing
            for I in CartesianIndices(size(Ft)[3:end])
                gaps = isempty(fill.gaps_of) ? cells .& (view(fv, :, :, I) .== 0) : cells
                F = view(Ft, :, :, I)
                if regression
                    valid = (view(fv, :, :, I) .> 0) .& isfinite.(F)
                    valid == valid0 || ((valid0, table) = (valid, RangeTable(z, valid)))
                    _, g, b = regression_fill!(F, gaps, valid, z, dx, dy, fill, table)
                    ngrown += g
                    append!(slopes, b)
                    nleft += count(gaps .& isnan.(F))
                elseif fill.method == "elevation"
                    F[gaps] .= z[gaps]
                else
                    nleft += laplace_fill!(F, gaps)
                end
                filled[f][:, :, I] .= gaps .& .!isnan.(F)
            end
            haskey(fill.cap, f) && cap_filled!(Ft, filled[f], fill.cap[f], [d.name for d in pf.dims[f]] == ["month"])
            ncells = count(any(==(1), filled[f]; dims=3:max(ndims(Ft), 3)))
            msg = "$(og.grid.name): gaps $(fill_where(fill)) of $(isempty(fill.gaps_of) ? f : fill.gaps_of) " *
                  "filled in $f ($(fill.method)), " *
                  "$ncells cells" * (nleft > 0 ? ", $nleft cell-slices left missing" : "")
            if regression
                msg *= "; radius grown for $ngrown cell-slices, median slope " *
                       "$(isempty(slopes) ? NaN : round(1000 * sort(slopes)[cld(end, 2)]; sigdigits=3)) per 1000 m"
            end
            println(msg)
        end
    end
    for (e, n) in pf.vectors
        s = _speed_field(pf, e)
        (haskey(filled, e) && s !== nothing) || continue
        S, ue, vn = out[s][1], out[e][1], out[n][1]
        size(S) == size(ue) || error("fill: speed $s and $e differ in dimensions")
        k = (filled[e] .== 1) .& (filled[n] .== 1)
        S[k] .= hypot.(ue[k], vn[k])
    end
    return filled
end

"Description of the fills, for the global attribute `gap_fill` and `mask_fill`."
fills_description(fills) = join(("$(join(fill.variables, ", ")): $(fill_how(fill)) $(fill_where(fill)) " *
                                 (isempty(fill.gaps_of) ? "where there are no source data" :
                                  "where $(fill.gaps_of) has no source data") for fill in fills), "; ")

"Attributes of `mask_fill` (or `mask_fill_<f>` for field `f`)."
function mask_fill_attrib(fills::AbstractVector{GapFill}, f)
    fs = f === nothing ? fills : filter(fill -> f in fill.variables, fills)
    return Pair{String,Any}[
        "units" => "1",
        "long_name" => "gap filled" * (f === nothing ? "" : " in $f"),
        "flag_values" => Int8[0, 1], "flag_meanings" => "source filled",
        "comment" => (all(fill -> isempty(fill.gaps_of), fs) ? "1: no source data (f_valid = 0), filled: " :
                      "1: filled: ") * fills_description(fs)]
end

"Description of a remapping for the global attribute `remap_method`."
function method_description(method::AbstractString, sigma::Real; integers::Bool=false)
    d = method == "con" ? "conservative" : "bilinear"
    d = sigma > 0 ? "$d, then Gaussian smoothing (sigma = $(round(sigma; digits=1)) km)" : d
    return integers ? "$d; integer fields: dominant class (conservative)" : d
end

"Output file of the remapped fields `name` on a grid."
remap_file(og::OutGrid, name::AbstractString) = joinpath(outdir(og), "$(og.grid.name)_$(name).nc")

"""
Intermediate file of the remapped fields `name` on a grid that is not one of their
own, e.g. a member of an ensemble product on a grid of the ensemble only:
\$FESMDATA_WORK/remap/members/<GRID>/<GRID>_<name>.nc (not released).
"""
member_work_file(og::OutGrid, name::AbstractString) =
    joinpath(_env("FESMDATA_WORK"), "remap", "members", og.grid.name, "$(og.grid.name)_$(name).nc")

"""
    remap_prepared(ps, grids; name, method="con", smooth="auto", dataset="remap",
                   overwrite=false, strict=false, fill=GapFill[], precision=Dict(),
                   intermediate=false) -> Vector{String}

Remap the fields of the prepared files `ps` (one `Prepared` or several, each on its own
grid) onto each grid (see `remap_array` and `smoothing_sigma`) and write them to
`<GRID>_<name>.nc` in its output folder, with `f_valid`, the area fraction of each
cell covered by source data (`f_valid_<field>` for each field when their coverage
differs; with the extra dimensions when it differs between them). The fields of
several files are combined on each grid (see `combine_remapped`). Vector fields are
rotated to the axes of projected grids. With `fill` (`GapFill`s), the gaps are then
filled (see `fill_gaps!`), marked by `mask_fill`. Grids not covered by
the sources are skipped (an error if `strict`). The grid files are written if missing.
Existing files are kept unless `overwrite`. `dataset` is the dataset of the
provenance attributes. `precision` gives the precision of some float fields instead of
their default (see `write_fields`). With `intermediate`, the files are intermediate
files instead (`member_work_file`), not rounded, without grid files.
"""
function remap_prepared(ps::AbstractVector{Prepared}, grids::Vector{OutGrid}; name::AbstractString,
                        method::AbstractString="con", smooth="auto", dataset::AbstractString="remap",
                        overwrite::Bool=false, strict::Bool=false, fill::AbstractVector{GapFill}=GapFill[],
                        precision::AbstractDict{String,Precision}=Dict{String,Precision}(),
                        intermediate::Bool=false)
    method in METHODS || error("unknown method $method, available: $(join(METHODS, ", "))")
    pf = PreparedFields(ps)
    check_fill(pf, fill)
    regional = [r for p in ps for r in p.regional]
    allunique(r -> r.name, regional) && !any(r -> r.name in pf.names, regional) ||
        error("fields given by region in several files, or also on the grid")
    paths = String[]
    names = pf.names
    sources = join(basename.(getfield.(ps, :path)), ", ")
    for og in grids
        path = intermediate ? member_work_file(og, name) : remap_file(og, name)
        if isfile(path) && !overwrite
            println("$(og.grid.name): exists, skipped (--overwrite to replace)")
            continue
        end
        outs = Dict[]
        hows = String[]
        t = @elapsed for p in ps
            pnames = sort(collect(keys(p.fields)))
            integers = any(in(pf.integer), pnames)
            sigma = smoothing_sigma(method, smooth, og.grid, p.grid)
            nsub = con_nsub(og.grid, p.grid)
            # The remapping is prepared once when it is used many times: integer fields
            # (one remapping per class), several fields or slices
            reuse = integers || sum(f -> prod(size(p.fields[f])[3:end]; init=1), pnames) > 1
            conmap = reuse ? con_map(og.grid, p.grid, nsub) : nothing
            push!(outs, Dict(f => remap_array(og.grid, p.grid, p.fields[f]; method, sigma, nsub, conmap) for f in pnames))
            push!(hows, method_description(method, sigma; integers))
        end
        out = combine_remapped(outs, pf)
        if all(f -> all(iszero, out[f][2]), names)
            strict && error("$(og.grid.name) is not covered by $sources")
            println("$(og.grid.name): not covered by the source, skipped")
            continue
        end
        varattrib = copy(pf.varattrib)
        rotate_vectors!(out, varattrib, pf.vectors, og.grid)
        filled = isempty(fill) ? nothing : fill_gaps!(out, pf, og, fill)
        fields = Dict{String,Array}(f => out[f][1] for f in names)
        dims = copy(pf.dims)
        _per_field!(fields, dims, varattrib, Dict(f => out[f][2] for f in names), pf.dims, "f_valid",
                    f -> f === nothing ? Pair{String,Any}[] : ["units" => "1", "long_name" => "area fraction covered by $f"])
        how = allequal(hows) ? hows[1] : join(("$(basename(p.path)): $h" for (p, h) in zip(ps, hows)), "; ")
        attrib = vcat(merged_attrib(ps), ["remapped_from" => sources, "remap_method" => how])
        length(ps) > 1 && push!(attrib, "combined" => "fields of several files covering separate areas merged: " *
                                                       "their contributions (value x covered fraction) summed, " *
                                                       "f_valid the sum of the covered fractions, at most 1")
        for r in regional
            fields[r.name] = region_field(og, r)
            dims[r.name] = Dim[]
            varattrib[r.name] = region_attrib(r)
        end
        if filled !== nothing
            _per_field!(fields, dims, varattrib, filled, pf.dims, "mask_fill", f -> mask_fill_attrib(fill, f))
            push!(attrib, "gap_fill" => fills_description(fill) * " (mask_fill)")
        end
        intermediate || isfile(joinpath(outdir(og), "$(og.grid.name)_grid.nc")) ||
            write_grid_files(outdir(og), og.grid; dataset)
        aux = unique(a -> a.name, [a for p in ps for a in p.aux])
        write_fields(path, og.grid, fields; dataset, attrib, varattrib, dims, aux, precision, og.elevation,
                     lossless=intermediate)
        println("$(og.grid.name): $(basename(path)), $how ($(round(t; digits=1)) s)")
        push!(paths, path)
    end
    return paths
end

remap_prepared(p::Prepared, grids::Vector{OutGrid}; kwargs...) = remap_prepared([p], grids; kwargs...)

"Value of the option --smooth: \"auto\" or a standard deviation in km."
function parse_smooth(s::AbstractString)
    s == "auto" && return "auto"
    v = tryparse(Float64, s)
    (v === nothing || v < 0) && error("--smooth must be auto or a standard deviation in km (0: none), not $s")
    return v
end

# ---------------------------------------------------------------------------
# Ensembles
# ---------------------------------------------------------------------------

"Long names of the statistics of an ensemble product, appended to those of the fields."
const STAT_NAMES = Dict("mean" => "ensemble mean", "stdev" => "ensemble standard deviation")

"""
    ensemble_stat(As, stat) -> (S, n)

Statistic `stat` (see `ENSEMBLE_STATS`) of the arrays `As` (of the members, same size)
in each cell, over the members with a finite value there: their mean, or their
population standard deviation (divided by n); NaN where none has a value. `n` is the
number of these members.
"""
function ensemble_stat(As::AbstractVector{<:AbstractArray{Float32}}, stat::AbstractString)
    n = zeros(Int8, size(As[1]))
    s = zeros(size(As[1]))
    for A in As, i in eachindex(A)
        isfinite(A[i]) || continue
        n[i] += 1
        s[i] += A[i]
    end
    m = map((s, n) -> n > 0 ? s / n : NaN, s, n)
    stat == "mean" && return Float32.(m), n
    ss = zeros(size(m))
    for A in As, i in eachindex(A)
        isfinite(A[i]) && (ss[i] += (A[i] - m[i])^2)
    end
    return Float32.(map((ss, n) -> n > 0 ? sqrt(ss / n) : NaN, ss, n)), n
end

"""
    MemberFile

The output file of a member of an ensemble product on a grid: its float fields (size
`(nx, ny, extra...)`, NaN as missing), their extra dimensions and attributes, the
variables on the extra dimensions only, and the global attributes copied from the
prepared files (but the title).
"""
struct MemberFile
    path::String
    fields::Dict{String,Array{Float32}}
    dims::Dict{String,Vector{Dim}}
    varattrib::Dict{String,Vector{Pair{String,Any}}}
    aux::Vector{AuxVar}
    attrib::Vector{Pair{String,String}}
end

"Whether a field of an output file is data, not the area covered by the source or the gaps filled."
is_data_field(name::AbstractString) = !startswith(name, "f_valid") && !startswith(name, "mask_fill")

"""
    read_member(path, og) -> MemberFile

Read the output file of a member of an ensemble product on grid `og`: its float data
fields (see `is_data_field`); integer fields (classes) have no ensemble statistics.
"""
function read_member(path::AbstractString, og::OutGrid)
    gdims = grid_dims(og.grid)
    NCDataset(path) do ds
        fields = Dict{String,Array{Float32}}()
        dims = Dict{String,Vector{Dim}}()
        varattrib = Dict{String,Vector{Pair{String,Any}}}()
        for (name, v) in ds
            dn = dimnames(v)
            (length(dn) >= 2 && dn[1:2] == gdims && is_data_field(name) && !_integer_field(v)) || continue
            fields[name] = Float32.(nomissing(Array(v), NaN))
            size(fields[name])[1:2] == size(og.grid) || error("$path: $name is not on $(og.grid.name)")
            dims[name] = [_dim(ds, d) for d in dn[3:end]]
            varattrib[name] = [k => v.attrib[k] for k in COPIED_VARATTRIB if haskey(v.attrib, k)]
        end
        isempty(fields) && error("$path: no float fields on $(og.grid.name)")
        attrib = [k => string(ds.attrib[k]) for k in COPIED_ATTRIB if haskey(ds.attrib, k) && k != "title"]
        return MemberFile(path, fields, dims, varattrib, _aux(ds, dims), attrib)
    end
end

"""
    ensemble_fields(ms, stat) -> (fields, dims, varattrib)

The fields of an ensemble product on a grid from the files of its members `ms`: of
each field of any member, the statistic `stat` over the members that have it (see
`ensemble_stat`), with their units and extra dimensions, which must agree, and
`n_<field>`, the number of members with a value in each cell.
"""
function ensemble_fields(ms::AbstractVector{MemberFile}, stat::AbstractString)
    fields = Dict{String,Array}()
    dims = Dict{String,Vector{Dim}}()
    varattrib = Dict{String,Vector{Pair{String,Any}}}()
    for f in sort(unique(f for m in ms for f in keys(m.fields)))
        has = [m for m in ms if haskey(m.fields, f)]
        m1 = has[1]
        units(m) = get(Dict(m.varattrib[f]), "units", nothing)
        shape(m) = [(d.name, d.values) for d in m.dims[f]]
        for m in has[2:end]
            what = "$f in $(basename(m1.path)) and $(basename(m.path))"
            units(m) == units(m1) || error("$what: different units ($(units(m1)), $(units(m)))")
            shape(m) == shape(m1) || error("$what: different extra dimensions")
        end
        fields[f], fields["n_$f"] = ensemble_stat([m.fields[f] for m in has], stat)
        dims[f] = dims["n_$f"] = m1.dims[f]
        atts = Dict(m1.varattrib[f])
        # The standard name is that of the field, not of its standard deviation
        keep = stat == "mean" ? ("units", "standard_name", "comment") : ("units", "comment")
        varattrib[f] = vcat([k => atts[k] for k in keep if haskey(atts, k)],
                            ["long_name" => "$(get(atts, "long_name", f)), $(STAT_NAMES[stat])"])
        varattrib["n_$f"] = ["units" => "1", "long_name" => "number of ensemble members with $f"]
    end
    return fields, dims, varattrib
end

"""
    make_product(p, grids; tag, overwrite=false) -> Vector{String}

Make a product of a thematic dataset on `grids` (some of its grids), as
`<GRID>_<Dataset>-<name>.nc` in their output folders, with the provenance attributes
of the dataset `tag`. Existing files are kept unless `overwrite`. A remap product is
remapped from its prepared files (see `remap_prepared`), made first by the prepare.jl
of its source if missing; every grid must be covered by the source (by one of its
files, for a product of several files).
"""
function make_product(p::RemapProduct, grids::Vector{OutGrid}; tag::AbstractString, overwrite::Bool=false,
                      intermediate::Bool=false)
    files = prepared_files(p)
    all(isfile, files) || run_prepare(p.source)
    preps = read_prepared_files(files; vars=p.variables)
    names = vcat(PreparedFields(preps).names, [r.name for q in preps for r in q.regional])
    println("$(product_name(p)): $(join(names, ", ")) from $(p.source) " *
            (length(files) > 1 ? "($(length(files)) files) " : "") * "onto $(length(grids)) grids")
    return remap_prepared(preps, grids; name=product_name(p), method=p.method, smooth=p.smooth, dataset=tag,
                          overwrite, strict=true, fill=p.fill, p.precision, intermediate)
end

"""
An ensemble product is made on each grid from the files of its members (see
`ensemble_fields`), with the global attributes of their prepared files joined (see
`merged_attrib`); the files of the members missing on a grid are made first: their
products on the grids of their own, intermediate files (`member_work_file`) on the other
grids of the ensemble (e.g. the 2 km grids of the mountain-glacier domains, where only
the ensemble statistics are released).
"""
function make_product(p::EnsembleProduct, grids::Vector{OutGrid}; tag::AbstractString, overwrite::Bool=false)
    members = ensemble_members(p)
    paths = String[]
    for m in members
        todo = filter(og -> on_grid(m, og) && !isfile(remap_file(og, product_name(m))), grids)
        isempty(todo) || append!(paths, make_product(m, todo; tag))
        todo = filter(og -> !on_grid(m, og) && !isfile(member_work_file(og, product_name(m))), grids)
        isempty(todo) || make_product(m, todo; tag, intermediate=true)
    end
    println("$(product_name(p)): $(STAT_NAMES[p.stat]) of $(length(members)) products onto $(length(grids)) grids")
    for og in grids
        path = remap_file(og, product_name(p))
        if isfile(path) && !overwrite
            println("$(og.grid.name): exists, skipped (--overwrite to replace)")
            continue
        end
        ms = [read_member((on_grid(m, og) ? remap_file : member_work_file)(og, product_name(m)), og)
              for m in members]
        fields, dims, varattrib = ensemble_fields(ms, p.stat)
        how = p.stat == "mean" ? "mean" : "standard deviation (population, divided by n)"
        title = "$(uppercasefirst(STAT_NAMES[p.stat])) of $(length(members)) products of $(p.dataset)"
        attrib = vcat(["title" => title,
                       "ensemble_members" => join(product_name.(members), ", "),
                       "ensemble_stat" => "$how over the members with a value in each cell (n_<field>)"],
                      merged_attrib([m.attrib for m in ms]))
        aux = unique(a -> a.name, [a for m in ms for a in m.aux])
        isfile(joinpath(outdir(og), "$(og.grid.name)_grid.nc")) || write_grid_files(outdir(og), og.grid; dataset=tag)
        write_fields(path, og.grid, fields; dataset=tag, attrib, varattrib, dims, aux, p.precision, og.elevation)
        println("$(og.grid.name): $(basename(path))")
        push!(paths, path)
    end
    return paths
end

"""
    remap_dataset(dataset, args=String[]; overwrite=false) -> Vector{String}

Make the products of a thematic dataset (<Dataset>/remap.toml) on the grids of their
domains (see `make_product`): all products, or those named in `args`, on all their
grids, or on the domains and grids named in `args`. Ensemble products are made after
the remap products.
"""
function remap_dataset(dataset::AbstractString, args=String[]; overwrite::Bool=false)
    products = remap_products(dataset)
    names = [p.name for p in products]
    chosen = filter(in(names), args)
    targets = setdiff(args, chosen)
    selected = isempty(chosen) ? products : filter(p -> p.name in chosen, products)
    selected = vcat(filter(p -> p isa RemapProduct, selected), filter(p -> p isa EnsembleProduct, selected))
    only_grids = isempty(targets) ? nothing : Set(og.grid.name for og in select_grids(targets))
    tag = dataset_tag(dataset)
    paths = String[]
    for p in selected
        grids = product_grids(p)
        only_grids === nothing || filter!(og -> og.grid.name in only_grids, grids)
        isempty(grids) && continue
        append!(paths, make_product(p, grids; tag, overwrite))
    end
    isempty(chosen) && isempty(paths) && !isempty(targets) &&
        println("No product of $dataset on $(join(targets, ", ")) (products: $(join(names, ", ")))")
    return paths
end

"""
    remap_command(args; vars=nothing, name=nothing, method=nothing, smooth=nothing, overwrite=false)

`julia fesmdata.jl remap <file.nc> <Domain|GRID|all> ...`: remap the fields of a
prepared file (or `vars`) onto the grids, as `<GRID>_<name>.nc` (`name` defaults to
the file name), by `method` (default "con") and with smoothing `smooth` (default
"auto"). `julia fesmdata.jl remap <Dataset> ...`: remap the products of a thematic
dataset (see `remap_dataset`), whose options are defined in its remap.toml.
"""
function remap_command(args; vars=nothing, name=nothing, method=nothing, smooth=nothing, overwrite::Bool=false)
    isempty(args) && error("give a prepared NetCDF file or a thematic dataset")
    if !isfile(args[1]) && is_remap_dataset(args[1])
        given = [o for (o, v) in (("--vars", vars), ("--name", name), ("--method", method), ("--smooth", smooth))
                 if v !== nothing]
        isempty(given) || error("$(join(given, ", ")): defined in $(args[1])/remap.toml for a thematic dataset")
        return remap_dataset(args[1], args[2:end]; overwrite)
    end
    path = args[1]
    isfile(path) || error("no file or thematic dataset $path")
    grids = select_grids(args[2:end])
    sm = parse_smooth(something(smooth, "auto"))
    meth = something(method, "con")
    p = read_prepared(path; vars)
    nm = name === nothing ? splitext(basename(path))[1] : name
    println("$(basename(path)): $(join(vcat(sort(collect(keys(p.fields))), [r.name for r in p.regional]), ", ")) " *
            "on a $(_describe(p.grid))")
    println("Remapping onto $(length(grids)) grids as <GRID>_$(nm).nc")
    return remap_prepared(p, grids; name=nm, method=meth, smooth=sm, overwrite)
end

_describe(g::LonLatGrid) = "$(join(size(g), "x")) lon-lat grid ($(g.dlon)° x $(round(g.dlat; digits=4))°" *
                           (uniform_lat(g) ? ")" : " on average, uneven latitudes)")
_describe(g::ProjGrid) = "$(join(size(g), "x")) projected grid ($(spacing(g)[1]) km)"
