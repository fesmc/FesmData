# Ocean and sea-ice fields of CMIP model output (PMIP3_cmip5, PMIP4_cmip6) on a common
# regular 1° grid: monthly SST and sea-ice concentration climatologies, sea-ice extent,
# annual mean potential temperature at standard depths, and the Atlantic meridional
# overturning streamfunction. Fields on the model's ocean (or sea-ice) grid are averaged in
# time on that grid and remapped with cdo (conservatively where the grid has cell bounds,
# else bilinearly). Needs cmip_climatology.jl (and Dates, NCDatasets) and cdo in the PATH
# (on Albedo: module load cdo).

using Dates
using NCDatasets

"The common grid: cell centres in longitude (0.5..359.5) and latitude (-89.5..89.5) [°]."
const OCEAN_LON = collect(0.5:1.0:359.5)
const OCEAN_LAT = collect(-89.5:1.0:89.5)
"Depths [m] of the annual mean potential temperature `to_ann`."
const TO_DEPTHS = [5.0, 50, 100, 200, 300, 500, 700, 1000, 1500, 2000]
"Depths [m] of the overturning streamfunction `amoc` (with the latitudes OCEAN_LAT)."
const MOC_DEPTHS = collect(0.0:100.0:6000.0)
"Sea-ice concentration threshold of the extent (fraction)."
const SI_THRESHOLD = 0.15
"Latitudes [°N] and least depth [m] of the AMOC maximum `amoc_max`."
const AMOC_MAX_LAT = (20.0, 60.0)
const AMOC_MAX_DEPTH = 500.0

"cdo grid description of the common grid, written to `dir`."
function target_grid(dir)
    path = joinpath(dir, "grid_1deg.txt")
    write(path, """
        gridtype = lonlat
        xsize    = $(length(OCEAN_LON))
        ysize    = $(length(OCEAN_LAT))
        xfirst   = $(first(OCEAN_LON))
        xinc     = 1.0
        yfirst   = $(first(OCEAN_LAT))
        yinc     = 1.0
        """)
    return path
end

"The horizontal dimensions (Julia order) of the variable `name`: all but time (unless `time` false: fx fields) and, for 3-D fields, the level dimension."
function horizontal_dims(ds, name; vertical=false, time=true)
    dn = collect(dimnames(ds[name]))
    time || return dn
    dn[end] == "time" || error("$name: time is not the last dimension ($dn)")
    return vertical ? dn[1:end-2] : dn[1:end-1]
end

"The variable with standard name `std` (latitude or longitude) of the field `name`: from its `coordinates` attribute, else a coordinate variable of one of its dimensions (by standard name, name, or units)."
function coordinate_var(ds, name, std)
    cands = split(get(ds[name].attrib, "coordinates", ""))
    append!(cands, dimnames(ds[name]))
    append!(cands, std == "latitude" ? ["lat", "latitude", "nav_lat"] : ["lon", "longitude", "nav_lon"])
    for c in cands
        haskey(ds, c) && get(ds[c].attrib, "standard_name", "") == std && return c
    end
    for c in cands
        haskey(ds, c) && c in (std == "latitude" ? ("lat", "latitude", "nav_lat") : ("lon", "longitude", "nav_lon")) && return c
    end
    for c in cands          # units only (POP: TLAT, TLONG)
        haskey(ds, c) && get(ds[c].attrib, "units", "") == (std == "latitude" ? "degrees_north" : "degrees_east") && return c
    end
    error("$name: no $std variable")
end

"Latitude [°N] of each cell of the horizontal grid of `name` (an array of the size of that grid)."
function native_lat(ds, name; vertical=false, time=true)
    hd = horizontal_dims(ds, name; vertical, time)
    hsize = Tuple(ds.dim[d] for d in hd)
    c = coordinate_var(ds, name, "latitude")
    lat = Float64.(coalesce.(Array(ds[c]), NaN))
    lat[abs.(lat) .> 90] .= NaN                 # fill values (land cells of some sea-ice grids)
    cd = collect(dimnames(ds[c]))
    cd == hd && return lat
    if length(cd) == 1 && cd[1] in hd        # regular grid: lat(lat)
        k = findfirst(==(cd[1]), hd)
        return repeat(reshape(lat, ntuple(i -> i == k ? length(lat) : 1, length(hd))),
                      outer=ntuple(i -> i == k ? 1 : hsize[i], length(hd)))
    end
    error("$name: latitude $c$(Tuple(cd)) not on the grid $(Tuple(hd))")
