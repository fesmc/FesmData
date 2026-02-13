using NCDatasets
#using NetCDF
using DimensionalData
using CairoMakie
using GeoMakie
using Statistics
using NaNStatistics
using ColorSchemes

#include("../../../../../ClimberAnalysis.jl/src/ClimberPlot.jl")
# For plotting use package available on https://github.com/awi-esc/ClimberAnalysis.jl
import .ClimberPlot as plotc


# load regridded mask on ClimberX grid

mask_5x5_con = NCDataset("/path/to/folder/mask_hosing_gl_remapcon_0.3Sv.nc");
lat= mask_5x5_con["lat"];
lon= mask_5x5_con["lon"];
mask_5x5_con_da = DimArray(mask_5x5_con["hosing"][:,:], (Dim{:lon}(lon), Dim{:lat}(lat)));


# normalize data in mask
data_to_save = mask_5x5_con_da./sum(skipmissing(mask_5x5_con_da));


# save mask to .nc file

ds = NCDataset("/path/to/folder/mask_greenland_fw_distribution.nc", "c")

# add dimension variables
function addNCDatasetVar!(ds, dimensions, name)
        defDim(ds, name, length(dimensions))
        defVar(ds, name, Array(dimensions), (name,))
return nothing
end

addNCDatasetVar!(ds, dims(data_to_save, :lat), "lat")
addNCDatasetVar!(ds, dims(data_to_save, :lon), "lon")
var_mask = defVar(ds, "mask", Array(data_to_save), ("lon","lat"));

# Define attributes
ds.attrib["title"] = "NaHosMIP greenland mask"
# write attributes
var_mask.attrib["units"] = "percentage"
var_mask.attrib["comments"] = "cell percentage for forcing freshwater around Greenland"
close(ds)









#######################################
### optional: load (and later look at) land sea ice mask of Climber-X (use any ocn.nc climber file)
ocn_data = NCDataset("/path/to/folder/ocn.nc");

lon = ocn_data["lon"];
lat = ocn_data["lat"];

focn = DimArray(ocn_data["f_ocn"][:,:,1], (Dim{:lon}(lon), Dim{:lat}(lat)));
########################################

#### plot maps used that were regridded with cdo

# mask created with create_hosing_GC3LL_grl_v2.py 
mask_orig = NCDataset("/path/to/folder/mask_gl_0.3Sv.nc");

# regridded mask on latlon 0.5x0.5deg grid (using cdo remapnn)
mask_05x05 = NCDataset("/path/to/folder/mask_gl_remapnn_highres_latlon_0.3Sv.nc");
lat= mask_05x05["lat"];
lon= mask_05x05["lon"];
mask_05x05_da = DimArray(mask_05x05["hosing"][:,:], (Dim{:lon}(lon), Dim{:lat}(lat)));

#mask_05x05_da = replace(mask_05x05_da, 9.969209968386869e36 => missing);

# regridded mask on latlon 5x5deg grid (using cdo remapcon)

mask_5x5_con = NCDataset("/path/to/folder/mask_hosing_gl_remapcon_0.3Sv.nc");
lat= mask_5x5_con["lat"];
lon= mask_5x5_con["lon"];
mask_5x5_con_da = DimArray(mask_5x5_con["hosing"][:,:], (Dim{:lon}(lon), Dim{:lat}(lat)));


# plot gl hosing mask on different grids
fig = Figure(size = (1500, 800));
ax1 = Axis(fig[1,1], 
        title = "original grid",
        xlabel = "lon",
        ylabel = "lat",
        limits = ((220,280),(230,330))
        );
plotc.global_map(replace(mask_orig["hosing"], 9.969209968386869e36 => missing), fig, ax1,ax_num=1, colors=:Reds, crange_opt=true, crange=(0,0.0004),contours=false, num_cont=100)#; crange_opt=false, crange=(0,100), ax_num=3, colors=nothing, contours::Bool=true, num_cont::Number= 6, save_out=false, outfile="Unknown_output", output_path=" ")

ax2 = Axis(fig[1,3], 
        title = "0.5x0.5 grid: remapnn",
        xlabel = "lon",
        ylabel = "lat",
        limits = ((-80,30), (40,90))
        );
plotc.global_map(mask_05x05_da, fig, ax2, ax_num=3, colors=:Reds, crange_opt=true, crange=(0,0.0004),contours=false, num_cont=100)#; crange_opt=false, crange=(0,100), ax_num=3, colors=nothing, contours::Bool=true, num_cont::Number= 6, save_out=false, outfile="Unknown_output", output_path=" ")

# plot mask on 5x5deg grid normalized
ax4 = Axis(fig[1,5], 
        title = "5x5 grid: remapcon",
        xlabel = "lon",
        ylabel = "lat",
        limits = ((-80,30), (40,90))
        );
plotc.global_map(mask_5x5_con_da./sum(skipmissing(mask_5x5_con_da)), fig, ax4, ax_num=5, colors=:Reds, crange_opt=true, crange=(0,0.2),contours=false, num_cont=100)#; crange_opt=false, crange=(0,100), ax_num=3, colors=nothing, contours::Bool=true, num_cont::Number= 6, save_out=false, outfile="Unknown_output", output_path=" ")





# land-ocn mask next to GL hosing mask

focn = DimArray(ocn_data["f_ocn"][:,:,1], (Dim{:lon}(lon), Dim{:lat}(lat)));

fig = Figure(size = (1000, 500));
ax1 = Axis(fig[1,1], 
        title = "ClimberX land-sea mask",
        xlabel = "lon",
        ylabel = "lat",
        limits = ((-80,30), (40,90))
        );
plotc.global_map(focn,fig, ax1,ax_num=1, crange_opt=true, crange=(0,2),contours=false)

ax4 = Axis(fig[1,3], 
        title = "5x5 grid: remapcon",
        xlabel = "lon",
        ylabel = "lat",
        limits = ((-80,30), (40,90))
        );
plotc.global_map(mask_5x5_con_da./sum(skipmissing(mask_5x5_con_da)), fig, ax4, ax_num=3, colors=:Reds, crange_opt=true, crange=(0,0.5),contours=false, num_cont=100)#; crange_opt=false, crange=(0,100), ax_num=3, colors=nothing, contours::Bool=true, num_cont::Number= 6, save_out=false, outfile="Unknown_output", output_path=" ")

