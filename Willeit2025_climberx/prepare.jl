# Prepare the CLIMBER-X simulations of Willeit et al. (2025) for remapping (datamanifest
# key willeit2025_climberx, original model output of two runs): the reference simulation
# HS4 (mid-glacial boundary conditions, self-sustained Dansgaard-Oeschger events and a
# Heinrich event) and the preindustrial control (piControl). All files are on the 5°
# model grid, with longitudes in -180:180:
#     $FESMDATA_PREPARED/Willeit2025_climberx/CLIMBERX_Willeit2025_<run>_transient.nc
#     $FESMDATA_PREPARED/Willeit2025_climberx/CLIMBERX_Willeit2025_<run>_transient_ocean.nc
#     $FESMDATA_PREPARED/Willeit2025_climberx/CLIMBERX_Willeit2025_<state>.nc
#     $FESMDATA_PREPARED/Willeit2025_climberx/CLIMBERX_Willeit2025_<state>_ocean.nc
# The transient files hold the 2D output (one model year every 10 years for HS4, every
# 1000 years for piControl) with the annual time series of the run; the climate states
# (interstadial, stadial, heinrich of HS4; piControl) are means over the 2D records of
# each state, with their anomalies relative to piControl (see README.md).
#
# Usage:
#     julia --project=Willeit2025_climberx Willeit2025_climberx/prepare.jl
#     julia fesmdata.jl remap Paleoclimate

using NCDatasets, Statistics

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

const KEY = "willeit2025_climberx"
const NAME = "CLIMBERX_Willeit2025"

# Run => (folder of the original output, description)
const RUNS = [
    "HS4" => ("HS4_Hamp_1.0", "reference simulation: mid-glacial (MIS3) ice sheets, CO2 interactive " *
                              "(about 200 ppm), freshwater noise in the North Atlantic, Heinrich event " *
                              "(freshwater hosing) from model year 2500"),
    "piControl" => ("ice_tarasov_0ka_co2_280ppm", "preindustrial control: present-day ice sheets, CO2 280 ppm, " *
                                                   "freshwater noise in the North Atlantic, freshwater hosing " *
                                                   "from model year 5000"),
]

# Climate states of the 2D records (variable `state` of the transient files): classified
# by the maximum Atlantic overturning, as its centred running mean over SMOOTH_YEARS
# years (`amoc_smooth`), in Sv, in years without freshwater hosing (annual hosing below
# HOSING_MAX Sv) for the interstadials and stadials; piControl: the records before the
# hosing starts.
const SMOOTH_YEARS = 51
const HOSING_MAX = 0.01
const STATES = ["transition", "interstadial", "stadial", "heinrich", "piControl"]   # flag values 0-4
const STATE_RULES = Dict(
    "interstadial" => "AMOC >= 16 Sv, hosing < $HOSING_MAX Sv",
    "stadial" => "6 Sv <= AMOC <= 13 Sv, hosing < $HOSING_MAX Sv",
    "heinrich" => "AMOC < 3 Sv",
    "piControl" => "the records before the freshwater hosing starts",
)
function hs4_state(amoc, hosing)
    amoc >= 16 && hosing < HOSING_MAX && return 1
    6 <= amoc <= 13 && hosing < HOSING_MAX && return 2
    amoc < 3 && return 3
    return 0
end

# Annual time series: file => [(name, original name, long name, units)]
const SERIES = [
    "ocn_ts.nc" => [
        ("amoc", "omaxa", "maximum of the Atlantic overturning streamfunction", "Sv"),
        ("amoc26N", "amoc26N", "maximum of the Atlantic overturning streamfunction at 26N", "Sv"),
        ("aabw", "aabw", "Antarctic bottom water formation rate", "Sv"),
        ("hosing", "hosing", "freshwater hosing flux (North Atlantic, 40-60N, 70-10W)", "Sv"),
        ("buoy_na55", "buoy_NA55", "surface buoyancy flux over the North Atlantic north of 55N", "N"),
        ("sst_glob", "sst", "sea surface temperature, global mean", "degC"),
        ("to_deep", "t_deep", "potential temperature of the ocean below 1000 m, mean", "degC"),
    ],
    "atm_ts.nc" => [
        ("t2m_glob", "tg", "near-surface air temperature, global mean", "degC"),
        ("t2m_nh", "tnh", "near-surface air temperature, Northern Hemisphere mean", "degC"),
        ("t2m_sh", "tsh", "near-surface air temperature, Southern Hemisphere mean", "degC"),
        ("t2m_grl", "tgrl", "near-surface air temperature at NGRIP (Greenland)", "degC"),
        ("t2m_ant", "tant", "near-surface air temperature, Antarctica mean", "degC"),
        ("t2m_natl", "tnatl", "near-surface air temperature, North Atlantic mean", "degC"),
        ("co2", "co2", "atmospheric CO2 concentration (radiation)", "ppm"),
    ],
]
const SEAICE_SERIES = [
    ("sic_ext_nh", "e_nh", "sea-ice extent (concentration > 15%), Northern Hemisphere, monthly mean"),
    ("sic_ext_sh", "e_sh", "sea-ice extent (concentration > 15%), Southern Hemisphere, monthly mean"),
]

