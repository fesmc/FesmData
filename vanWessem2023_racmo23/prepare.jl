# Prepare the RACMO2.3p2 Antarctic surface mass balance and surface climate (van Wessem
# et al., 2023 data release; monthly fields 1979-2022 on the 27 km rotated-pole grid
# ANT27) for remapping: monthly climatologies 1981-2010 and 1991-2020 (x, y, month) and
# annual values 1979-2022 (x, y, time), with the surface elevation and masks, in
# $FESMDATA_WORK/prepared/vanWessem2023_racmo23/.
#
# The rotated-pole grid is regular in rotated longitude and latitude (0.25°). It is
# written as x, y = R * rotated lon, lat (radians), R = 6371229 m, i.e. an equidistant
# cylindrical projection on the rotated sphere (PROJ ob_tran with o_proj=eqc): the
# same cells, without regridding.
#
# Usage:
#     julia --project=vanWessem2023_racmo23 vanWessem2023_racmo23/prepare.jl

using Dates
using NCDatasets
using Statistics

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

const SOURCE = "vanWessem2023_racmo23"
const YEARS = 1979:2022
const PERIODS = (1981:2010, 1991:2020)
const DAYS_PER_YEAR = 365.25

# Earth radius of RACMO (m) and the PROJ string of the grid (x, y in m)
const R_EARTH = 6371229.0
const PROJ = "+proj=ob_tran +o_proj=eqc +o_lat_p=-180.0 +lon_0=10.0 +R=6371229 +units=m"

# Monthly fields: name in the prepared file => (source key and variable, kind, long name),
# with the names of the RACMO2.4p1 products (vanDalum2025_racmo24). :flux are monthly
# sums (kg m-2 per month) and become rates in kg m-2 yr-1; :mean are monthly means (K).
# Fields marked glaciated are meaningful on glaciated surfaces only and are set missing
# where f_ice < F_ICE_MIN (RACMO2.3p2 gives smb near zero and subl over the ocean there).
const FIELDS = [
    "smb"    => (var="smb",      file="smb_monthlyS",      kind=:flux, glaciated=true,  long_name="surface mass balance"),
    "pr"     => (var="precip",   file="precip_monthlyS",   kind=:flux, glaciated=false, long_name="total precipitation"),
    "sf"     => (var="snowfall", file="snowfall_monthlyS", kind=:flux, glaciated=false, long_name="snowfall (solid precipitation)"),
    "runoff" => (var="runoff",   file="runoff_monthlyS",   kind=:flux, glaciated=true,  long_name="meltwater runoff"),
    "melt"   => (var="snowmelt", file="snowmelt_monthlyS", kind=:flux, glaciated=true,  long_name="snow and ice melt"),
    "subl"   => (var="subl",     file="subl_monthlyS",     kind=:flux, glaciated=true,
                 long_name="sublimation (negative) and deposition (positive), including drifting snow"),
    "t2m"    => (var="t2m",      file="t2m_monthlyA",      kind=:mean, glaciated=false, long_name="near-surface (2 m) air temperature"),
    "T_srf"  => (var="tskin",    file="tskin_monthlyA",    kind=:mean, glaciated=false, long_name="surface (skin) temperature"),
]

const FLUX_UNITS = "kg m-2 yr-1"
const F_ICE_MIN = 0.1f0

# ---------------------------------------------------------------------------
# Original data
# ---------------------------------------------------------------------------

db = manifest()
path_of(key) = download_dataset(db, "racmo23p2_ant27_$key")

hgt = NCDataset(path_of("height"))
rlon = round.(Float64.(hgt["rlon"][:]); digits=6)
rlat = round.(Float64.(hgt["rlat"][:]); digits=6)
nx, ny = length(rlon), length(rlat)
dimnames(hgt["mask2d"]) == ("rlon", "rlat") || error("unexpected dimensions of mask2d")
f_ice = Float32.(hgt["mask2d"][:, :])
z_srf = Float32.(hgt["height"][:, :])
mask_grounded = Int32.(nomissing(hgt["maskgrounded2d"][:, :], 0.0))
close(hgt)
x = R_EARTH .* deg2rad.(rlon)
y = R_EARTH .* deg2rad.(rlat)
glaciated = f_ice .>= F_ICE_MIN

