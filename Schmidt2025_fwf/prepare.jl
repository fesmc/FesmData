# Prepare the freshwater flux and mass anomaly series of the ice sheets by region of
# Schmidt et al. (2025) as records (see Records/README.md): each series file of the
# Zenodo record (datamanifest keys schmidt2025_<file>) as time series by region
# (featureType timeSeries), with the regions of the Regions basin set Schmidt2025
# (datamanifest keys schmidt2025_regions_greenland and schmidt2025_regions_antarctica),
# located at their centroids, $FESMDATA_PREPARED/Schmidt2025_fwf/Schmidt2025_<file>.nc.
#
# Usage:
#     julia --project=Schmidt2025_fwf Schmidt2025_fwf/prepare.jl
#     julia fesmdata.jl record Freshwater
#
# The variables are those of the source files (names and attributes), in the
# orientation (time, region) of Julia; uncertainties are renamed <name>_sd, and the
# units missing in the source are set (see UNITS). The time stamps of the source (the
# start of the year or month in Greenland, 1 July of the year in Antarctica) are
# replaced by the middles of the years or months, with time_bnds.

using ArchGDAL
using Dates
using NCDatasets
using Proj

const AG = ArchGDAL

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

# Series files: ice sheet and the time stamps of the source (:year_start, 1 January of
# the year; :mid_year, 1 July of the year; :month_start, the first day of the month)
const SERIES = [
    (file="GL_discharge", sheet=:greenland, stamp=:year_start),
    (file="GL_runoff", sheet=:greenland, stamp=:month_start),
    (file="GL_mass_anomaly", sheet=:greenland, stamp=:year_start),
    (file="AQ_calving", sheet=:antarctica, stamp=:mid_year),
    (file="AQ_subshelf_melt", sheet=:antarctica, stamp=:mid_year),
    (file="AQ_grounded_mass_change", sheet=:antarctica, stamp=:mid_year),
    (file="AQ_mass_anomaly", sheet=:antarctica, stamp=:mid_year),
]

# Regions: GeoPackage (datamanifest key) and the field with the region name. The region
# numbers of the series are the names in alphabetical order (as basin ids of the Regions
# basin set Schmidt2025); polygons with other names (Islands in Antarctica) are not used.
const REGIONS = Dict(
    :greenland => (key="schmidt2025_regions_greenland", field="label",
                   names=["CE", "CW", "NE", "NO", "NW", "SE", "SW"]),
    :antarctica => (key="schmidt2025_regions_antarctica", field="NAME",
                    names=["A-Ap", "Ap-B", "B-C", "C-Cp", "Cp-D", "D-Dp", "Dp-E", "E-Ep", "Ep-F", "F-G",
                           "G-H", "H-Hp", "Hp-I", "I-Ipp", "Ipp-J", "J-Jpp", "Jpp-K", "K-A"]),
)

# Uncertainties, renamed <name>_sd
const RENAME = Dict(
    "GL_discharge" => Dict("err" => "discharge_sd"),
    "GL_mass_anomaly" => Dict("SMB_ROI_err" => "SMB_ROI_sd", "D_ROI_err" => "D_ROI_sd"),
    "AQ_calving" => Dict("uncertainty" => "calving_sd"),
)

# Units set where the source has none, or "Gt d-1" for values of the magnitude of the
# fluxes in Gt yr-1 (the uncertainties of GL_mass_anomaly)
const UNITS = Dict(
    "GL_mass_anomaly" => Dict(v => "Gt yr-1" for v in ("SMB_ROI_err", "D_ROI_err", "MB_ROI", "MB", "D_ROI_anom",
                                                        "SMB_ROI_anom", "MB_ROI_anom")),
    "AQ_calving" => Dict("uncertainty" => "Gt yr-1"),
    "AQ_mass_anomaly" => Dict("MB_ROI_anom" => "Gt yr-1"),
)

# Attributes copied from the variables of the source
const COPY_ATTRIB = ("long_name", "standard_name", "description", "comment", "positive")

const TIME_UNITS = "days since 1800-01-01 00:00:00"
days(t::DateTime) = Dates.value(t - DateTime(1800, 1, 1)) / 86_400_000

"""
    centroids(sheet) -> (names, lat, lon)

Area-weighted centroids of the regions of an ice sheet, computed in the projection of
the GeoPackage and converted to lon-lat.
"""
function centroids(sheet::Symbol)
    r = REGIONS[sheet]
    sums = Dict(name => zeros(3) for name in r.names)       # area, area x, area y
    AG.read(download_dataset(manifest(), r.key)) do ds
        layer = AG.getlayer(ds, 0)
        to_lonlat = Proj.Transformation(AG.toWKT(AG.getspatialref(layer)), "EPSG:4326"; always_xy=true)
        for f in layer
            name = AG.getfield(f, r.field)
            haskey(sums, name) || continue
            g = AG.getgeom(f)
            a = AG.geomarea(g)
            c = AG.centroid(g)
            sums[name] .+= (a, a * AG.getx(c, 0), a * AG.gety(c, 0))
        end
        any(s[1] == 0 for s in values(sums)) && error("$(r.key): regions without polygons")
        lonlat = [to_lonlat(s[2] / s[1], s[3] / s[1]) for s in (sums[n] for n in r.names)]
        return r.names, [p[2] for p in lonlat], [p[1] for p in lonlat]
    end
end