const REFERENCES =
    "Willeit, M., Ganopolski, A., Kaufhold, C., Dalmonech, D., Liu, B., and Ilyina, T.: Earth system " *
    "response to Heinrich events explained by a bipolar convection seesaw, Nat. Geosci., 18, 1159-1166, " *
    "2025, doi:10.1038/s41561-025-01814-0; Willeit, M., Ganopolski, A., Robinson, A., and Edwards, N. R.: " *
    "The Earth system model CLIMBER-X v1.0 - Part 1: Climate model description and validation, " *
    "Geosci. Model Dev., 15, 5905-5948, 2022, doi:10.5194/gmd-15-5905-2022"

const LICENSE = "CC BY 4.0 (model output provided by M. Willeit; cite Willeit et al., 2025)"

_float(A) = Float32.(coalesce.(A, NaN32))
_nan(A) = map(x -> ismissing(x) || x == -9999 ? NaN32 : Float32(x), A)

# Longitudes of the model (-177.5:5:177.5) and the order that makes them ascending
function lonlat(ds)
    lon = mod.(Float64.(ds["lon"][:]) .+ 180, 360) .- 180
    ix = sortperm(lon)
    return lon[ix], Float64.(ds["lat"][:]), ix
end

function check_units(v, expected)
    u = get(v.attrib, "units", "")
    u in expected || error("$(v.var.name): units $u, expected $(join(expected, " or "))")
end

"""
    Run

The output of a run: the model years of its 2D records, the 2D fields (lon x lat x ...,
2D records last; monthly fields with month 1-12, annual fields), the static fields, the
annual series and the Atlantic overturning streamfunction.
"""
struct Run
    name::String
    dir::String
    description::String
    years::Vector{Float64}                    # model time of the 2D records (as in the files)
    lon::Vector{Float64}
    lat::Vector{Float64}
    monthly::Dict{String,Array{Float32,4}}    # lon x lat x 13 x record (13: annual mean)
    ocean::Dict{String,Array{Float32,4}}      # lon x lat x depth x record, annual means
    depth::Vector{Float64}
    static::Dict{String,Matrix{Float32}}
    moc::Array{Float32,3}                     # lat_moc x depth_w x record, annual mean
    lat_moc::Vector{Float64}
    depth_w::Vector{Float64}
    series_time::Vector{Float64}
    series::Vector{Tuple{String,Vector{Float64},String,String}}   # name, values, long name, units
    seaice::Vector{Tuple{String,Matrix{Float64},String}}          # name, month x year, long name
end

