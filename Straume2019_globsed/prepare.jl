# Prepare GlobSed v3 (Straume et al., 2019), the total sediment thickness of the
# oceans, for remapping: the 5 arc-min grid of GlobSed-v3.nc as a prepared NetCDF file,
# $FESMDATA_WORK/prepared/Straume2019_globsed/Straume2019_GlobSed.nc, with z_sed.
#
# Usage:
#     julia --project=Straume2019_globsed Straume2019_globsed/prepare.jl
#     julia fesmdata.jl remap $FESMDATA_WORK/prepared/Straume2019_globsed/Straume2019_GlobSed.nc all

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

dir = download_dataset(manifest(), "globsed_v3")    # downloads it if missing
input = joinpath(dir, "GlobSed", "GlobSed_package3", "GlobSed-v3.nc")

# GlobSed-v3.nc is gridline registered (GMT): its nodes are at multiples of 5' from
# -180 to 180 and -90 to 90, so that the column at 180° repeats the one at -180°. It
# is dropped, and the nodes are the centres of the cells of the prepared grid.
lon, lat, z = NCDataset(input) do ds
    Float64.(ds["lon"][:]), Float64.(ds["lat"][:]), Float32.(nomissing(ds["z"][:, :], NaN32))
end
(lon[1], lon[end]) == (-180.0, 180.0) || error("$input: expected longitudes -180:180")
isequal(z[1, :], z[end, :]) || error("$input: the columns at -180° and 180° differ")
lon, z = lon[1:end-1], z[1:end-1, :]

path = joinpath(prepared_dir("Straume2019_globsed"), "Straume2019_GlobSed.nc")
mkpath(dirname(path))
NCDataset(path, "c") do ds
    defVar(ds, "lon", lon, ("lon",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
    defVar(ds, "lat", lat, ("lat",); attrib=["units" => "degrees_north", "standard_name" => "latitude"])
    defVar(ds, "z_sed", z, ("lon", "lat"); fillvalue=NaN32, deflatelevel=1,
           attrib=["units" => "m", "long_name" => "total sediment thickness",
                   "comment" => "oceans and marginal seas only, missing on land"])
    ds.attrib["title"] = "Total sediment thickness of the world's oceans and marginal seas, " *
                         "version 3 (GlobSed; Straume et al., 2019)"
    ds.attrib["references"] = "Straume, E. O., Gaina, C., Medvedev, S., Hochmuth, K., Gohl, K., " *
                              "Whittaker, J. M., Abdul Fattah, R., Doornenbal, J. C. and Hopper, J. R.: " *
                              "GlobSed: Updated total sediment thickness in the world's oceans, " *
                              "Geochem. Geophys. Geosyst., 20, 1756-1772, 2019, doi:10.1029/2018GC008115; " *
                              "data: doi:10.1594/PANGAEA.982339"
    ds.attrib["doi"] = "10.1029/2018GC008115"
    ds.attrib["license"] = "CC BY 4.0 (PANGAEA, doi:10.1594/PANGAEA.982339)"
    foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("sediment"))
end
println("Wrote $path")