end

"Whether the latitude of the grid of `name` has cell bounds (conservative remapping)."
function has_bounds(ds, name)
    c = coordinate_var(ds, name, "latitude")
    b = get(ds[c].attrib, "bounds", "")
    return !isempty(b) && haskey(ds, b)
end

"""
    remap_1deg(src, name, F, extra, workdir; vertical=false) -> (G, method)

Remap the field `F`, on the horizontal grid of the variable `name` of the file `src`
(its dimensions first, then one extra dimension: `extra` = :month or the depths of the
levels), to the common 1° grid with cdo: remapcon if the grid has cell bounds, else
remapbil. Returns the field on the common grid (lon × lat × extra, NaN where undefined)
and the cdo operator.
"""
function remap_1deg(src, name, F, extra, workdir; vertical=false)
    tin, tout = joinpath(workdir, "native.nc"), joinpath(workdir, "remapped.nc")
    rm.((tin, tout); force=true)
    method = NCDataset(src) do ds
        hd = horizontal_dims(ds, name; vertical)
        own = collect(dimnames(ds[name]))
        NCDataset(tin, "c") do out
            # the grid: the coordinate variables of the horizontal dimensions, latitude and
            # longitude, and their cell bounds
            grid = [filter(d -> haskey(ds, d), hd); coordinate_var(ds, name, "latitude"); coordinate_var(ds, name, "longitude")]
            append!(grid, [ds[c].attrib["bounds"] for c in grid if haskey(ds[c].attrib, "bounds")])
            for k in unique(filter(c -> haskey(ds, c), grid))
                v = ds[k]
                dn = collect(dimnames(v))
                all(d -> d in hd || !(d in own), dn) || continue
                for d in dn
                    haskey(out.dim, d) || defDim(out, d, ds.dim[d])
                end
                atts = [a => v.attrib[a] for a in keys(v.attrib) if !(a in ("_FillValue", "missing_value"))]
                defVar(out, k, Array(v.var), dn; attrib=atts)
            end
            if extra === :month       # as a time axis, which cdo keeps
                defDim(out, "time", Inf)
                defVar(out, "time", Float64.(15:30:345), ("time",); attrib=["units" => "days since 2001-01-01", "calendar" => "360_day", "axis" => "T"])
                xd = "time"
            else
                defVar(out, "depth", Float64.(extra), ("depth",); attrib=["units" => "m", "positive" => "down", "axis" => "Z", "standard_name" => "depth"])
                xd = "depth"
            end
            atts = Pair{String,Any}["_FillValue" => 1f20, "missing_value" => 1f20]
            coords = filter(c -> haskey(out, c), split(get(ds[name].attrib, "coordinates", "")))
            isempty(coords) || push!(atts, "coordinates" => join(coords, " "))
            defVar(out, name, Float32.(replace(F, NaN => 1f20)), (hd..., xd); attrib=atts)
        end
        has_bounds(ds, name) ? "remapcon" : "remapbil"
    end
    run(`cdo -s -f nc4 $method,$(target_grid(workdir)) $tin $tout`)
    G = NCDataset(tout) do ds
        A = Float64.(coalesce.(ds[name][:, :, :], NaN))
        A[abs.(A) .>= 1e19] .= NaN
        A
    end
    size(G)[1:2] == (length(OCEAN_LON), length(OCEAN_LAT)) || error("$name: remapped to $(size(G))")
    return G, method
end

"Whether the level dimension of the 3-D field `name` of the file is a depth (not e.g. density)."
function is_depth_axis(file, name)
    NCDataset(file) do ds
        try
            level_depths(ds, collect(dimnames(ds[name]))[end-1])
            true
        catch
            false
        end
    end
end

"Nominal depth [m] of the levels of the vertical dimension `z` (zlev of ocean_sigma_z, cm converted)."
function level_depths(ds, z)
    v = ds[z]
    if get(v.attrib, "standard_name", "") == "ocean_sigma_z" && haskey(ds, "zlev")
        return abs.(Float64.(ds["zlev"][:]))      # positive down (MIROC-ES2L: negative)
    end
    units = lowercase(get(v.attrib, "units", ""))
    units in ("m", "meter", "meters", "metre", "metres") && return Float64.(v[:])
    units in ("cm", "centimeter", "centimeters", "centimetre", "centimetres") && return Float64.(v[:]) ./ 100
    error("level $z: not a depth (units \"$units\")")
