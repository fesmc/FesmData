# Prepare the sediment thickness of ECM1 (Mooney et al., 2023) for remapping: the total
# thickness and the thickness of its three sediment layers on the 1x1° grid of the model,
# as a prepared NetCDF file, $FESMDATA_PREPARED/Mooney2023_ecm1/Mooney2023_ECM1_sed.nc.
#
# Usage:
#     julia --project=Mooney2023_ecm1 Mooney2023_ecm1/prepare.jl
#     julia fesmdata.jl remap $FESMDATA_PREPARED/Mooney2023_ecm1/Mooney2023_ECM1_sed.nc all

using DelimitedFiles
using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

dir = download_dataset(manifest(), "ecm1_sediments")    # downloads it if missing
input = joinpath(dir, "ECM1_Sediments", "Sed_ECM1.txt")

# Sed_ECM1.txt: a header line, then one line per 1x1° cell, from 89.5°N to 89.5°S, with
# longitudes from 179.5°W to 179.5°E as the inner loop. Columns 4-7 are the total
# sediment thickness (Sed) and the thickness of the three sediment layers from the top
# (SedT1-SedT3), in m; the others are the seismic velocities and densities of the layers.
a, header = readdlm(input, '\t', Float64; header=true)
header[1:7] == ["Numb", "Lon", "Lat", "Sed", "SedT1", "SedT2", "SedT3"] ||
    error("$input: unexpected columns $(header[1:7])")
lon = collect(-179.5:1.0:179.5)
lat = collect(-89.5:1.0:89.5)
(a[:, 2] == repeat(lon, 180) && a[:, 3] == repeat(reverse(lat); inner=360)) ||
    error("$input: expected 360 x 180 cells from 89.5°N, longitudes first")
column(k) = Float32.(reverse(reshape(a[:, k], 360, 180); dims=2))

fields = [("z_sed", column(4), "sediment thickness"),
          ("z_sed_upper", column(5), "thickness of the upper sediments"),
          ("z_sed_middle", column(6), "thickness of the middle sediments"),
          ("z_sed_lower", column(7), "thickness of the lower sediments")]
all(F -> minimum(F) >= 0, getindex.(fields, 2)) || error("$input: negative thickness")
fields[1][2] == fields[2][2] .+ fields[3][2] .+ fields[4][2] ||
    error("$input: the total sediment thickness is not the sum of the layers")

path = joinpath(prepared_dir("Mooney2023_ecm1"), "Mooney2023_ECM1_sed.nc")
mkpath(dirname(path))
NCDataset(path, "c") do ds
    defVar(ds, "lon", lon, ("lon",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
    defVar(ds, "lat", lat, ("lat",); attrib=["units" => "degrees_north", "standard_name" => "latitude"])
    for (name, F, long_name) in fields
        defVar(ds, name, F, ("lon", "lat"); deflatelevel=1,
               attrib=["units" => "m", "long_name" => long_name])
    end
    ds["z_sed"].attrib["comment"] = "sum of the upper, middle and lower sediment layers of ECM1"
    ds.attrib["title"] = "Sediment thickness of the Earth Crustal Model 1 (ECM1; Mooney et al., 2023)"
    ds.attrib["references"] = "Mooney, W. D., Barrera-Lopez, C., Suárez, M. G. and Castelblanco, M. A.: " *
                              "Earth Crustal Model 1 (ECM1): A 1° x 1° global seismic and density model, " *
                              "Earth-Sci. Rev., 243, 104493, doi:10.1016/j.earscirev.2023.104493, 2023; " *
                              "data: https://www.earthcrustmodel1.com/ (Sediment Model)"
    ds.attrib["doi"] = "10.1016/j.earscirev.2023.104493"
    ds.attrib["license"] = "No licence stated by the authors (https://www.earthcrustmodel1.com/); " *
                           "cite Mooney et al. (2023)"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("sediment"))
end
println("Wrote $path")