"Bounds of the time stamps `t` of the source."
function time_bounds(t::Vector{DateTime}, stamp::Symbol, file)
    if stamp == :year_start
        all(x -> month(x) == 1 && day(x) == 1 && x == floor(x, Day), t) || error("$file: time stamps are not 1 January")
        return t, t .+ Year(1)
    elseif stamp == :mid_year
        all(x -> month(x) == 7 && day(x) == 1 && x == floor(x, Day), t) || error("$file: time stamps are not 1 July")
        return DateTime.(year.(t), 1, 1), DateTime.(year.(t) .+ 1, 1, 1)
    elseif stamp == :month_start
        all(x -> day(x) == 1 && x == floor(x, Day), t) || error("$file: time stamps are not the first of the month")
        return t, t .+ Month(1)
    end
    error("unknown time stamp $stamp")
end

function prepare(s)
    db = manifest()
    names, lat, lon = centroids(s.sheet)
    nr = length(names)
    src = download_dataset(db, "schmidt2025_" * lowercase(s.file))
    path = joinpath(prepared_dir("Schmidt2025_fwf"), "Schmidt2025_$(s.file).nc")
    mkpath(dirname(path))
    rm(path; force=true)
    NCDataset(src) do sds
        sds["region"][:] == 1:nr || error("$src: regions are not 1:$nr")
        haskey(sds, "region_name") && strip.(sds["region_name"][:]) != names &&
            error("$src: region names $(sds["region_name"][:]) differ from $names")
        t0, t1 = time_bounds(sds["time"][:], s.stamp, s.file)
        nt = length(t0)
        NCDataset(path, "c") do ds
            defDim(ds, "region", nr)
            defDim(ds, "time", nt)
            defDim(ds, "nv", 2)
            defVar(ds, "region", Int32.(1:nr), ("region",); attrib=[
                "units" => "1", "long_name" => "region number, the basin id of the Regions basin set Schmidt2025"])
            defVar(ds, "region_name", names, ("region",); attrib=["long_name" => "region", "cf_role" => "timeseries_id"])
            defVar(ds, "lat", lat, ("region",); attrib=["units" => "degrees_north", "standard_name" => "latitude",
                                                        "long_name" => "latitude of the centroid of the region"])
            defVar(ds, "lon", lon, ("region",); attrib=["units" => "degrees_east", "standard_name" => "longitude",
                                                        "long_name" => "longitude of the centroid of the region"])
            defVar(ds, "time", (days.(t0) .+ days.(t1)) ./ 2, ("time",); attrib=[
                "units" => TIME_UNITS, "calendar" => "proleptic_gregorian", "bounds" => "time_bnds",
                "long_name" => "time, middle of the $(s.stamp == :month_start ? "month" : "year")"])
            defVar(ds, "time_bnds", permutedims(hcat(days.(t0), days.(t1))), ("nv", "time"))
            for (name, v) in sds
                name in ("time", "region", "region_name") && continue
                dims = dimnames(v)
                issubset(dims, ("time", "region")) && !isempty(dims) || error("$src: $name has dimensions $dims")
                out = get(get(RENAME, s.file, Dict()), name, name)
                units = get(get(UNITS, s.file, Dict()), name, get(v.attrib, "units", nothing))
                units === nothing && error("$src: $name has no units (add them to UNITS)")
                attrib = Pair{String,Any}["units" => units]
                for k in COPY_ATTRIB
                    haskey(v.attrib, k) && push!(attrib, k => v.attrib[k])
                end
                haskey(get(UNITS, s.file, Dict()), name) &&
                    push!(attrib, "comment_units" => "units set by FesmData (source: $(get(v.attrib, "units", "none")))")
                data = length(dims) == 2 ? v.var[:, :] : v.var[:]
                if length(dims) == 2
                    dims == ("time", "region") || (data = permutedims(data))
                    push!(attrib, "coordinates" => "time lat lon")
                end
                odims = length(dims) == 2 ? ("time", "region") : dims
                if eltype(data) <: AbstractFloat
                    fill = get(v.attrib, "_FillValue", nothing)
                    fill === nothing || (data = map(x -> x == fill ? NaN : x, data))
                    defVar(ds, out, Float64.(data), odims; fillvalue=NaN, attrib=attrib)
                else
                    defVar(ds, out, data, odims; attrib=attrib)
                end
            end
            ds.attrib["title"] = get(sds.attrib, "title", s.file) * " (Schmidt et al., 2025, $(s.file).nc)"
            ds.attrib["references"] = "Schmidt, G. A., Mankoff, K. D., Bamber, J. L., et al.: Datasets and protocols " *
                                      "for including anomalous freshwater from melting ice sheets in climate " *
                                      "simulations, Geosci. Model Dev., 18, 8333-8361, 2025, " *
                                      "doi:10.5194/gmd-18-8333-2025. Data: Freshwater sources from Antarctica and " *
                                      "Greenland, Zenodo, doi:10.5281/zenodo.17386710" *
                                      (haskey(sds.attrib, "original_data_source") ?
                                       ". Original data: " * strip(sds.attrib["original_data_source"]) : "")
            ds.attrib["doi"] = "10.5281/zenodo.17386710"
            ds.attrib["license"] = "CC BY 4.0 (Zenodo)"
            ds.attrib["featureType"] = "timeSeries"
            ds.attrib["Conventions"] = "CF-1.11"
            foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("freshwater"))
        end
    end
    println("Wrote $path")
end

foreach(prepare, SERIES)