end

"""
    last_years(files, nyears) -> (records, years)

The time records of the last `nyears` complete years of `files` (all if fewer; not
necessarily contiguous: pools may hold scattered years of 3-D fields), and the first and
last year and the number of years.
"""
function last_years(files, nyears)
    recs = time_records(files)
    complete = sort(complete_years(recs))
    isempty(complete) && error("no complete year in $(join(basename.(files), ", "))")
    ys = complete[max(1, end - nyears + 1):end]
    return filter(r -> r.year in ys, recs), (first(ys), last(ys), length(ys))
end

"To degC, from K if the field is in kelvin (values below 100 K, e.g. 0 over land in MRI-CGCM3, undefined)."
to_degc(F, units) = lowercase(units) in ("k", "kelvin") ? map(x -> x < 100 ? NaN : x - 273.15, F) : F

"""
    sst_mon(files, workdir; nyears, name="tos") -> fields

Monthly SST climatology [degC] of `name` (tos) over the last `nyears` years, on the common grid.
"""
function sst_mon(files, workdir; nyears, name="tos")
    units = NCDataset(ds -> get(ds[name].attrib, "units", "degC"), first(files))
    M, _, years = monthly_climatology(files, name, nyears)
    G, method = remap_1deg(first(files), name, to_degc(M, units), :month, workdir)
    return [(name="sst_mon", data=G, dims=("lon", "lat", "month"), units="degC",
             long_name="sea surface temperature, monthly mean", years, source=name, remap=method, files)]
end

"""
    sea_ice(files, name, areafile, workdir; nyears) -> fields

Monthly sea-ice concentration climatology (fraction) of `name` (sic, siconc or siconca) over
the last `nyears` years and the monthly extent mask (concentration >= 15 %) on the common
grid, and the monthly sea-ice extent of each hemisphere [10^6 km2] on the native grid: the
mean over the years of the area of the cells with concentration >= 15 %, with the cell areas
of `areafile` (areacello; `nothing` or another grid: cdo gridarea; or given as a tuple
(areas [m2], description)).
"""
function sea_ice(files, name, areafile, workdir; nyears)
    M, _, years = monthly_climatology(files, name, nyears)
    scale = maximum(filter(isfinite, M)) > 1.5 ? 0.01 : 1.0          # % or fraction
    ind, _, _ = monthly_climatology(files, name, nyears; y1=years[2],
                                    transform=x -> isnan(x) ? 0.0 : Float64(x * scale >= SI_THRESHOLD))
    hsize = size(M)[1:end-1]
    area, areasrc = cell_area(first(files), name, areafile, workdir)
    lat = NCDataset(ds -> native_lat(ds, name), first(files))
    ext(sel) = [sum(area[i] * ind[i, m] for i in CartesianIndices(hsize) if sel(lat[i]) && isfinite(area[i]); init=0.0) / 1e12
                for m in 1:12]
    nh, sh = ext(>(0)), ext(<(0))
    G, method = remap_1deg(first(files), name, M .* scale, :month, workdir)
    G = clamp.(G, 0, 1)
    E = map(x -> isnan(x) ? NaN : Float64(x >= SI_THRESHOLD), G)
    common = (; years, source=name, files)
    return [(name="sic_mon", data=G, dims=("lon", "lat", "month"), units="1",
             long_name="sea-ice area fraction, monthly mean", remap=method, common...),
            (name="siext_mon", data=E, dims=("lon", "lat", "month"), units="1",
             long_name="sea-ice extent mask (monthly mean sea-ice area fraction >= $SI_THRESHOLD)", remap=method, common...),
            (name="siextent_nh", data=nh, dims=("month",), units="1e6 km2",
             long_name="Northern Hemisphere sea-ice extent (area of the cells with sea-ice area fraction >= $SI_THRESHOLD), monthly mean",
             cell_area=areasrc, march=nh[3], september=nh[9], common...),
            (name="siextent_sh", data=sh, dims=("month",), units="1e6 km2",
             long_name="Southern Hemisphere sea-ice extent (area of the cells with sea-ice area fraction >= $SI_THRESHOLD), monthly mean",
             cell_area=areasrc, march=sh[3], september=sh[9], common...)]
