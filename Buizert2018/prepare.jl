# Prepare the Buizert et al. (2018) Greenland reconstruction for remapping: the monthly
# surface air temperature and precipitation of the gridded reconstruction, 22 ka to
# present in decadal steps, and its 1981-2010 baseline climatology (NOAA NCEI,
# datamanifest keys buizert2018_recon and buizert2018_baseline), on their native
# 0.5° x 0.25° lon-lat grid, as two prepared files in $FESMDATA_WORK/prepared/Buizert2018/:
#
#   Buizert2018.nc            tas, pr (lon, lat, month, time), z_srf (lon, lat)
#   Buizert2018_1981-2010.nc  tas, pr (lon, lat, month), z_srf (lon, lat)
#
# Usage:
#     julia --project=Buizert2018 Buizert2018/prepare.jl
#     julia fesmdata.jl remap $FESMDATA_WORK/prepared/Buizert2018/Buizert2018.nc GRL-32KM

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

const NT_CHUNK = 100    # time steps read and written at once

db = manifest()
recon = download_dataset(db, "buizert2018_recon")
baseline = download_dataset(db, "buizert2018_baseline")

# The grid is regular, but given as 2D LON(c, r), LAT(c, r) (r × c in Julia), the same
# in both files: longitudes -96:0.5:0, latitudes 58:0.25:85, ascending.
function read_grid(path)
    NCDataset(path) do ds
        LON, LAT = ds["LON"].var[:, :], ds["LAT"].var[:, :]
        lon, lat = Float64.(LON[:, 1]), Float64.(LAT[1, :])
        all(LON .== LON[:, 1:1]) && all(LAT .== LAT[1:1, :]) && issorted(lon) && issorted(lat) ||
            error("$path: LON and LAT do not form a regular ascending lon-lat grid")
        return lon, lat
    end
end
lon, lat = read_grid(recon)
read_grid(baseline) == (lon, lat) || error("the grids of $recon and $baseline differ")
nx, ny = length(lon), length(lat)

# Time: TIME is in years relative to 1950 CE, negative in the past (-22005 to 55, so
# YEAR_CE = TIME + 1950), at the centres of decades; written as age in years BP
# (22005 to -55), oldest first as in the file.
time = NCDataset(recon) do ds
    dimnames(ds["TS2"]) == ("r", "c", "month", "time") || error("$recon: unexpected dimensions of TS2")
    -Float64.(ds["TIME"].var[:])
end
nt = length(time)

const M_PER_S = 1000.0f0    # m s-1 (water equivalent) -> kg m-2 s-1

attrib_tas = ["units" => "K", "long_name" => "surface air temperature (2 m), monthly mean",
              "standard_name" => "air_temperature"]
attrib_pr = ["units" => "kg m-2 s-1", "long_name" => "precipitation (accumulation rate), monthly mean",
             "standard_name" => "precipitation_flux"]
attrib_zsrf = ["units" => "m", "long_name" => "surface elevation of the reconstruction (present day, DEM)"]

# Grid, month and z_srf (DEM of the source file `src`), and the global attributes
function write_common(ds, title, src)
    defDim(ds, "lon", nx)
    defDim(ds, "lat", ny)
    defDim(ds, "month", 12)
    defVar(ds, "lon", lon, ("lon",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
    defVar(ds, "lat", lat, ("lat",); attrib=["units" => "degrees_north", "standard_name" => "latitude"])
    defVar(ds, "month", Int32.(1:12), ("month",); attrib=["units" => "1", "long_name" => "month of the year"])
    z_srf = NCDataset(s -> s["DEM"].var[:, :], src)
    defVar(ds, "z_srf", z_srf, ("lon", "lat"); fillvalue=NaN32, deflatelevel=1, attrib=attrib_zsrf)
    ds.attrib["title"] = title
    ds.attrib["references"] = "Buizert, C., Keisling, B. A., Box, J. E., He, F., Carlson, A. E., Sinclair, G., and " *
                              "DeConto, R. M.: Greenland-wide seasonal temperatures during the last deglaciation, " *
                              "Geophys. Res. Lett., 45, 1905-1914, 2018, doi:10.1002/2017GL075601. Data: NOAA/WDS " *
                              "Paleoclimatology - Greenland 22,000 Year Seasonal Temperature Reconstructions, NOAA " *
                              "NCEI, doi:10.25921/psvs-yg80"
    ds.attrib["doi"] = "10.25921/psvs-yg80"
    ds.attrib["license"] = "NOAA NCEI open data, no licence stated (no restrictions on use; cite the publication " *
                           "and the dataset)"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("paleoclimate"))
end

dir = prepared_dir("Buizert2018")
mkpath(dir)

# Transient reconstruction, written in chunks of time steps
path = joinpath(dir, "Buizert2018.nc")
rm(path; force=true)
NCDataset(path, "c") do ds
    write_common(ds, "Greenland monthly surface air temperature and precipitation, 22 ka to present " *
                     "(Buizert et al., 2018)", recon)
    defVar(ds, "time", time, ("time",); attrib=["units" => "years BP", "long_name" => "age (years before present, 1950 CE)",
                                                "comment" => "decadal means centred on the given age"])
    tas = defVar(ds, "tas", Float32, ("lon", "lat", "month", "time"); fillvalue=NaN32, deflatelevel=1,
                 chunksizes=[nx, ny, 12, 1], attrib=attrib_tas)
    pr = defVar(ds, "pr", Float32, ("lon", "lat", "month", "time"); fillvalue=NaN32, deflatelevel=1,
                chunksizes=[nx, ny, 12, 1], attrib=attrib_pr)
    NCDataset(recon) do src
        for k0 in 1:NT_CHUNK:nt
            ks = k0:min(k0 + NT_CHUNK - 1, nt)
            tas[:, :, :, ks] = src["TS2"].var[:, :, :, ks]
            pr[:, :, :, ks] = src["PRECIP"].var[:, :, :, ks] .* M_PER_S
        end
    end
end
println("Wrote $path")

# Baseline climatology 1981-2010 (TS2, PRECIP of d = month)
path = joinpath(dir, "Buizert2018_1981-2010.nc")
rm(path; force=true)
NCDataset(path, "c") do ds
    write_common(ds, "Greenland monthly surface air temperature and precipitation, 1981-2010 baseline of the " *
                     "reconstruction of Buizert et al. (2018)", baseline)
    NCDataset(baseline) do src
        dimnames(src["TS2"]) == ("r", "c", "d") || error("$baseline: unexpected dimensions of TS2")
        defVar(ds, "tas", src["TS2"].var[:, :, :], ("lon", "lat", "month"); fillvalue=NaN32, deflatelevel=1,
               attrib=attrib_tas)
        defVar(ds, "pr", src["PRECIP"].var[:, :, :] .* M_PER_S, ("lon", "lat", "month"); fillvalue=NaN32,
               deflatelevel=1, attrib=attrib_pr)
    end
end
println("Wrote $path")
