using NCDatasets
#using NetCDF
using DimensionalData
using CairoMakie


"""
    hosing_rate_ts(forcing_times, freshwater; hos_start_time=2000, fw_start=0.0)

    Creates a linear (but optinal varying, i.e. ramp-ups or -downs) hosing rate time series with dimensions `time` and `fwf`. 
    `time` is (for now) in the range of year 0 to year 10000 AD with units in years relative to 2000 AD (as usally used by the CLIMBERX model)
    `fwf` is the total freshwater flux that should be put into the system in a certain year

    
    # Arguments:
    - `forcing_times::AbstractArray`: Vector of interval length in which fwf should change/stay constant to/by corresponding value in freshwater 
    - `freshwater::AbstractVector`: Vector of freshwater values that should be at the beginning and each point of changing time 
"""
function hosing_rate_ts(forcing_times, freshwater; hos_start_time=2000, fw_start=0.0)
    # the time dimension defines here from year 0 to year 100000 
    # initialise dimension Array
    time = [i for i=-1999.0:8000.0];

    # initialize fwf Array, put 0.0 for all times before hosing starts
    fwf = [0.0 for i=1:hos_start_time];

    for (t,f) in zip(forcing_times,freshwater)
        m = (f - fw_start) / t
        append!(fwf, [m*i+fw_start for i=1:(t)])
        fw_start = f
    end
    println(length(fwf))

    append!(fwf, [fwf[end] for i=1:(length(time) - sum(forcing_times)-hos_start_time)]);

    return DimArray(fwf, (Dim{:time}(time)))
end



function create_hosing_rate_nc(hosing_ts, output_path, title)
    ds = NCDataset(output_path, "c")

    # add dimension variables
    function addNCDatasetVar!(ds, dimensions, name)
        defDim(ds, name, length(dimensions))
        defVar(ds, name, Array(dimensions), (name,))
        return nothing
    end

    addNCDatasetVar!(ds, dims(hosing_ts, :time), "time")
    fwf = defVar(ds, "fwf", hosing_ts.data, ("time",))

    # Define a global attribute
    ds.attrib["title"] = title
    
    # write a the complete data set
   # fwf[:] = 

    # write attributes
    fwf.attrib["units"] = "Sv"
    fwf.attrib["comments"] = "total amount of fw forcing per year"

    close(ds)
end

max_fwf = [0.1, 0.3];
tier = [2, 1];

for (i,j) in zip(max_fwf, tier)

    # create main files needed for protocol experiments
    out_Aab="/path/to/folder/hosing_rates/hos_rate_"*string(i)*"_tipmip-ocn-p1t"*string(j)*"-Aab.nc";
    ts_Aab = hosing_rate_ts([100,50],[i,i]);
    create_hosing_rate_nc(ts_Aab, out_Aab, "total hosing rate applied in tipmip-ocn-p1t"*string(j)*"-Aab")

    out_Acd="/path/to/folder/hosing_rates/hos_rate_"*string(i)*"_tipmip-ocn-p1t"*string(j)*"-Acd.nc";
    ts_Acd = hosing_rate_ts([100,50,100],[i,i,0.0]);
    create_hosing_rate_nc(ts_Acd, out_Acd, "total hosing rate applied in tipmip-ocn-p1t"*string(j)*"-Acd")

    # create files needed for additional experiments
    for a=2:5

        out_A_v="/path/to/folder/hosing_rates/hos_rate_"*string(i)*"_tipmip-ocn-p1t"*string(j)*"-A_v"*string(a)*".nc";
        ts_A_v = hosing_rate_ts([100,50*a,100],[i,i,0.0]);
        create_hosing_rate_nc(ts_A_v, out_A_v, "total hosing rate applied in tipmip-ocn-p1t"*string(j)*"-A_v"*string(a))

    end

end






fig = Figure(size = (900, 1000));
ax1 = Axis(fig[1,1], 
        xlabel = "time",
        ylabel = "fwf",
        limits = ((-100,500), (0,1.5))
        );
lines!(hosing_rate_ts([100,50,100,40,60,70],[0.3,0.3,0.0, 0.4, 0.1, 1.0], fw_start=0.5))

fig
