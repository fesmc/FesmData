# Prepare the 3D mantle viscosity of Lloyd et al. (2024) for remapping: the viscosity
# inferred from the shear-wave speeds of GLAD-M25, global on a 0.5° grid at 201 depths
# (0-2891 km), from the supporting information of the article (datamanifest key
# lloyd2024_visc), as a prepared NetCDF file,
# $FESMDATA_PREPARED/Lloyd2024_visc/Lloyd2024_visc.nc, with log10_visc (on depth).
#
# Usage:
#     julia --project=Lloyd2024_visc Lloyd2024_visc/prepare.jl
#     julia fesmdata.jl remap $FESMDATA_PREPARED/Lloyd2024_visc/Lloyd2024_visc.nc Antarctica

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

const KEY = "lloyd2024_visc"
const FILE = "3D_visc_infer_GLAD-M25.nc"

# The supporting information, ggad455_supplemental_files.zip (downloaded by hand, see
# README.md), holds 3D_visc_infer_GLAD-M25.nc.tar.gz: extracted next to it if not done yet.
function original_file()
    dir = get_dataset_path(manifest(), KEY)
    zip = joinpath(dir, "ggad455_supplemental_files.zip")
    nc = joinpath(dir, FILE)
    if !isfile(nc)
        isfile(zip) || error("$zip is missing: download it by hand (see Lloyd2024_visc/README.md)")
        run(`unzip -o -q $zip $FILE.tar.gz -d $dir`)
        run(`tar -xzf $(joinpath(dir, "$FILE.tar.gz")) -C $dir`)
    end
    return nc
end

# log10eta (longitude, latitude, depth) in Julia order: lon -180:0.5:180, lat
# -90:0.5:90, depth in km. The column at 180° is the same meridian as -180° and is
# dropped (it differs from it at 15% of the points, by 0.003 on average, up to 6 at a
# few points).
lon0, lat, depth_km, E = NCDataset(original_file()) do ds
    Float64.(ds["longitude"][:]), Float64.(ds["latitude"][:]), Float64.(ds["depth"][:]),
    Float32.(ds["log10eta"].var[:, :, :])
end
(lon0[1] == -180 && lon0[end] == 180) || error("$FILE: longitudes $(lon0[1]):$(lon0[end]), expected -180:180")
(issorted(lon0) && issorted(lat) && issorted(depth_km)) || error("$FILE: coordinates not ascending")
lon, E = lon0[1:end-1], E[1:end-1, :, :]

path = joinpath(prepared_dir("Lloyd2024_visc"), "Lloyd2024_visc.nc")
mkpath(dirname(path))
rm(path; force=true)
NCDataset(path, "c") do ds
    defVar(ds, "lon", lon, ("lon",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
    defVar(ds, "lat", lat, ("lat",); attrib=["units" => "degrees_north", "standard_name" => "latitude"])
    defVar(ds, "depth", 1e3 .* depth_km, ("depth",);
           attrib=["units" => "m", "standard_name" => "depth", "positive" => "down",
                   "long_name" => "depth below the surface"])
    defVar(ds, "log10_visc", E, ("lon", "lat", "depth"); fillvalue=NaN32, deflatelevel=1,
           attrib=["units" => "log10(Pa s)", "long_name" => "log10 of mantle viscosity in Pa s",
                   "source_file" => FILE])
    ds.attrib["title"] = "3D mantle viscosity inferred from GLAD-M25 (Lloyd et al., 2024)"
    ds.attrib["references"] = "Lloyd, A. J., Crawford, O., Al-Attar, D., Austermann, J., Hoggard, M. J., " *
                              "Richards, F. D. and Syvret, F.: GIA imaging of 3-D mantle viscosity based " *
                              "on palaeo sea level observations - Part I: Sensitivity kernels for an " *
                              "Earth with laterally varying viscosity, Geophys. J. Int., 236, 1139-1171, 2024"
    ds.attrib["doi"] = "10.1093/gji/ggad455"
    ds.attrib["license"] = "CC BY 4.0 (supporting information of an open-access article)"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("solidearth"))
end
println("Wrote $path")