function read_run(name, dir, description)
    println("Reading $name ($dir)")
    monthly = Dict{String,Array{Float32,4}}()
    ocean = Dict{String,Array{Float32,4}}()
    static = Dict{String,Matrix{Float32}}()
    years, lon, lat, ix = NCDataset(joinpath(dir, "atm.nc")) do ds
        lon, lat, ix = lonlat(ds)
        check_units(ds["t2a"], ("K",))
        check_units(ds["prc"], ("kg/m2/day",))
        monthly["t2m"] = _float(ds["t2a"][:, :, :, :])[ix, :, :, :] .- 273.15f0
        monthly["pr"] = _float(ds["prc"][:, :, :, :])[ix, :, :, :]
        static["z_srf"] = _float(ds["zsa"][:, :, 1])[ix, :]
        static["f_land"] = _float(ds["frlnd"][:, :, 1])[ix, :]
        Float64.(ds["time"][:]), lon, lat, ix
    end
    NCDataset(joinpath(dir, "sic.nc")) do ds
        Float64.(ds["time"][:]) == years || error("$dir: sic.nc and atm.nc have different times")
        monthly["f_sic"] = _float(ds["fsic"][:, :, :, :])[ix, :, :, :]
    end
    NCDataset(joinpath(dir, "cmn.nc")) do ds
        static["f_ice"] = _float(ds["f_ice"][:, :, 1])[ix, :]
    end
    depth, moc, lat_moc, depth_w = NCDataset(joinpath(dir, "ocn.nc")) do ds
        Float64.(ds["time"][:]) == years || error("$dir: ocn.nc and atm.nc have different times")
        check_units(ds["sst"], ("C",))
        check_units(ds["t"], ("C",))
        check_units(ds["s"], ("psu",))
        check_units(ds["opsi_a"], ("Sv",))
        monthly["sst"] = _nan(ds["sst"][:, :, :, :])[ix, :, :, :]
        ocean["to"] = _nan(ds["t"][:, :, :, 13, :])[ix, :, :, :]
        ocean["so"] = _nan(ds["s"][:, :, :, 13, :])[ix, :, :, :]
        moc = _nan(ds["opsi_a"][:, :, 13, :])
        Float64.(ds["lev"][:]), moc, Float64.(ds["latv1"][:]), abs.(Float64.(ds["levw"][:]))
    end
    # Sea ice only over the ocean of the model (where the SST is defined)
    monthly["f_sic"][isnan.(monthly["sst"])] .= NaN32

    series_time = Float64[]
    series = Tuple{String,Vector{Float64},String,String}[]
    for (file, vars) in SERIES
        NCDataset(joinpath(dir, file)) do ds
            t = Float64.(ds["time"][:])
            isempty(series_time) ? append!(series_time, t) : (t == series_time || error("$dir: $file: other times"))
            for (n, orig, long_name, units) in vars
                check_units(ds[orig], units == "degC" ? ("degC", "C") : (units,))
                push!(series, (n, Float64.(coalesce.(ds[orig][:], NaN)), long_name, units))
            end
        end
    end
    seaice = NCDataset(joinpath(dir, "sic_ts.nc")) do ds
        Float64.(ds["time"][:]) == series_time || error("$dir: sic_ts.nc: other times")
        [(n, Float64.(coalesce.(ds[orig][:, :], NaN))[1:12, :], long_name) for (n, orig, long_name) in SEAICE_SERIES]
    end
    return Run(name, dir, description, years, lon, lat, monthly, ocean, depth, static, moc, lat_moc, depth_w,
               series_time, series, seaice)
end

series(r::Run, name) = only(s[2] for s in r.series if s[1] == name)

# State of each 2D record (see STATE_RULES) and the smoothed AMOC of the classification
function classify(r::Run)
    amoc, hosing = series(r, "amoc"), series(r, "hosing")
    n, w = length(amoc), SMOOTH_YEARS ÷ 2
    smooth = [mean(amoc[max(1, i - w):min(n, i + w)]) for i in 1:n]
    k = [findfirst(==(y), r.series_time) for y in r.years]
    any(isnothing, k) && error("$(r.name): 2D records without a year of the time series")
    if r.name == "piControl"
        first_hosing = r.series_time[findfirst(>(0), hosing)]
        state = Int8[y < first_hosing ? 4 : 0 for y in r.years]
    else
        state = Int8[hs4_state(smooth[i], hosing[i]) for i in k]
    end
    return state, Float32.(smooth[k])
end

# Time coordinate of the 2D records and of the series: years ago for HS4 (model calendar,
# negative years before present), model years for piControl
function time_attrib(r::Run)
    r.name == "HS4" && return (t -> -t, ["units" => "years ago", "long_name" => "time (model calendar, before 1950 CE)"])
    return (t -> t, ["units" => "years", "long_name" => "model year of the simulation"])
end