end

"""
    cell_area(file, name, areafiles, workdir) -> (area, description)

Cell areas [m2] of the native grid of the field `name` of `file`: areacello of the first of
`areafiles` (a file, a list, e.g. the run's own and those of the other experiments of the
model, or nothing) that is on that grid, by latitude (or on that grid with one more row at
the end: the duplicated fold row of NorESM2); else from the cell bounds of `file` (cdo
gridarea); else approximated from the cell centres. Given areas: a tuple (areas, description).
"""
cell_area(file, name, area::Tuple, workdir) = area

function cell_area(file, name, areafiles, workdir)
    lat, lon = NCDataset(ds -> (native_lat(ds, name), native_lon(ds, name)), file)
    hsize = size(lat)
    for areafile in (areafiles === nothing ? String[] : areafiles isa AbstractString ? [areafiles] : areafiles)
        A, alat = NCDataset(areafile) do ds
            Float64.(coalesce.(Array(ds["areacello"]), NaN)), native_lat(ds, "areacello"; time=false)
        end
        if size(A) != hsize && length(hsize) == 2 && size(A) == (hsize[1], hsize[2] + 1)
            A, alat = A[:, 1:end-1], alat[:, 1:end-1]
        end
        if size(A) == hsize && size(alat) == hsize
            ok = isfinite.(lat) .& isfinite.(alat)
            maximum(abs.(lat[ok] .- alat[ok]); init=0.0) < 0.01 && return A, "areacello ($(basename(areafile)))"
        end
    end
    earth = 4pi * 6.371e6^2
    out = joinpath(workdir, "gridarea.nc")
    rm(out; force=true)
    try
        run(pipeline(`cdo -s gridarea $file $out`; stderr=devnull))
        A = NCDataset(ds -> Float64.(Array(ds["cell_area"])), out)
        A[.!isfinite.(lat)] .= NaN
        size(A) == hsize && sum(filter(isfinite, A)) < 1.01 * earth &&
            return A, "cdo gridarea (cell bounds of the sea-ice grid)"
    catch
    end
    A = centre_area(lat, lon)
    sum(filter(isfinite, A)) < 1.05 * earth || error("$file: no cell areas")
    return A, "approximated from the cell centres (no areacello, no cell bounds)"
end

"Longitude [°E] of each cell of the horizontal grid of `name` (as native_lat)."
function native_lon(ds, name)
    c = coordinate_var(ds, name, "longitude")
    lon = Float64.(coalesce.(Array(ds[c]), NaN))
    lon[abs.(lon) .> 720] .= NaN
    collect(dimnames(ds[c])) == horizontal_dims(ds, name) && return lon
    lat = native_lat(ds, name)                 # regular grid: lon(lon)
    k = findfirst(==(only(dimnames(ds[c]))), horizontal_dims(ds, name))
    return repeat(reshape(lon, ntuple(i -> i == k ? length(lon) : 1, ndims(lat))),
                  outer=ntuple(i -> i == k ? 1 : size(lat, i), ndims(lat)))
end

"""
    centre_area(lat, lon) -> area

Cell areas [m2] of a logically rectangular grid approximated from its cell centres: the
area of the parallelogram spanned by the centred differences of the centre positions along
the two grid directions (one-sided at the edges, longitudes periodic in the first).
"""
function centre_area(lat, lon)
    ndims(lat) == 2 || error("cell areas from the centres: not a logically rectangular grid")
    R = 6.371e6
    P = [R .* [cosd(la) * cosd(lo), cosd(la) * sind(lo), sind(la)] for (la, lo) in zip(lat, lon)]
    ni, nj = size(lat)
    A = fill(NaN, ni, nj)
    for j in 1:nj, i in 1:ni
        di = (P[mod1(i + 1, ni), j] .- P[mod1(i - 1, ni), j]) ./ 2
        dj = (P[i, min(j + 1, nj)] .- P[i, max(j - 1, 1)]) ./ (min(j + 1, nj) - max(j - 1, 1))
        c = [di[2] * dj[3] - di[3] * dj[2], di[3] * dj[1] - di[1] * dj[3], di[1] * dj[2] - di[2] * dj[1]]
        A[i, j] = sqrt(sum(abs2, c))
    end
    return A
end

