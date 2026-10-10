# Remap a prepared NetCDF file (fields on their native lon-lat or projected grid) onto
# the grids of the domains, with conservative remapping (see README.md).
#
#     julia fesmdata.jl remap <file.nc> <Domain|GRID|all> ... [--vars=a,b] [--name=NAME]

include(joinpath(@__DIR__, "..", "shared", "io.jl"))
include(joinpath(@__DIR__, "..", "shared", "domains.jl"))

# ---------------------------------------------------------------------------
# Prepared files
# ---------------------------------------------------------------------------

"Global attributes of a prepared file copied to the remapped files."
const COPIED_ATTRIB = ("title", "references", "doi", "license", "institution", "comment")

"Variable attributes of a prepared file copied to the remapped files."
const COPIED_VARATTRIB = ("units", "long_name", "standard_name", "comment")

"""
    Prepared

The 2D fields of a prepared file on their grid (`LonLatGrid` or `ProjGrid`), with
their attributes and the global attributes of the file.
"""
struct Prepared
    path::String
    grid::Union{LonLatGrid,ProjGrid}
    fields::Dict{String,Matrix{Float64}}
    varattrib::Dict{String,Vector{Pair{String,Any}}}
    attrib::Vector{Pair{String,String}}
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

"""
    read_prepared(path; vars=nothing) -> Prepared

Read the 2D fields of a prepared file: all fields on the grid of the file, or the
fields `vars`. The grid is given by 1D coordinate variables, lon and lat (degrees,
-180:180 or 0:360, in any order) or x and y (m or km) with a `grid_mapping`
variable holding a PROJ string (`proj_params` or `proj4`). Latitudes and y may be
descending. Missing values (_FillValue, NaN) become NaN.
"""
function read_prepared(path::AbstractString; vars=nothing)
    NCDataset(path) do ds
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

        # Fields on the grid; others are listed, so that nothing is dropped silently
        ongrid = String[]
        other = String[]
        for (name, v) in ds
            name in values(coords) && continue
            dn = dimnames(v)
            if Set(dn) == Set((xdim, ydim)) && length(dn) == 2
                push!(ongrid, name)
            elseif xdim in dn && ydim in dn
                push!(other, name)
            end
        end
        selected = vars === nothing ? ongrid : collect(String, vars)
        for name in selected
            name in ongrid && continue
            name in other && error("$path: $name has more than two dimensions $(dimnames(ds[name])), " *
                                   "only 2D fields are supported so far")
            error("$path: no 2D field $name on the grid, available: $(join(ongrid, ", "))")
        end
        isempty(selected) && error("$path: no 2D fields on the grid")
        vars === nothing && !isempty(other) &&
            @warn "skipping fields with more than two dimensions: $(join(other, ", "))"

        # Grid, and the reordering of the data to ascending axes
        xr, yr = ds[xdim][:], ds[ydim][:]
        iy = sortperm(yr)
        if haskey(coords, :lon) && xdim == coords[:lon]
            ix, lon = _lon_order(xr)
            grid = LonLatGrid(_uniform(lon, "lon"), _uniform(yr[iy], "lat"))
        else
            ix = sortperm(xr)
            grid = ProjGrid(splitext(basename(path))[1], _km(ds[xdim], xr[ix], xdim),
                            _km(ds[ydim], yr[iy], ydim), _proj(ds, selected[1]))
        end

        fields = Dict{String,Matrix{Float64}}()
        varattrib = Dict{String,Vector{Pair{String,Any}}}()
        for name in selected
            v = ds[name]
            _integer_field(v) && error("$path: $name is an integer or flag field (mask); only " *
                                       "continuous fields are supported so far")
            A = Float64.(nomissing(v[:, :], NaN))
            dimnames(v) == (ydim, xdim) && (A = permutedims(A))
            fields[name] = A[ix, iy]
            varattrib[name] = [k => v.attrib[k] for k in COPIED_VARATTRIB if haskey(v.attrib, k)]
        end
        attrib = [k => string(ds.attrib[k]) for k in COPIED_ATTRIB if haskey(ds.attrib, k)]
        return Prepared(abspath(path), grid, fields, varattrib, attrib)
    end
end

_integer_field(v) = eltype(v) <: Union{Missing,Integer} || haskey(v.attrib, "flag_values")

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

# ---------------------------------------------------------------------------
# Target grids
# ---------------------------------------------------------------------------

