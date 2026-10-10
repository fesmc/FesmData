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

"Remapping methods: conservative and bilinear."
const METHODS = ("con", "bilinear")

"Spacing of a grid in km (of a lon-lat grid: its latitude spacing)."
spacing_km(g::ProjGrid) = maximum(spacing(g))
spacing_km(g::LonLatGrid) = 111.195 * g.dlat

# Conservative remapping onto a target grid. Sampled remapping uses samples spaced at
# most half the source spacing; a source on the same projection, or a lon-lat source
# on a lon-lat grid, is remapped exactly. The spacing of a lon-lat source is the
# smallest over the target, where its cells are narrowest (up to 85°, nearer the pole
# the samples are coarser than its cells).
function remap_con(tgt::ProjGrid, src::LonLatGrid, F)
    latmax = min(maximum(abs, lat_bounds(tgt)), 85.0)
    ds = 111.195 * min(src.dlat, src.dlon * cosd(latmax))
    return remap(tgt, src, F; nsub=max(1, ceil(Int, 2 * spacing_km(tgt) / ds)))
end

function remap_con(tgt::ProjGrid, src::ProjGrid, F)
    same_projection(tgt, src) && return remap(tgt, src, F)
    return remap(tgt, src, F; nsub=max(1, ceil(Int, 2 * spacing_km(tgt) / minimum(spacing(src)))))
end

remap_con(tgt::LonLatGrid, src::LonLatGrid, F) = remap(tgt, src, F)

remap_con(tgt::LonLatGrid, src::ProjGrid, F) =
    remap(tgt, src, F; nsub=max(1, ceil(Int, 2 * spacing_km(tgt) / minimum(spacing(src)))))

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
    remap_field(tgt, src, F; method="con", sigma=0) -> (Ft, f_valid)

Field `F` on `src` remapped onto `tgt` by `method` (see `METHODS`), then smoothed with a
Gaussian of standard deviation `sigma` (km) if `sigma > 0`. `f_valid` is the fraction
of each cell covered by the source, before smoothing.
"""
function remap_field(tgt, src, F; method::AbstractString="con", sigma::Real=0)
    Ft, fv = method == "con" ? remap_con(tgt, src, F) :
             method == "bilinear" ? remap_bilinear(tgt, src, F) :
             error("unknown method $method, available: $(join(METHODS, ", "))")
    return (sigma > 0 ? smooth(tgt, Ft, sigma) : Ft), fv
end

"Description of a remapping for the global attribute `remap_method`."
function method_description(method::AbstractString, sigma::Real)
    d = method == "con" ? "conservative" : "bilinear"
    return sigma > 0 ? "$d, then Gaussian smoothing (sigma = $(round(sigma; digits=1)) km)" : d
end

"Output file of the remapped fields `name` on a grid."
remap_file(og::OutGrid, name::AbstractString) = joinpath(outdir(og), "$(og.grid.name)_$(name).nc")

"""
    remap_prepared(p, grids; name, method="con", smooth="auto", dataset="remap",
                   overwrite=false, strict=false) -> Vector{String}

