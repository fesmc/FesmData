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

The fields of a prepared file on their grid (`LonLatGrid` or `ProjGrid`), with their
extra dimensions (e.g. month, depth), the vector fields among them, their attributes
and the global attributes of the file. A field has size `(nx, ny, extra...)`: Float32
with NaN as missing, or integer (with `missing`).
"""
struct Prepared
    path::String
    grid::Union{LonLatGrid,ProjGrid}
    fields::Dict{String,Array}
    dims::Dict{String,Vector{Dim}}          # extra dimensions of each field
    vectors::Vector{Tuple{String,String}}   # (eastward, northward) components
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

Read the fields of a prepared file: all fields on the grid of the file, or the fields
`vars`. The grid is given by 1D coordinate variables, lon and lat (degrees, -180:180
or 0:360, in any order) or x and y (m or km) with a `grid_mapping` variable holding a
PROJ string (`proj_params` or `proj4`). Latitudes and y may be descending. Fields may
have extra dimensions (with or without coordinate variables), and may be integer.
Vector fields are pairs with the standard names `eastward_*` and `northward_*`.
Missing values (_FillValue, NaN) become NaN, or `missing` in integer fields.
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

        # Fields on the grid: variables with both grid dimensions
        ongrid = String[]
        for (name, v) in ds
            name in (xdim, ydim) && continue
            dn = dimnames(v)
            xdim in dn && ydim in dn && push!(ongrid, name)
        end
        selected = vars === nothing ? ongrid : collect(String, vars)
        for name in selected
            name in ongrid || error("$path: no field $name on the grid, available: $(join(ongrid, ", "))")
        end
        isempty(selected) && error("$path: no fields on the grid")

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
        return Prepared(abspath(path), grid, fields, dims, _vectors(path, fields, dims, varattrib), varattrib, attrib)
    end
end

# Extra dimension `name` of a prepared file, with the raw values and attributes of its
# coordinate variable (indices 1:n if it has none).
function _dim(ds, name)
    if haskey(ds, name) && dimnames(ds[name]) == (name,)
        v = ds[name]
        return Dim(name, Array(v.var), [k => v.attrib[k] for k in keys(v.attrib)])
    end
    return Dim(name, collect(1:ds.dim[name]), Pair{String,Any}[])
end

# Vector fields: pairs of fields with the standard names eastward_<x> and northward_<x>,
# both read, on the same dimensions.
function _vectors(path, fields, dims, varattrib)
    std(name) = string(get(Dict(varattrib[name]), "standard_name", ""))
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

"Conservative remapping of `F` onto `tgt`, exact or with `nsub` samples per cell side (see `con_nsub`)."
remap_con(tgt, src, F; nsub=con_nsub(tgt, src)) = nsub === nothing ? remap(tgt, src, F) : remap(tgt, src, F; nsub)

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
    remap_field(tgt, src, F; method="con", sigma=0, nsub) -> (Ft, f_valid)

2D field `F` on `src` remapped onto `tgt` by `method` (see `METHODS`), then smoothed
with a Gaussian of standard deviation `sigma` (km) if `sigma > 0`. `f_valid` is the
fraction of each cell covered by the source, before smoothing.
"""
function remap_field(tgt, src, F::AbstractMatrix; method::AbstractString="con", sigma::Real=0,
                     nsub=con_nsub(tgt, src))
    Ft, fv = method == "con" ? remap_con(tgt, src, F; nsub) :
             method == "bilinear" ? remap_bilinear(tgt, src, F) :
             error("unknown method $method, available: $(join(METHODS, ", "))")
    return (sigma > 0 ? smooth(tgt, Ft, sigma) : Ft), fv
end

"Largest number of distinct values of an integer field (classes) remapped by dominant class."
const MAX_CLASSES = 1000

"""
    remap_classes(tgt, src, M; nsub, classes) -> (Mt, f_valid)

Class of the 2D integer field `M` covering the largest area of each target cell, from
the conservatively remapped area fraction of each class (ties go to the smaller
class), `missing` where the source has no data; `f_valid` is the fraction of each
cell covered by the source.
"""
function remap_classes(tgt, src, M::AbstractMatrix; nsub=con_nsub(tgt, src), classes=sort(unique(skipmissing(M))))
    Mt = Matrix{Union{Missing,nonmissingtype(eltype(M))}}(missing, size(tgt))
    best = fill(-1.0f0, size(tgt))
    fv = zeros(Float32, size(tgt))
    ind = Matrix{Float32}(undef, size(M))
    for c in classes
        @. ind = ifelse(ismissing(M), NaN32, Float32(coalesce(M == c, false)))
        fr, fv = remap_con(tgt, src, ind; nsub)
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
    remap_array(tgt, src, F; method, sigma, nsub) -> (Ft, f_valid)