"""
    select_grids(args) -> Vector{OutGrid}

Output grids named by `args`: domains (output folders, e.g. Antarctica), grids (e.g.
ANT-8KM), or "all".
"""
function select_grids(args)
    isempty(args) && error("give the target domains or grids (e.g. Antarctica ANT-8KM, or all)")
    grids = [og for key in domain_keys() for og in Domain(key).grids]
    folders = sort(unique(og.folder for og in grids))
    sel = OutGrid[]
    for a in args
        if a == "all"
            append!(sel, grids)
        elseif a in folders
            append!(sel, filter(og -> og.folder == a, grids))
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

# Conservative remapping onto a target grid. Sampled remapping uses samples spaced at
# most half the source spacing; a source on the same projection is remapped exactly.
# The spacing of a lon-lat source is the smallest over the target, where its cells
# are narrowest (up to 85°, nearer the pole the samples are coarser than its cells).
function remap_field(tgt::ProjGrid, src::LonLatGrid, F)
    latmax = min(maximum(abs, lat_bounds(tgt)), 85.0)
    ds = 111.195 * min(src.dlat, src.dlon * cosd(latmax))
    return remap(tgt, src, F; nsub=max(1, ceil(Int, 2 * spacing(tgt)[1] / ds)))
end

function remap_field(tgt::ProjGrid, src::ProjGrid, F)
    same_projection(tgt, src) && return remap(tgt, src, F)
    return remap(tgt, src, F; nsub=max(1, ceil(Int, 2 * spacing(tgt)[1] / minimum(spacing(src)))))
end

"Output file of the remapped fields `name` on a grid."
remap_file(og::OutGrid, name::AbstractString) = joinpath(outdir(og), "$(og.grid.name)_$(name).nc")

"""
    remap_prepared(p, grids; name, dataset="remap", overwrite=false) -> Vector{String}

Remap the fields of `p` onto each grid and write them to `<GRID>_<name>.nc` in its
output folder, with `f_valid`, the area fraction of each cell covered by source data
(`f_valid_<field>` for each field when their coverage differs). Grids not covered by
the source are skipped. The grid files are written if missing. Existing files are
kept unless `overwrite`.
"""
function remap_prepared(p::Prepared, grids::Vector{OutGrid}; name::AbstractString,
                        dataset::AbstractString="remap", overwrite::Bool=false)
    paths = String[]
    names = sort(collect(keys(p.fields)))
    for og in grids
        path = remap_file(og, name)
        if isfile(path) && !overwrite
            println("$(og.grid.name): exists, skipped (--overwrite to replace)")
            continue
        end
        t = @elapsed out = Dict(f => remap_field(og.grid, p.grid, p.fields[f]) for f in names)
        if all(f -> all(iszero, out[f][2]), names)
            println("$(og.grid.name): not covered by the source, skipped")
            continue
        end
        fields = Dict{String,Matrix}(f => out[f][1] for f in names)
        varattrib = copy(p.varattrib)
        if allequal(out[f][2] for f in names)
            fields["f_valid"] = out[names[1]][2]
        else
            for f in names
                fields["f_valid_$f"] = out[f][2]
                varattrib["f_valid_$f"] = ["units" => "1", "long_name" => "area fraction covered by $f"]
            end
        end
        attrib = vcat(p.attrib, ["remapped_from" => basename(p.path)])
        isfile(joinpath(outdir(og), "$(og.grid.name)_grid.nc")) || write_grid_files(outdir(og), og.grid; dataset)
        write_fields(path, og.grid, fields; dataset, attrib, varattrib)
        println("$(og.grid.name): $(basename(path)) ($(round(t; digits=1)) s)")
        push!(paths, path)
    end
    return paths
end

"""
    remap_command(args; vars=nothing, name=nothing, overwrite=false)

`julia fesmdata.jl remap <file.nc> <Domain|GRID|all> ...`: remap the fields of a
prepared file (or `vars`) onto the grids, as `<GRID>_<name>.nc` (`name` defaults to
the file name).
"""
function remap_command(args; vars=nothing, name=nothing, overwrite::Bool=false)
    isempty(args) && error("give a prepared NetCDF file and the target domains or grids")
    path = args[1]
    isfile(path) || error("no file $path")
    grids = select_grids(args[2:end])
    p = read_prepared(path; vars)
    nm = name === nothing ? splitext(basename(path))[1] : name
    println("$(basename(path)): $(join(sort(collect(keys(p.fields))), ", ")) on a $(_describe(p.grid))")
    println("Remapping onto $(length(grids)) grids as <GRID>_$(nm).nc")
    return remap_prepared(p, grids; name=nm, overwrite)
end

_describe(g::LonLatGrid) = "$(join(size(g), "x")) lon-lat grid ($(g.dlon)° x $(g.dlat)°)"
_describe(g::ProjGrid) = "$(join(size(g), "x")) projected grid ($(spacing(g)[1]) km)"