Remap the fields of `p` onto each grid (see `remap_field` and `smoothing_sigma`) and
write them to `<GRID>_<name>.nc` in its output folder, with `f_valid`, the area
fraction of each cell covered by source data (`f_valid_<field>` for each field when
their coverage differs). Grids not covered by the source are skipped (an error if
`strict`). The grid files are written if missing. Existing files are kept unless
`overwrite`. `dataset` is the dataset of the provenance attributes.
"""
function remap_prepared(p::Prepared, grids::Vector{OutGrid}; name::AbstractString, method::AbstractString="con",
                        smooth="auto", dataset::AbstractString="remap", overwrite::Bool=false, strict::Bool=false)
    method in METHODS || error("unknown method $method, available: $(join(METHODS, ", "))")
    paths = String[]
    names = sort(collect(keys(p.fields)))
    for og in grids
        path = remap_file(og, name)
        if isfile(path) && !overwrite
            println("$(og.grid.name): exists, skipped (--overwrite to replace)")
            continue
        end
        sigma = smoothing_sigma(method, smooth, og.grid, p.grid)
        t = @elapsed out = Dict(f => remap_field(og.grid, p.grid, p.fields[f]; method, sigma) for f in names)
        if all(f -> all(iszero, out[f][2]), names)
            strict && error("$(og.grid.name) is not covered by $(basename(p.path))")
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
        how = method_description(method, sigma)
        attrib = vcat(p.attrib, ["remapped_from" => basename(p.path), "remap_method" => how])
        isfile(joinpath(outdir(og), "$(og.grid.name)_grid.nc")) || write_grid_files(outdir(og), og.grid; dataset)
        write_fields(path, og.grid, fields; dataset, attrib, varattrib)
        println("$(og.grid.name): $(basename(path)), $how ($(round(t; digits=1)) s)")
        push!(paths, path)
    end
    return paths
end

"Value of the option --smooth: \"auto\" or a standard deviation in km."
function parse_smooth(s::AbstractString)
    s == "auto" && return "auto"
    v = tryparse(Float64, s)
    (v === nothing || v < 0) && error("--smooth must be auto or a standard deviation in km (0: none), not $s")
    return v
end

"""
    run_prepare(source)

Run the preparation of a source, `<source>/prepare.jl` in its own environment (with its
packages installed if needed).
"""
function run_prepare(source::AbstractString)
    dir = joinpath(REPO_DIR, source)
    script = joinpath(dir, "prepare.jl")
    isfile(script) || error("no $script to prepare $source")
    println("Preparing $source: julia --project=$source $source/prepare.jl")
    run(`$(Base.julia_cmd()) --project=$dir -e "import Pkg; Pkg.instantiate()"`)
    run(`$(Base.julia_cmd()) --project=$dir $script`)
end

"""
    remap_dataset(dataset, args=String[]; overwrite=false) -> Vector{String}

Remap the products of a thematic dataset (<Dataset>/remap.toml) onto the grids of
their domains: all products, or those named in `args`, on all their grids, or on the
domains and grids named in `args`. A prepared file that is missing is made first by
the prepare.jl of its source. Every grid must be covered by the source.
"""
function remap_dataset(dataset::AbstractString, args=String[]; overwrite::Bool=false)
    products = remap_products(dataset)
    names = [p.name for p in products]
    chosen = filter(in(names), args)
    targets = setdiff(args, chosen)
    selected = isempty(chosen) ? products : filter(p -> p.name in chosen, products)
    only_grids = isempty(targets) ? nothing : Set(og.grid.name for og in select_grids(targets))
    tag = remap_tag(dataset)
    paths = String[]
    for p in selected
        grids = [og for key in domain_keys() for og in Domain(key).grids if og.folder in p.domains]
        only_grids === nothing || filter!(og -> og.grid.name in only_grids, grids)
        isempty(grids) && continue
        isfile(prepared_file(p)) || run_prepare(p.source)
        prep = read_prepared(prepared_file(p); vars=p.variables)
        println("$(product_name(p)): $(join(sort(collect(keys(prep.fields))), ", ")) from $(p.source) " *
                "onto $(length(grids)) grids")
        append!(paths, remap_prepared(prep, grids; name=product_name(p), method=p.method, smooth=p.smooth,
                                      dataset=tag, overwrite, strict=true))
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
    println("$(basename(path)): $(join(sort(collect(keys(p.fields))), ", ")) on a $(_describe(p.grid))")
    println("Remapping onto $(length(grids)) grids as <GRID>_$(nm).nc")
    return remap_prepared(p, grids; name=nm, method=meth, smooth=sm, overwrite)
end

_describe(g::LonLatGrid) = "$(join(size(g), "x")) lon-lat grid ($(g.dlon)° x $(g.dlat)°)"
_describe(g::ProjGrid) = "$(join(size(g), "x")) projected grid ($(spacing(g)[1]) km)"
