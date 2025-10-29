cd(@__DIR__)
import Pkg; Pkg.activate(".")

using Shapefile
using Proj
using GeoDataFrames
using GeoFormatTypes
using Rasters
using NCDatasets



# 1. Output grid definition
begin
    # Define coordinate ranges
    lon = -180:0.5:180
    lat = 0:0.5:90

    # Also define times of output
    # 18 time slices available with undefined time values for some
    time_label = [
        "Early Matuyama Chron",
        "Late Gauss Chron",
        "MIS 20-24",
        "MIS 16",
        "MIS 12",
        "MIS 10",
        "MIS 8",
        "MIS 6",
        "MIS 5d",
        "MIS 5c",
        "MIS 5b",
        "MIS 5a",
        "MIS 4",
        "45 ka",
        "40 ka",
        "35 ka",
        "30 ka",
        "LGM"]         
    time = 1:length(time_label)

    nx = length(lon)
    ny = length(lat)
    nt = length(time)

    # Create the raster: lon/lat
    r = Raster(zeros(length(lon), length(lat)); dims=(X(lon), Y(lat)))

    # Optional: add CRS metadata (e.g., WGS84)
    r = setcrs(r, EPSG(4326))

    # Create the raster: x/y proj
    crs = ProjString("+proj=laea +lat_0=90 +lon_0=0 +x_0=0 +y_0=0 +units=m +datum=WGS84")
    x = range(-9e6,9e6,step=100e3)
    y = range(-9e6,9e6,step=100e3)
    rxy = Raster(zeros(length(x), length(y)); dims=(X(x), Y(y)))
    rxy = setcrs(rxy, crs)

end

# Initialize NCDataset
begin
    path_out = "Batchelor2019_ice_masks.nc"
    ds = NCDataset(path_out, "c")
    defDim(ds, "lon", nx)
    defDim(ds, "lat", ny)
    defDim(ds, "time", nt)

    lonvar = defVar(ds, "lon", Float64, ("lon",))
    lonvar[:] = lon
    
    latvar = defVar(ds, "lat", Float64, ("lat",))
    latvar[:] = lat
    
    timevar = defVar(ds, "time", Float64, ("time",))
    timevar[:] = time

    timelabelvar = defVar(ds, "label", String, ("time",))
    timelabelvar[:] = time_label

    maskvar = defVar(ds, "mask", Int8, ("lon","lat","time"))
    maskvar[:,:,1] = r

    #attrs(maskvar)["long_name"] = "binary mask (1=feature,0=background)"
    close(ds)
    println("Wrote ", path_out)
end

begin
    # Update output dataset for each time slice
    ds = NCDataset("Batchelor2019_ice_masks.nc", "a")

    for k in 1:nt
        
        # Read shapefile and convert to raster grid
        fldr_str = string(time_label[k])
        dir = "Batchelor2019_NHextent/$(fldr_str)/hypothesised ice-sheet reconstructions/"
        filename = filter(f -> endswith(f, "_best_estimate.shp"), readdir(dir))[1]
        path_now = joinpath(dir,filename)
        shp = GeoDataFrames.read(path_now)
        if k < nt
            #shp.geometry = GeoDataFrames.reproject(shp.geometry, proj_str, GeoFormatTypes.EPSG(4326))
            mask_xy = rasterize(last,shp,fill=1,to=rxy)
            mask = Rasters.resample(mask_xy; to=r)
        else
            mask = rasterize(last,shp,fill=1,to=r)
        end
        
        mask[ismissing.(mask)] .= 0

        # Write to the file
        ds["mask"][:, :, k] = mask
        
        println("Updated time index ", k)
    end

    close(ds)
end
