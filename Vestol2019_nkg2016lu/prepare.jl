# Prepare the land uplift model NKG2016LU of Fennoscandia and the Baltic region (Vestøl
# et al., 2019) for remapping: the absolute uplift NKG2016LU_abs (ITRF2008) and its
# standard uncertainty NKG2016LU_StdUnc on their 1/12° x 1/6° lon-lat grid (49-75°N,
# 0-50°E; datamanifest key vestol2019_nkg2016lu), as a prepared NetCDF file,
# $FESMDATA_PREPARED/Vestol2019_nkg2016lu/Vestol2019_NKG2016LU.nc, with uplift_rate and
# uplift_rate_sd.
#
# Usage:
#     julia --project=Vestol2019_nkg2016lu Vestol2019_nkg2016lu/prepare.jl
#     julia fesmdata.jl remap SolidEarth NKG2016LU

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

const KEY = "vestol2019_nkg2016lu"
const LAT = 49:1/12:75                  # grid nodes of the model (Gravsoft grid header)
const LON = 0:1/6:50

db = manifest()
dir = get_dataset_path(db, KEY)
isdir(dir) || (dir = download_dataset(db, KEY))

# Line-based files (*.dat): latitude, longitude (degrees), value (mm/a), one line per
# node, from the north-west corner by rows of latitude
function read_dat(name)
    path = joinpath(dir, name)
    rows = [parse.(Float64, split(l)) for l in eachline(path) if !isempty(strip(l))]
    all(r -> length(r) == 3, rows) || error("$path: lines without 3 columns")
    z = fill(NaN32, length(LON), length(LAT))
    for (la, lo, v) in rows
        i, j = round(Int, (lo - first(LON)) * 6) + 1, round(Int, (la - first(LAT)) * 12) + 1
        (isapprox(LON[i], lo; atol=1e-5) && isapprox(LAT[j], la; atol=1e-5)) ||
            error("$path: node ($la, $lo) is not on the grid")
        isnan(z[i, j]) || error("$path: node ($la, $lo) repeats")
        z[i, j] = v
    end
    any(isnan, z) && error("$path: $(count(isnan, z)) nodes missing")
    return z
end
uplift = read_dat("NKG2016LU_abs.dat")
uplift_sd = read_dat("NKG2016LU_StdUnc.dat")

path = joinpath(prepared_dir("Vestol2019_nkg2016lu"), "Vestol2019_NKG2016LU.nc")
mkpath(dirname(path))
rm(path; force=true)
NCDataset(path, "c") do ds
    defVar(ds, "lon", collect(LON), ("lon",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
    defVar(ds, "lat", collect(LAT), ("lat",); attrib=["units" => "degrees_north", "standard_name" => "latitude"])
    defVar(ds, "uplift_rate", uplift, ("lon", "lat"); fillvalue=NaN32, deflatelevel=1,
           attrib=["units" => "mm yr-1",
                   "long_name" => "absolute land uplift rate, ITRF2008 (observed: elastic part not removed)",
                   "elastic_correction" => "not removed",
                   "comment" => "NKG2016LU_abs: semi-empirical model of the GNSS uplift rates (BIFROST, ITRF2008), " *
                                "levelling and tide gauges, with a GIA model (NKG2016GIA_prel0306) filling the gaps " *
                                "between the observations and outside them; relative to the Earth's centre of mass"])
    defVar(ds, "uplift_rate_sd", uplift_sd, ("lon", "lat"); fillvalue=NaN32, deflatelevel=1,
           attrib=["units" => "mm yr-1", "long_name" => "standard uncertainty of the absolute land uplift rate",
                   "comment" => "NKG2016LU_StdUnc"])
    ds.attrib["title"] = "Land uplift model NKG2016LU of Fennoscandia and the Baltic region, absolute uplift (Vestøl et al., 2019)"
    ds.attrib["references"] = "Vestøl, O., Ågren, J., Steffen, H., Kierulf, H., and Tarasov, L.: NKG2016LU: a new " *
                              "land uplift model for Fennoscandia and the Baltic Region, J. Geod., 93, 1759-1779, " *
                              "2019, doi:10.1007/s00190-019-01280-8. Data: Nordic Geodetic Commission (NKG), " *
                              "Lantmäteriet, nkg2016lu-with-readme.zip"
    ds.attrib["doi"] = "10.1007/s00190-019-01280-8"
    ds.attrib["license"] = "CC BY 4.0 (Lantmäteriet)"
    ds.attrib["reference_frame"] = "ITRF2008"
    ds.attrib["elastic_correction"] = "not removed"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("solidearth"))
end
println("Wrote $path")
