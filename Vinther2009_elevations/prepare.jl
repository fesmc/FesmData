# Prepare the Holocene surface elevation changes at four Greenland ice core sites of
# Vinther et al. (2009) as a record (see Records/README.md): section 3 of the NOAA NCEI
# text file (datamanifest key vinther2009_greenland), 20-year values from 11.7 ka b2k to
# present, as time series at Camp Century, NGRIP, GRIP and DYE-3 (featureType
# timeSeries), $FESMDATA_WORK/prepared/Vinther2009_elevations/Vinther2009_elevations.nc.
#
# Usage:
#     julia --project=Vinther2009_elevations Vinther2009_elevations/prepare.jl
#     julia fesmdata.jl record IceCores Vinther2009

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

const B2K_TO_BP = 50.0          # years before 2000 CE -> years before 1950 CE
const DT = 20.0                 # years, length of the intervals

# Sites, in the order of the columns of section 3, with their location and present
# elevation (m) from the description of the file, and the 1-sigma uncertainty of the
# elevation changes (m) given in section 3
const SITES = [
    (name="Camp Century", lat=77 + 10 / 60, lon=-(61 + 8 / 60), z_srf=1890.0, sd=65.0),
    (name="NGRIP", lat=75.1, lon=-42.3, z_srf=2920.0, sd=40.0),
    (name="GRIP", lat=72 + 35 / 60, lon=-(37 + 38 / 60), z_srf=3230.0, sd=40.0),
    (name="DYE-3", lat=65 + 11 / 60, lon=-(43 + 49 / 60), z_srf=2490.0, sd=65.0),
]

txt = download_dataset(manifest(), "vinther2009_greenland")

# Section 3: after its title, a header of four lines (the first "Age    CampCentury
# NGRIP  GRIP  DYE-3"), then rows of age (years b2k, bottom of each 20-year interval) and
# the four site elevation changes (m), up to an empty line. The file is Latin-1: read
# it as bytes, the data lines are ASCII.
lines = split(String(map(b -> b < 0x80 ? b : UInt8('?'), read(txt))), r"\r?\n")
i0 = findfirst(l -> startswith(l, "3. Holocene site elevation data"), lines)
i0 === nothing && error("$txt: no section 3 (site elevation data)")
k = findfirst(l -> split(l) == ["Age", "CampCentury", "NGRIP", "GRIP", "DYE-3"], lines[i0+1:end])
k === nothing && error("$txt: no header line \"Age CampCentury NGRIP GRIP DYE-3\" in section 3")
ih = i0 + k
rows = Vector{Float64}[]
for l in lines[ih+4:end]
    isempty(strip(l)) && break
    push!(rows, parse.(Float64, split(l)))
end
all(length.(rows) .== 5) || error("$txt: rows of section 3 without 5 values")
age = [r[1] for r in rows]
dz = [r[j+1] for r in rows, j in eachindex(SITES)]
all(diff(age) .== DT) || error("$txt: the ages are not every $DT years")
nt, ns = size(dz)

# Interval centres and bounds, in years before 1950 CE
time = age .- DT / 2 .- B2K_TO_BP
time_bnds = permutedims(hcat(age .- DT .- B2K_TO_BP, age .- B2K_TO_BP))

path = joinpath(prepared_dir("Vinther2009_elevations"), "Vinther2009_elevations.nc")
mkpath(dirname(path))
rm(path; force=true)
NCDataset(path, "c") do ds
    defDim(ds, "station", ns)
    defDim(ds, "time", nt)
    defDim(ds, "nv", 2)
    defVar(ds, "site_name", [s.name for s in SITES], ("station",);
           attrib=["long_name" => "ice core site", "cf_role" => "timeseries_id"])
    defVar(ds, "lat", [s.lat for s in SITES], ("station",); attrib=["units" => "degrees_north", "standard_name" => "latitude"])
    defVar(ds, "lon", [s.lon for s in SITES], ("station",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
    defVar(ds, "z_srf", [s.z_srf for s in SITES], ("station",);
           attrib=["units" => "m", "long_name" => "present surface elevation of the site"])
    defVar(ds, "time", time, ("time",); attrib=[
        "units" => "years ago", "long_name" => "time (years before 1950 CE)", "bounds" => "time_bnds",
        "comment" => "centre of the 20-year interval; GICC05, converted from years b2k (before 2000 CE) by " *
                     "subtracting 50"])
    defVar(ds, "time_bnds", time_bnds, ("nv", "time"))
    attrib_series(units, long_name) = ["units" => units, "long_name" => long_name, "coordinates" => "time lat lon"]
    defVar(ds, "dz_srf", Float32.(dz), ("time", "station"); deflatelevel=1,
           attrib=attrib_series("m", "surface elevation change relative to the present (interval 20-40 b2k), " *
                                     "corrected for upstream effects; elevation = z_srf + dz_srf"))
    defVar(ds, "dz_srf_sd", Float32[s.sd for _ in 1:nt, s in SITES], ("time", "station"); deflatelevel=1,
           attrib=attrib_series("m", "uncertainty (1 sigma) of the surface elevation change"))
    ds.attrib["title"] = "Holocene surface elevation changes at Greenland ice core sites (Vinther et al., 2009)"
    ds.attrib["references"] = "Vinther, B. M., Buchardt, S. L., Clausen, H. B., Dahl-Jensen, D., Johnsen, S. J., " *
                              "Fisher, D. A., Koerner, R. M., Raynaud, D., Lipenkov, V., Andersen, K. K., Blunier, T., " *
                              "Rasmussen, S. O., Steffensen, J. P., and Svensson, A. M.: Holocene thinning of the " *
                              "Greenland ice sheet, Nature, 461, 385-388, 2009. Data: Vinther, B. M. et al.: Greenland " *
                              "Ice Sheet Holocene d18O, Temperature, and Surface Elevation, IGBP PAGES/World Data " *
                              "Center for Paleoclimatology Data Contribution Series # 2011-053, NOAA NCDC, 2011"
    ds.attrib["doi"] = "10.1038/nature08355"
    ds.attrib["license"] = "NOAA NCEI open data, no licence stated (no restrictions on use; cite the publication)"
    ds.attrib["featureType"] = "timeSeries"
    ds.attrib["Conventions"] = "CF-1.11"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("icecores"))
end
println("Wrote $path")
