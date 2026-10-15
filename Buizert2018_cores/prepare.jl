# Prepare the seasonal temperatures at Greenland ice core sites of Buizert et al. (2018)
# as a record (see Records/README.md): the table of the cores of the NOAA NCEI archive
# (datamanifest key buizert2018_cores), annual and seasonal mean temperatures every 20
# years from 22 ka to present at nine sites, as time series (featureType timeSeries),
# $FESMDATA_PREPARED/Buizert2018_cores/Buizert2018_cores.nc. The gridded reconstruction
# of the same work is Paleoclimate-Buizert2018 (../Buizert2018).
#
# Usage:
#     julia --project=Buizert2018_cores Buizert2018_cores/prepare.jl
#     julia fesmdata.jl record IceCores Buizert2018

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))
include(joinpath(@__DIR__, "..", "shared", "records_prepare.jl"))

const SEASONS = ["ANN", "DJF", "MAM", "JJA", "SON"]

txt = download_dataset(manifest(), "buizert2018_cores")

# A free header, then tab-separated blocks of 6 columns, one per site: rows "site",
# "latitude", "longitude", "elevation (m)", the column names (Age, ANN, DJF, MAM, JJA,
# SON), their units, then the data
lines = read_lines(txt)
fields(i) = strip.(split(lines[i], '\t'))
i0 = findfirst(l -> startswith(l, "site\t"), lines)
i0 === nothing && error("$txt: no row of sites")
[f[1] for f in fields.(i0:i0+5)] == ["site", "latitude", "longitude", "elevation (m)", "Age", "(yr BP)"] ||
    error("$txt: unexpected header rows")
ns = count(==("Age"), fields(i0 + 4))
block(i, k) = fields(i)[6(k-1)+1:6k]
all(block(i0 + 4, k) == ["Age"; SEASONS] for k in 1:ns) || error("$txt: unexpected columns $(fields(i0 + 4))")
sites = [Site(block(i0, k)[2], parse(Float64, block(i0 + 1, k)[2]), parse(Float64, block(i0 + 2, k)[2]);
              z_srf=parse(Float64, block(i0 + 3, k)[2])) for k in 1:ns]
data = [parse.(Float64, fields(i)[1:6ns]) for i in i0+6:length(lines) if !isempty(strip(lines[i]))]
age = [r[1] for r in data]
all(all(r[6(k-1)+1] == r[1] for k in 1:ns) for r in data) || error("$txt: the sites have different ages")
temp(s) = [r[6(k-1)+1+s] + 273.15 for r in data, k in 1:ns]

write_series(joinpath(prepared_dir("Buizert2018_cores"), "Buizert2018_cores.nc"); tag="icecores",
    sites, time=age,
    time_comment="years before 1950 CE (the ice core chronologies of the reconstruction, GICC05 in Greenland)",
    vars=[Var("tas_$(lowercase(s))", temp(j), "K",
              "$(s == "ANN" ? "annual" : s) mean surface air temperature; no correction for ice flow or elevation change")
          for (j, s) in enumerate(SEASONS)],
    title="Seasonal temperatures at Greenland ice core sites, 22 ka to present (Buizert et al., 2018)",
    references="Buizert, C., Keisling, B. A., Box, J. E., He, F., Carlson, A. E., Sinclair, G., and DeConto, R. M.: " *
               "Greenland-wide seasonal temperatures during the last deglaciation, Geophys. Res. Lett., 45, " *
               "1905-1914, 2018, doi:10.1002/2017GL075601. Data: Greenland 22,000 Year Seasonal Temperature " *
               "Reconstructions, NOAA NCEI, doi:10.25921/psvs-yg80 (buizert2018cores.txt)",
    doi="10.25921/psvs-yg80",
    license="NOAA NCEI open data, no licence stated (no restrictions on use; cite the publication)")