# Monthly field of the source, all years: (rlon, rlat, month, year) in Float64
function read_monthly(f)
    ds = NCDataset(path_of(first(split(f.file, "_"))))
    v = ds[f.var]
    dimnames(v) == ("rlon", "rlat", "height", "time") || error("unexpected dimensions of $(f.var)")
    round.(Float64.(ds["rlon"][:]); digits=6) == rlon && round.(Float64.(ds["rlat"][:]); digits=6) == rlat ||
        error("$(f.var): grid differs from Height_latlon_ANT27.nc")
    time = ds["time"][:]
    [(year(t), month(t)) for t in time] == [(y, m) for y in YEARS for m in 1:12] ||
        error("$(f.var): time axis is not monthly $(first(YEARS))-$(last(YEARS))")
    A = Array{Float64}(undef, nx, ny, 12, length(YEARS))
    for (k, yr) in enumerate(YEARS)
        A[:, :, :, k] = nomissing(v[:, :, 1, (k-1)*12+1:k*12], NaN)
    end
    close(ds)
    any(isnan, A) && error("$(f.var) has missing values")
    return A
end

ndays = [daysinmonth(y, m) for m in 1:12, y in YEARS]

# Monthly rates (kg m-2 yr-1) of monthly sums, or monthly means as they are
monthly(A, kind) = kind == :flux ? A ./ reshape(ndays, 1, 1, 12, :) .* DAYS_PER_YEAR : A

# Annual values: sums of the months (kg m-2 yr-1) or day-weighted means
annual(A, kind) = kind == :flux ? dropdims(sum(A; dims=3); dims=3) :
                  dropdims(sum(A .* reshape(ndays, 1, 1, 12, :); dims=3); dims=3) ./
                  reshape(sum(ndays; dims=1), 1, 1, :)

climatology = Dict(p => Dict{String,Array{Float32,3}}() for p in PERIODS)
annuals = Dict{String,Array{Float32,3}}()
for (name, f) in FIELDS
    println("Reading $(f.var)")
    A = read_monthly(f)
    f.glaciated && (A[.!glaciated, :, :] .= NaN)
    M = monthly(A, f.kind)
    for p in PERIODS
        k = findfirst(==(first(p)), YEARS):findfirst(==(last(p)), YEARS)
        climatology[p][name] = Float32.(dropdims(mean(M[:, :, :, k]; dims=4); dims=4))
    end
    annuals[name] = Float32.(annual(A, f.kind))
end

# ---------------------------------------------------------------------------
# Prepared files
# ---------------------------------------------------------------------------

units(f) = f.kind == :flux ? FLUX_UNITS : "K"

function comment(f)
    c = f.kind == :flux ? "rate of the monthly sum of RACMO2.3p2 $(f.var) (kg m-2 = mm w.e.)" :
                          "mean of RACMO2.3p2 $(f.var)"
    f.glaciated && (c *= "; glaciated surfaces only, missing where f_ice < $F_ICE_MIN")
    return c
end