Field `F` (size `(nx, ny, extra...)`) remapped onto `tgt` slice by slice: by
`remap_field`, or by `remap_classes` if `F` is integer. `f_valid` has the size of `Ft`.
"""
function remap_array(tgt, src, F::AbstractArray; method::AbstractString, sigma::Real, nsub)
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
        Ft[:, :, I], fv[:, :, I] = isint ? remap_classes(tgt, src, S; nsub, classes) :
                                   remap_field(tgt, src, S; method, sigma, nsub)
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
        for (name, axis) in ((e, "x"), (n, "y"))
            varattrib[name] = vcat(filter(p -> first(p) != "standard_name", varattrib[name]),
                                   ["vector_component" => "along the $axis axis of the grid"])
        end
    end
end

rotate_vectors!(out, varattrib, vectors, ::LonLatGrid) = nothing

# Fraction covered by the source of a remapped field, without the extra dimensions
# when it is the same for all of them.
function _collapse(fv::AbstractArray)
    ndims(fv) == 2 && return fv
    fv1 = fv[:, :, ntuple(_ -> 1, ndims(fv) - 2)...]
    return all(I -> view(fv, :, :, I) == fv1, CartesianIndices(size(fv)[3:end])) ? fv1 : fv
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
    remap_prepared(p, grids; name, method="con", smooth="auto", dataset="remap",
                   overwrite=false, strict=false) -> Vector{String}

Remap the fields of `p` onto each grid (see `remap_array` and `smoothing_sigma`) and
write them to `<GRID>_<name>.nc` in its output folder, with `f_valid`, the area
fraction of each cell covered by source data (`f_valid_<field>` for each field when
their coverage differs; with the extra dimensions when it differs between them).
Vector fields are rotated to the axes of projected grids. Grids not covered by the
source are skipped (an error if `strict`). The grid files are written if missing.
Existing files are kept unless `overwrite`. `dataset` is the dataset of the
provenance attributes.
"""
function remap_prepared(p::Prepared, grids::Vector{OutGrid}; name::AbstractString, method::AbstractString="con",
                        smooth="auto", dataset::AbstractString="remap", overwrite::Bool=false, strict::Bool=false)
    method in METHODS || error("unknown method $method, available: $(join(METHODS, ", "))")
    paths = String[]
    names = sort(collect(keys(p.fields)))
    integers = any(f -> nonmissingtype(eltype(p.fields[f])) <: Integer, names)
    for og in grids
        path = remap_file(og, name)
        if isfile(path) && !overwrite
            println("$(og.grid.name): exists, skipped (--overwrite to replace)")
            continue
        end
        sigma = smoothing_sigma(method, smooth, og.grid, p.grid)
        nsub = con_nsub(og.grid, p.grid)
        t = @elapsed out = Dict(f => remap_array(og.grid, p.grid, p.fields[f]; method, sigma, nsub) for f in names)
        if all(f -> all(iszero, out[f][2]), names)
            strict && error("$(og.grid.name) is not covered by $(basename(p.path))")
            println("$(og.grid.name): not covered by the source, skipped")
            continue
        end
        varattrib = copy(p.varattrib)
        rotate_vectors!(out, varattrib, p.vectors, og.grid)
        fields = Dict{String,Array}(f => out[f][1] for f in names)
        dims = copy(p.dims)
        fvs = Dict(f => _collapse(out[f][2]) for f in names)
        if allequal(fvs[f] for f in names)
            fields["f_valid"] = fvs[names[1]]
            dims["f_valid"] = ndims(fvs[names[1]]) > 2 ? p.dims[names[1]] : Dim[]
        else
            for f in names
                fields["f_valid_$f"] = fvs[f]
                dims["f_valid_$f"] = ndims(fvs[f]) > 2 ? p.dims[f] : Dim[]
                varattrib["f_valid_$f"] = ["units" => "1", "long_name" => "area fraction covered by $f"]
            end
        end
        how = method_description(method, sigma; integers)
        attrib = vcat(p.attrib, ["remapped_from" => basename(p.path), "remap_method" => how])
        isfile(joinpath(outdir(og), "$(og.grid.name)_grid.nc")) || write_grid_files(outdir(og), og.grid; dataset)
        write_fields(path, og.grid, fields; dataset, attrib, varattrib, dims)
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