"""
    to_ann(files, workdir; nyears, name="thetao") -> fields

Annual mean potential temperature [degC] of `name` (thetao) over the last `nyears` years at the
depths TO_DEPTHS: averaged on the native levels (down to the first at or below the deepest
depth), interpolated linearly in depth on the native grid (the top value above the first
level, undefined below the last defined level), and remapped to the common grid.
"""
function to_ann(files, workdir; nyears, name="thetao")
    sel, years = last_years(files, nyears)
    S = W = nothing
    z = Float64[]
    units = "degC"
    for f in unique(r.file for r in sel)
        NCDataset(f) do ds
            v = ds[name]
            units = get(v.attrib, "units", "degC")
            zall = level_depths(ds, collect(dimnames(v))[end-1])
            K = something(findfirst(>=(maximum(TO_DEPTHS)), zall), length(zall))
            z = zall[1:K]
            for r in filter(r -> r.file == f, sel)
                A = Float64.(coalesce.(v[ntuple(_ -> Colon(), ndims(v) - 2)..., 1:K, r.i], NaN))
                if S === nothing
                    S, W = zeros(size(A)), zeros(size(A))
                end
                ok = isfinite.(A)
                S[ok] .+= A[ok] .* r.days
                W[ok] .+= r.days
            end
        end
    end
    T = to_degc(S ./ W, units)                     # NaN where never defined
    hsize = size(T)[1:end-1]
    T = reshape(T, :, length(z))
    D = fill(NaN, size(T, 1), length(TO_DEPTHS))
    for c in axes(T, 1), (j, d) in enumerate(TO_DEPTHS)
        if d <= z[1]
            D[c, j] = T[c, 1]
        elseif d <= z[end]
            k = searchsortedlast(z, d)
            k == length(z) && (D[c, j] = T[c, k]; continue)
            w = (d - z[k]) / (z[k+1] - z[k])
            D[c, j] = (1 - w) * T[c, k] + w * T[c, k+1]      # NaN if either level is undefined
        end
    end
    G, method = remap_1deg(first(files), name, reshape(D, hsize..., length(TO_DEPTHS)), TO_DEPTHS, workdir; vertical=true)
    return [(name="to_ann", data=G, dims=("lon", "lat", "depth"), units="degC",
             long_name="sea water potential temperature, annual mean", years, source=name,
             remap="linear in depth on the native grid, then $method", files)]
end

"The index of the Atlantic (atlantic_arctic_ocean; POP: Atlantic Ocean + ...) along the basin dimension `bd`."
function atlantic_index(ds, bd)
    for (k, v) in ds
        dn = collect(dimnames(v))       # names: (strlen, basin) characters, or strings
        dn == [bd] || (length(dn) == 2 && dn[2] == bd) || continue
        if eltype(v.var) <: Union{Char,AbstractString}
            A = Array(v.var)
            names = A isa AbstractMatrix ? [strip(String(filter(!=('\0'), A[:, j]))) for j in axes(A, 2)] : strip.(string.(A))
            i = findfirst(n -> occursin("atlantic", lowercase(n)), names)
            i === nothing || return i
        end
    end
    if haskey(ds, bd)      # integer basin coordinate, its values named in an attribute
        vals = ds[bd][:]
        for a in values(ds[bd].attrib)
            a isa AbstractString || continue
            m = something(match(r"atlantic\w*\s*=\s*(\d+)"i, a), match(r"(\d+)\s*=\s*atlantic"i, a), Some(nothing))
            m === nothing && continue
            i = findfirst(==(parse(Int, m[1])), vals)
            i === nothing || return i
        end
    end
    error("no Atlantic basin along $bd")
end

