# Prepare the Aq1 geothermal heat flow of Antarctica (Stål et al., 2021) for remapping:
# the 20 km grid of aq1_01_20.nc (PANGAEA, datamanifest key staal2020_aq1, polar
# stereographic EPSG:3031) written to $FESMDATA_WORK/prepared/Stal2020_ghf/Stal2020_GHF.nc
# with ghf and ghf_unc in mW m-2.
#
# Usage:
#     julia --project=Stal2020_ghf Stal2020_ghf/prepare.jl
#     julia fesmdata.jl remap $FESMDATA_WORK/prepared/Stal2020_ghf/Stal2020_GHF.nc Antarctica

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

const PROJ = "+proj=stere +lat_0=-90 +lat_ts=-71 +lon_0=0 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs"

# Q (heat flow) and U (uncertainty) in W/m2 on (X, Y) in m (EPSG:3031), cropped at the
# coast; the other fields (N, sum of similarity; H, information entropy) are not used
input = download_dataset(manifest(), "staal2020_aq1")
x, y, Q, U = NCDataset(input) do ds
    all(v -> dimnames(ds[v]) == ("X", "Y"), ("Q", "U")) || error("$input: unexpected dimensions")
    Float64.(ds["X"][:]), Float64.(ds["Y"][:]), nomissing(ds["Q"][:, :], NaN), nomissing(ds["U"][:, :], NaN)
end
# The coordinates are 280 points from -2800 to 2800 km, stored in Float32: rebuild them
for c in (x, y)
    r = range(c[1], c[end]; length=length(c))
    maximum(abs, c .- r) < 1 || error("$input: coordinates not uniformly spaced")
    c .= r
end

path = joinpath(prepared_dir("Stal2020_ghf"), "Stal2020_GHF.nc")
mkpath(dirname(path))
isfile(path) && rm(path)
NCDataset(path, "c") do ds
    defVar(ds, "crs", Int32(0), (); attrib=["grid_mapping_name" => "polar_stereographic",
                                            "proj_params" => PROJ, "epsg" => "EPSG:3031"])
    defVar(ds, "x", x, ("x",); attrib=["units" => "m", "standard_name" => "projection_x_coordinate"])
    defVar(ds, "y", y, ("y",); attrib=["units" => "m", "standard_name" => "projection_y_coordinate"])
    for (name, F, long_name) in (("ghf", Q, "geothermal heat flow"),
                                 ("ghf_unc", U, "uncertainty of geothermal heat flow (U of Aq1)"))
        defVar(ds, name, Float32.(1000 .* F), ("x", "y"); fillvalue=NaN32, deflatelevel=1,
               attrib=["units" => "mW m-2", "long_name" => long_name, "grid_mapping" => "crs"])
    end
    ds.attrib["title"] = "Geothermal heat flow of Antarctica, Aq1 (Stål et al., 2021)"
    ds.attrib["references"] = "Stål, T., Reading, A. M., Halpin, J. A., and Whittaker, J. M.: Antarctic " *
                              "geothermal heat flow model: Aq1, Geochem. Geophys. Geosyst., 22, " *
                              "e2020GC009428, 2021, doi:10.1029/2020GC009428; data: Stål, T. et al.: " *
                              "Antarctic geothermal heat flow model: Aq1, PANGAEA, 2020, " *
                              "doi:10.1594/PANGAEA.924857 (aq1_01_20.nc)"
    ds.attrib["doi"] = "10.1594/PANGAEA.924857"
    ds.attrib["license"] = "CC BY 4.0"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("ghf"))
end
println("Wrote $path")