function write_common!(ds, title)
    defDim(ds, "x", nx)
    defDim(ds, "y", ny)
    defVar(ds, "x", x, ("x",); attrib=["units" => "m", "standard_name" => "projection_x_coordinate",
        "long_name" => "x coordinate (R * rotated longitude)"])
    defVar(ds, "y", y, ("y",); attrib=["units" => "m", "standard_name" => "projection_y_coordinate",
        "long_name" => "y coordinate (R * rotated latitude)"])
    defVar(ds, "crs", Int32(0), (); attrib=[
        "proj_params" => PROJ,
        "grid_north_pole_latitude" => -180.0,
        "grid_north_pole_longitude" => -170.0,
        "comment" => "RACMO2.3p2 ANT27 rotated-pole grid (0.25 degree): x, y = R * rotated longitude, " *
                     "latitude (radians), R = $(Int(R_EARTH)) m, an equidistant cylindrical projection " *
                     "on the rotated sphere"])
    defVar(ds, "z_srf", z_srf, ("x", "y"); fillvalue=NaN32, deflatelevel=1, attrib=[
        "units" => "m", "long_name" => "surface elevation (orography of RACMO)", "grid_mapping" => "crs"])
    defVar(ds, "f_ice", f_ice, ("x", "y"); fillvalue=NaN32, deflatelevel=1, attrib=[
        "units" => "1", "long_name" => "glaciated fraction (grounded and floating ice)", "grid_mapping" => "crs"])
    defVar(ds, "mask_grounded", mask_grounded, ("x", "y"); deflatelevel=1, attrib=[
        "units" => "1", "long_name" => "grounded ice mask",
        "flag_values" => Int32[0, 1], "flag_meanings" => "other grounded_ice", "grid_mapping" => "crs"])
    ds.attrib["title"] = title
    ds.attrib["references"] =
        "van Wessem, J. M., van de Berg, W. J., Noël, B. P. Y., van Meijgaard, E., Amory, C., Birnbaum, G., " *
        "Jakobs, C. L., Krüger, K., Lenaerts, J. T. M., Lhermitte, S., Ligtenberg, S. R. M., Medley, B., " *
        "Reijmer, C. H., van Tricht, K., Trusel, L. D., van Ulft, L. H., Wouters, B., Wuite, J., and " *
        "van den Broeke, M. R.: Modelling the climate and surface mass balance of polar ice sheets using " *
        "RACMO2 - Part 2: Antarctica (1979-2016), The Cryosphere, 12, 1479-1498, " *
        "https://doi.org/10.5194/tc-12-1479-2018, 2018. Data: van Wessem, J. M., van de Berg, W. J., and " *
        "van den Broeke, M. R.: Data set: Monthly averaged RACMO2.3p2 variables; Antarctica, Zenodo, " *
        "https://doi.org/10.5281/zenodo.7760491, 2023"
    ds.attrib["doi"] = "10.5281/zenodo.7760491"
    ds.attrib["license"] = "CC BY 4.0"
    ds.attrib["comment"] = "Fluxes in kg m-2 yr-1 (= mm w.e. yr-1; 1 yr = $DAYS_PER_YEAR d for monthly " *
                           "rates); smb = pr + subl - runoff - drifting-snow erosion"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("smb"))
end

outdir = prepared_dir(SOURCE)
mkpath(outdir)

for p in PERIODS
    path = joinpath(outdir, "RACMO2.3p2_$(first(p))-$(last(p)).nc")
    rm(path; force=true)
    NCDataset(path, "c") do ds
        write_common!(ds, "Antarctic surface mass balance and surface climate, RACMO2.3p2 (ERA5), " *
                          "monthly climatology $(first(p))-$(last(p))")
        defVar(ds, "month", Int32.(1:12), ("month",); attrib=["units" => "1", "long_name" => "month of the year"])
        for (name, f) in FIELDS
            defVar(ds, name, climatology[p][name], ("x", "y", "month"); fillvalue=NaN32, deflatelevel=1,
                   attrib=["units" => units(f), "long_name" => f.long_name, "grid_mapping" => "crs",
                           "cell_methods" => "time: mean within months time: mean over years",
                           "comment" => comment(f)])
        end
    end
    println("Wrote $path")
end

path = joinpath(outdir, "RACMO2.3p2_annual_$(first(YEARS))-$(last(YEARS)).nc")
rm(path; force=true)
NCDataset(path, "c") do ds
    write_common!(ds, "Antarctic surface mass balance and surface climate, RACMO2.3p2 (ERA5), " *
                      "annual means $(first(YEARS))-$(last(YEARS))")
    t = [Dates.value(Date(y, 7, 1) - Date(1950, 1, 1)) for y in YEARS]
    defVar(ds, "time", Float64.(t), ("time",); attrib=["units" => "days since 1950-01-01 00:00:00",
        "calendar" => "standard", "standard_name" => "time", "long_name" => "time (year, at 1 July)"])
    for (name, f) in FIELDS
        defVar(ds, name, annuals[name], ("x", "y", "time"); fillvalue=NaN32, deflatelevel=1,
               attrib=["units" => units(f), "long_name" => f.long_name, "grid_mapping" => "crs",
                       "cell_methods" => f.kind == :flux ? "time: sum over the year" : "time: mean over the year",
                       "comment" => replace(comment(f), "rate of the monthly sum" => "annual sum")])
    end
end
println("Wrote $path")