"""
    amoc(files, name; nyears, latfile=nothing) -> fields

The Atlantic meridional overturning streamfunction [Sv] of `name` (msftmyz, msftmz or
msftyz) averaged over the last `nyears` years: on the common latitudes × MOC_DEPTHS
(interpolated linearly from the model's own latitude and depth axes), and its maximum below
AMOC_MAX_DEPTH between the latitudes AMOC_MAX_LAT (on the model's axes). Where the latitude
axis of the files is invalid, that of `latfile` (the same variable on the same grid, e.g.
of the piControl run; EC-Earth3 midHolocene) is taken.
"""
function amoc(files, name; nyears, latfile=nothing)
    M, days, years = monthly_climatology(files, name, nyears)
    A = sum(selectdim(M, ndims(M), m) .* days[m] for m in 1:12) ./ sum(days)
    lat, z, P = NCDataset(first(files)) do ds
        dn = collect(dimnames(ds[name]))       # ([x,] lat, lev, basin, time)
        P = selectdim(A, length(dn) - 1, atlantic_index(ds, dn[end-1]))
        size(P)[1:end-2] == ntuple(_ -> 1, ndims(P) - 2) || error("$name: more than one column ($(size(P)))")
        moc_lat(ds, name), level_depths(ds, dn[end-2]), reshape(P, size(P, ndims(P) - 1), size(P, ndims(P)))
    end
    notes = String[]
    if !valid_lat(lat)
        latfile === nothing && error("$name: invalid latitude axis")
        lat = NCDataset(ds -> moc_lat(ds, name), latfile)
        valid_lat(lat) && length(lat) == size(P, 1) || error("$name: invalid latitude axis, also in $(basename(latfile))")
        push!(notes, "latitudes of $(basename(latfile)) (the latitude axis of the files is invalid)")
    end
    P = P ./ 1e9                                                    # kg s-1 to Sv
    if maximum(abs, filter(isfinite, P)) < 1e-3     # CNRM-CM5: "1035*(zomsfatl)", 1035 × Sv given as kg s-1
        P .*= 1e9 / 1035
        push!(notes, "values given in the file as 1035 × Sv (original_name " *
                     "$(NCDataset(ds -> get(ds[name].attrib, "original_name", ""), first(files)))), divided by 1035")
    end
    return amoc_fields(lat, z, P, years, name, files; note=isempty(notes) ? nothing : join(notes, "; "))
end

"The latitudes of the overturning streamfunction `name`: its latitude dimension, or (IPSL) nav_lat(x = 1, y)."
function moc_lat(ds, name)
    yd = collect(dimnames(ds[name]))[end-3]
    haskey(ds, yd) && ndims(ds[yd]) == 1 && startswith(get(ds[yd].attrib, "units", ""), "degree") &&
        return Float64.(ds[yd][:])
    return Float64.(vec(ds[coordinate_var(ds, name, "latitude")][:, :]))
end

"Whether `lat` is a latitude axis: within ±90° and spanning more than 10°."
valid_lat(lat) = all(l -> -90 <= l <= 90, lat) && maximum(lat) - minimum(lat) > 10

"""
    amoc_fields(lat, z, P, years, source, files) -> fields

The fields `amoc` and `amoc_max` of the Atlantic overturning streamfunction `P` [Sv] on
the model's latitudes `lat` and depths `z` [m] (see amoc).
"""
function amoc_fields(lat, z, P, years, source, files; note=nothing)
    o = sortperm(lat)
    lat, P = lat[o], P[o, :]
    sel = [AMOC_MAX_LAT[1] <= lat[i] <= AMOC_MAX_LAT[2] && z[k] >= AMOC_MAX_DEPTH && isfinite(P[i, k])
           for i in eachindex(lat), k in eachindex(z)]
    pmax = any(sel) ? maximum(P[sel]) : NaN
    G = interp2(lat, z, P, OCEAN_LAT, MOC_DEPTHS)
    common = note === nothing ? (; years, source, files) : (; years, source, files, comment=note)
    return [(name="amoc", data=G, dims=("lat", "depth_moc"), units="Sv",
             long_name="Atlantic meridional overturning streamfunction, annual mean", common...),
            (name="amoc_max", data=pmax, dims=(), units="Sv",
             long_name="maximum of the Atlantic overturning streamfunction below $(Int(AMOC_MAX_DEPTH)) m between $(Int(AMOC_MAX_LAT[1])) and $(Int(AMOC_MAX_LAT[2])) N",
             common...)]
end

"Linear interpolation of P(x, y) to the points xi × yi (NaN outside the axes or next to undefined values)."
function interp2(x, y, P, xi, yi)
    function weights(a, t)
        (t < a[1] || t > a[end]) && return nothing
        k = clamp(searchsortedlast(a, t), 1, length(a) - 1)
        length(a) == 1 && return (1, 1, 0.0)
        return (k, k + 1, (t - a[k]) / (a[k+1] - a[k]))
    end
    G = fill(NaN, length(xi), length(yi))
    for (i, s) in enumerate(xi), (j, t) in enumerate(yi)
        wx, wy = weights(x, s), weights(y, t)
        (wx === nothing || wy === nothing) && continue
        (i0, i1, a), (j0, j1, b) = wx, wy
        v = (1 - a) * (1 - b) * P[i0, j0] + a * (1 - b) * P[i1, j0] + (1 - a) * b * P[i0, j1] + a * b * P[i1, j1]
        G[i, j] = v
    end
    return G