function defcoords(ds, r::Run; month=true, depth=false)
    defVar(ds, "lon", r.lon, ("lon",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
    defVar(ds, "lat", r.lat, ("lat",); attrib=["units" => "degrees_north", "standard_name" => "latitude"])
    month && defVar(ds, "month", Int32.(1:12), ("month",); attrib=["units" => "1", "long_name" => "month of the year"])
    depth && defVar(ds, "depth", Float32.(r.depth), ("depth",);
                    attrib=["units" => "m", "positive" => "down", "long_name" => "depth of the T levels"])
end

field(ds, name, A, dims, units, long_name) =
    defVar(ds, name, A, dims; fillvalue=NaN32, deflatelevel=1, attrib=["units" => units, "long_name" => long_name])

const MONTHLY = [
    ("t2m", "degC", "near-surface (2 m) air temperature, grid-cell mean"),
    ("pr", "mm d-1", "precipitation (water equivalent)"),
    ("sst", "degC", "sea surface temperature"),
    ("f_sic", "1", "sea-ice area fraction of the ocean"),
]
const OCEAN = [("to", "degC", "sea water potential temperature"), ("so", "psu", "sea water salinity")]
const STATIC = [
    ("z_srf", "m", "surface elevation of the atmosphere model, grid-cell mean"),
    ("f_land", "1", "land area fraction (with the ice sheets)"),
    ("f_ice", "1", "ice-sheet area fraction"),
]

function write_attrib(ds, title, r::Run, original_files)
    ds.attrib["title"] = title
    ds.attrib["model"] = "CLIMBER-X v1.0"
    ds.attrib["simulation"] = r.name
    ds.attrib["simulation_description"] = r.description
    ds.attrib["references"] = REFERENCES
    ds.attrib["doi"] = "10.1038/s41561-025-01814-0"
    ds.attrib["license"] = LICENSE
    ds.attrib["original_files"] = original_files
    ds.attrib["comment"] = "2D output: monthly means of single model years (one every " *
                           "$(Int(r.years[2] - r.years[1])) years); annual time series: every model year"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("paleoclimate"))
end

# The transient files of a run: the 2D records, their states, and the time series
function write_transient(outdir, r::Run, state, smooth)
    tf, tatt = time_attrib(r)
    defseries(ds) = begin
        defVar(ds, "time_ann", tf.(r.series_time), ("time_ann",); attrib=vcat(tatt, ["comment" => "annual time series"]))
        for (n, v, long_name, units) in r.series
            defVar(ds, n, v, ("time_ann",); attrib=["units" => units, "long_name" => long_name * ", annual mean"])
        end
        for (n, v, long_name) in r.seaice
            defVar(ds, n, v, ("month", "time_ann"); attrib=["units" => "10^6 km2", "long_name" => long_name])
        end
    end
    path = joinpath(outdir, "$(NAME)_$(r.name)_transient.nc")
    NCDataset(path, "c") do ds
        defcoords(ds, r)
        defVar(ds, "time", tf.(r.years), ("time",); attrib=tatt)
        for (n, units, long_name) in MONTHLY
            field(ds, "$(n)_mon", r.monthly[n][:, :, 1:12, :], ("lon", "lat", "month", "time"), units, long_name * ", monthly mean")
        end
        for (n, units, long_name) in STATIC
            field(ds, n, r.static[n], ("lon", "lat"), units, long_name)
        end
        defVar(ds, "state", state, ("time",);
               attrib=["units" => "1", "long_name" => "climate state of the 2D record",
                       "flag_values" => Int8.(0:4), "flag_meanings" => join(STATES, " "),
                       "comment" => join(("$s: $(STATE_RULES[s])" for s in STATES[2:end]), "; ") *
                                    "; AMOC: amoc_smooth"])
        defVar(ds, "amoc_smooth", smooth, ("time",);
               attrib=["units" => "Sv", "long_name" => "maximum of the Atlantic overturning streamfunction, " *
                                                         "centred $SMOOTH_YEARS-year running mean"])
        defseries(ds)
        write_attrib(ds, "CLIMBER-X $(r.name) 2D output and time series (Willeit et al., 2025)", r,
                     "atm.nc, sic.nc, ocn.nc, cmn.nc, ocn_ts.nc, atm_ts.nc, sic_ts.nc")
    end
    println("Wrote $path")
    path = joinpath(outdir, "$(NAME)_$(r.name)_transient_ocean.nc")
    NCDataset(path, "c") do ds
        defcoords(ds, r; month=false, depth=true)
        defVar(ds, "time", tf.(r.years), ("time",); attrib=tatt)
        for (n, units, long_name) in OCEAN
            field(ds, n, r.ocean[n], ("lon", "lat", "depth", "time"), units, long_name * ", annual mean")
        end
        defVar(ds, "lat_moc", r.lat_moc, ("lat_moc",);
               attrib=["units" => "degrees_north", "long_name" => "latitude of the overturning streamfunction"])
        defVar(ds, "depth_w", Float32.(r.depth_w), ("depth_w",);
               attrib=["units" => "m", "positive" => "down", "long_name" => "depth of the tops of the levels"])
        defVar(ds, "moc_atl", r.moc, ("lat_moc", "depth_w", "time"); fillvalue=NaN32, deflatelevel=1,
               attrib=["units" => "Sv", "long_name" => "Atlantic meridional overturning streamfunction, annual mean"])
        write_attrib(ds, "CLIMBER-X $(r.name) ocean 2D output (Willeit et al., 2025)", r, "ocn.nc")
    end
    println("Wrote $path")
end

# Mean of the 2D records `k` along the last dimension
recmean(A, k) = dropdims(mean(selectdim(A, ndims(A), k); dims=ndims(A)); dims=ndims(A))

"""
Climate state `s` of a run: the mean of its 2D records `k`, with the anomalies relative
to the piControl state `ref` (state minus piControl; missing where either is), if given.
"""
function write_state(outdir, r::Run, s, k, ref)
    isempty(k) && error("$(r.name): no 2D records of the state $s")
    tf, tatt = time_attrib(r)
    yrs = tf.(r.years[k])
    note(ds) = begin
        ds.attrib["state"] = s
        ds.attrib["state_definition"] = STATE_RULES[s] * " (AMOC: maximum of the Atlantic overturning, " *
                                        "centred $SMOOTH_YEARS-year running mean)"
        ds.attrib["records"] = "$(length(k)) single model years from $(yrs[1]) to $(yrs[end]) " *
                               "($(Dict(tatt)["units"]))"
        ref === nothing || (ds.attrib["anomalies"] = "*_anom: $s minus piControl (CLIMBER-X preindustrial control); " *
                                                     "ocean: by model level (the depths of the levels differ " *
                                                     "between the runs by up to 0.6%)")
    end
    M = Dict(n => recmean(r.monthly[n], k) for (n, _, _) in MONTHLY)
    O = Dict(n => recmean(r.ocean[n], k) for (n, _, _) in OCEAN)
    path = joinpath(outdir, "$(NAME)_$s.nc")
    NCDataset(path, "c") do ds
        defcoords(ds, r)
        for (n, units, long_name) in MONTHLY
            field(ds, "$(n)_mon", M[n][:, :, 1:12], ("lon", "lat", "month"), units, long_name * ", monthly mean")
            field(ds, "$(n)_ann", M[n][:, :, 13], ("lon", "lat"), units, long_name * ", annual mean")
            (ref === nothing || n == "f_sic") && continue
            field(ds, "$(n)_mon_anom", M[n][:, :, 1:12] .- ref[n][:, :, 1:12], ("lon", "lat", "month"), units,
                  long_name * ", monthly mean, anomaly relative to piControl")
            field(ds, "$(n)_ann_anom", M[n][:, :, 13] .- ref[n][:, :, 13], ("lon", "lat"), units,
                  long_name * ", annual mean, anomaly relative to piControl")
        end
        for (n, units, long_name) in STATIC
            field(ds, n, r.static[n], ("lon", "lat"), units, long_name)
        end
        note(ds)
        write_attrib(ds, "CLIMBER-X $s climatology (Willeit et al., 2025)", r, "atm.nc, sic.nc, ocn.nc, cmn.nc")
    end
    println("Wrote $path ($(length(k)) records)")
    path = joinpath(outdir, "$(NAME)_$(s)_ocean.nc")
    NCDataset(path, "c") do ds
        defcoords(ds, r; month=false, depth=true)
        for (n, units, long_name) in OCEAN
            field(ds, n, O[n], ("lon", "lat", "depth"), units, long_name * ", annual mean")
            ref === nothing && continue
            field(ds, "$(n)_anom", O[n] .- ref[n], ("lon", "lat", "depth"), units,
                  long_name * ", annual mean, anomaly relative to piControl")
        end
        note(ds)
        write_attrib(ds, "CLIMBER-X $s ocean climatology (Willeit et al., 2025)", r, "ocn.nc")
    end
    println("Wrote $path")
    return merge(M, O)
end

# The transient files of a run, and the states of its 2D records
function write_run(outdir, r::Run)
    state, smooth = classify(r)
    println("$(r.name): ", join(("$(STATES[i + 1]) $(count(==(i), state))" for i in 0:4 if any(==(i), state)), ", "))
    write_transient(outdir, r, state, smooth)
    return state
end

db = manifest()
dir = get_dataset_path(db, KEY)
isdir(dir) || error("$dir: missing; the original output of Willeit et al. (2025) is not public, " *
                    "see Willeit2025_climberx/README.md")

outdir = prepared_dir("Willeit2025_climberx")
mkpath(outdir)
runs = Dict(name => read_run(name, joinpath(dir, folder), description) for (name, (folder, description)) in RUNS)
ctl, hs4 = runs["piControl"], runs["HS4"]
ctl.lon == hs4.lon && ctl.lat == hs4.lat && length(ctl.depth) == length(hs4.depth) ||
    error("the runs are on different grids")

state = write_run(outdir, ctl)
ref = write_state(outdir, ctl, "piControl", findall(==(4), state), nothing)
state = write_run(outdir, hs4)
for (i, s) in ((1, "interstadial"), (2, "stadial"), (3, "heinrich"))
    write_state(outdir, hs4, s, findall(==(i), state), ref)
end