end

"The years of a field: first-last, and the number of years if they are not contiguous."
function years_attrib(y)
    s = "$(y[1])-$(y[2])"
    length(y) == 3 && y[3] != y[2] - y[1] + 1 && (s *= " ($(y[3]) complete years)")
    return s
end

"""
    write_ocean(path, fields, attrib)

Write the ocean fields (named tuples: name, data, dims, units, long_name, years, source,
files, and optionally remap, cell_area, march, september, comment) on the common grid, with the
global attributes `attrib` (pairs).
"""
function write_ocean(path, fields, attrib)
    NCDataset(path, "c") do ds
        defVar(ds, "lon", OCEAN_LON, ("lon",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
        defVar(ds, "lat", OCEAN_LAT, ("lat",); attrib=["units" => "degrees_north", "standard_name" => "latitude"])
        defVar(ds, "month", Int32.(1:12), ("month",); attrib=["units" => "1", "long_name" => "month of the year"])
        defVar(ds, "depth", TO_DEPTHS, ("depth",); attrib=["units" => "m", "positive" => "down", "standard_name" => "depth"])
        defVar(ds, "depth_moc", MOC_DEPTHS, ("depth_moc",); attrib=["units" => "m", "positive" => "down", "standard_name" => "depth",
                                                                  "long_name" => "depth of the overturning streamfunction"])
        for f in fields
            atts = Pair{String,Any}["units" => f.units, "long_name" => f.long_name, "years" => years_attrib(f.years),
                    "source_variable" => f.source, "original_data" => join(unique(dirname.(f.files)), " ")]
            haskey(f, :remap) && push!(atts, "remapping" => f.remap)
            haskey(f, :cell_area) && push!(atts, "cell_area" => f.cell_area)
            haskey(f, :comment) && push!(atts, "comment" => f.comment)
            haskey(f, :march) && push!(atts, "march" => Float32(f.march), "september" => Float32(f.september))
            if f.dims == ()        # scalar: no compression
                defVar(ds, f.name, fill(Float32(f.data)), (); fillvalue=NaN32, attrib=atts)
            else
                defVar(ds, f.name, Float32.(f.data), f.dims; fillvalue=NaN32, deflatelevel=1, attrib=atts)
            end
        end
        foreach(((k, v),) -> ds.attrib[k] = v, attrib)
    end
end

"The ocean field names written by prepare_ocean (for the global attribute `missing`)."
const OCEAN_FIELDS = Dict("tos" => ["sst_mon"], "sic" => ["sic_mon", "siext_mon", "siextent_nh", "siextent_sh"],
                          "thetao" => ["to_ann"], "msft" => ["amoc", "amoc_max"])

"""
    ocean_fields(src, workdir; nyears, nyears_thetao) -> (fields, missing)

All ocean fields of a model run from its files `src` (a Dict: "tos", "sic" (with the
variable name in "sic_name"), "thetao", "msft" (with "msft_name", and optionally
"msft_latfile", see amoc) => files, and "areacello" => areacello files, see cell_area). A field without
files, or whose preparation fails (the error is printed), is named in `missing`.
"""
function ocean_fields(src, workdir; nyears, nyears_thetao)
    fields, missing_ = [], String[]
    for (key, make) in (("tos", fs -> sst_mon(fs, workdir; nyears)),
                        ("sic", fs -> sea_ice(fs, src["sic_name"], src["areacello"], workdir; nyears)),
                        ("thetao", fs -> to_ann(fs, workdir; nyears=nyears_thetao)),
                        ("msft", fs -> amoc(fs, src["msft_name"]; nyears, latfile=get(src, "msft_latfile", nothing))))
        fs = get(src, key, String[])
        if isempty(fs)
            append!(missing_, OCEAN_FIELDS[key])
            continue
        end
        try
            append!(fields, make(fs))
        catch e
            println("  $key: ", sprint(showerror, e)[1:min(end, 400)])
            append!(missing_, OCEAN_FIELDS[key])
        end
    end
    return fields, missing_
end
