# Prepare GLAC-1D (Tarasov et al., 2012; Briggs et al., 2014; Tarasov & Peltier, 2002) for
# remapping, writing to $FESMDATA_PREPARED/Tarasov2012_glac1d/:
#
# - from the data page of L. Tarasov, the ice thickness of the regional reconstructions,
#   120-0 ka (every 1 kyr to 30 ka, every 100 years after), on their 1° x 0.5° grids:
#   Tarasov2012_GLAC1D_NA_nn9927.nc (North America + Greenland, H_ice and H_lake),
#   Tarasov2012_GLAC1D_NA_nn9894.nc (North America + Greenland, H_ice) and
#   Tarasov2012_GLAC1D_ANT_nn4041.nc (Antarctica, H_ice);
# - from the PMIP4 GLAC-1D files, global, 26-0 ka every 100 years:
#   Tarasov2012_GLAC1D_PMIP4_topo.nc (z_topo, z_srf, f_ice, 1° x 0.5°) and
#   Tarasov2012_GLAC1D_PMIP4_ice.nc (H_ice, 0.5° x 0.25°).
#
# Usage:
#     julia --project=Tarasov2012_glac1d Tarasov2012_glac1d/prepare.jl
#     julia fesmdata.jl remap IceHistory GLAC1D GLAC1D_nn9927 GLAC1D_nn9894

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

const SOURCE = "Tarasov2012_glac1d"
# The server of L. Tarasov does not send its intermediate TLS certificate
const HOST = "www.physics.mun.ca"

const REF_GR = "Tarasov, L. and Peltier, W. R.: Greenland glacial history and local geodynamic consequences, " *
               "Geophys. J. Int., 150, 198-229, 2002, doi:10.1046/j.1365-246X.2002.01702.x"
const REF_NA = "Tarasov, L., Dyke, A. S., Neal, R. M. and Peltier, W. R.: A data-calibrated distribution of " *
               "deglacial chronologies for the North American ice complex from glaciological modeling, " *
               "Earth Planet. Sci. Lett., 315-316, 30-40, 2012, doi:10.1016/j.epsl.2011.09.010"
const REF_ANT = "Briggs, R. D., Pollard, D. and Tarasov, L.: A data-constrained large ensemble analysis of " *
                "Antarctic evolution since the Eemian, Quat. Sci. Rev., 103, 91-115, 2014, " *
                "doi:10.1016/j.quascirev.2014.09.003"
const REF_EU = "Tarasov, L., Hughes, A., Gyllencreutz, R., Lohne, O. S., Mangerud, J. and Svendsen, J.-I.: " *
               "The global GLAC-1c deglaciation chronology, melwater pulse 1-a, and a question of missing " *
               "ice, IGS Symposium on Contribution of Glaciers and Ice Sheets to Sea-Level Change, 2014"
const REF_AO = "Abe-Ouchi, A., Saito, F., Kawamura, K., Raymo, M. E., Okuno, J., Takahashi, K. and " *
               "Blatter, H.: Insolation-driven 100,000-year glacial cycles and hysteresis of ice-sheet " *
               "volume, Nature, 500, 190-193, 2013, doi:10.1038/nature12374"
const LICENSE = "No licence stated by the providers (L. Tarasov, Memorial University of Newfoundland, " *
                "https://www.physics.mun.ca/~lev/dataAccess.html; PMIP4, " *
                "https://pmip4.lsce.ipsl.fr/doku.php/data:ice_glac_1d); users are asked to cite the references"

# Regional reconstructions of L. Tarasov: prepared file, prefix of the original files
# (<prefix>120kto30k.nc, <prefix>30kto0k.nc), fields (name => (source field, long_name)),
# title, references, doi
const REGIONAL = [
    ("Tarasov2012_GLAC1D_NA_nn9927.nc", "GLAC1Dnn9927NAGrB",
     ["H_ice" => ("HICE", "ice thickness (grounded and floating)"),
      "H_lake" => ("DWATER", "lake water thickness (proglacial lakes)")],
     "GLAC-1D ice thickness of North America (nn9927) and Greenland (GrB), 120-0 ka " *
     "(Tarasov et al., 2012; Tarasov and Peltier, 2002)", [REF_NA, REF_GR], "10.1016/j.epsl.2011.09.010"),
    ("Tarasov2012_GLAC1D_NA_nn9894.nc", "GLAC1Dnn9894NAGrB",
     ["H_ice" => ("HICE", "ice thickness (grounded and floating)")],
     "GLAC-1D ice thickness of North America (nn9894) and Greenland (GrB), 120-0 ka " *
     "(Tarasov et al., 2012; Tarasov and Peltier, 2002)", [REF_NA, REF_GR], "10.1016/j.epsl.2011.09.010"),
    ("Tarasov2012_GLAC1D_ANT_nn4041.nc", "GLAC1Dnn4041ANT",
     ["H_ice" => ("HICE", "ice thickness (grounded and floating)")],
     "GLAC-1D ice thickness of Antarctica (nn4041), 120-0 ka (Briggs et al., 2014)", [REF_ANT],
     "10.1016/j.quascirev.2014.09.003"),
]

# PMIP4 files: prepared file, manifest key, fields (name => (source field, units,
# long_name)), title
const PMIP4 = [
    ("Tarasov2012_GLAC1D_PMIP4_topo.nc", "glac1d_pmip4_topo",
     ["z_topo" => ("HDCB", "m", "topography relative to sea level at the time (surface of land and grounded ice, " *
                                "base of floating ice, sea floor in the open ocean)"),
      "z_srf" => ("HDC", "m", "surface elevation relative to sea level at the time (surface of land and ice, " *
                              "including ice shelves, sea floor in the open ocean)"),
      "f_ice" => ("ICEM", "1", "ice area fraction")],
     "GLAC-1D (PMIP4) topography and ice mask, 26-0 ka"),
    ("Tarasov2012_GLAC1D_PMIP4_ice.nc", "glac1d_pmip4_hice",
     ["H_ice" => ("HGLOBH", "m", "ice thickness")],
     "GLAC-1D (PMIP4) ice thickness, 26-0 ka"),
]

"Folder of the regional files of L. Tarasov (downloaded if missing)."
function tarasov_dir()
    db = manifest()
    path = get_dataset_path(db, "glac1d_tarasov")
    ispath(path) && return path
    return withenv(() -> download_dataset(db, "glac1d_tarasov"), "JULIA_SSL_NO_VERIFY_HOSTS" => HOST)
end

"""
    read_lonlat(ds, v) -> (lon, lat, perm)

The cell centres of the grid of variable `v` (dimensions lon, lat, time in the file,
ascending), with the longitudes in -180:180 and `perm` their order.
"""
function read_lonlat(ds, v)
    xname, yname, _ = dimnames(ds[v])
    lon = mod.(Float64.(ds[xname].var[:]) .+ 180, 360) .- 180
    lat = Float64.(ds[yname].var[:])
    issorted(lat) || error("$(path(ds)): latitudes not ascending")
    perm = sortperm(lon)
    return lon[perm], lat, perm
end

"Ages (years before 1950 CE) of the time axis of variable `v` (kyr, negative before present)."
read_ages(ds, v) = Float64.(round.(Int, -1000 .* ds[dimnames(ds[v])[3]].var[:]))

"Field `v` (lon, lat, time) with the longitudes reordered by `perm`."
function read_field(ds, v, perm)
    A = Float32.(ds[v].var[:, :, :])[perm, :, :]
    any(a -> abs(a) >= 1f30, A) && error("$(path(ds)): missing values in $v")
    return A
end

"""
The fields of a regional reconstruction (files `<prefix>120kto30k.nc` and
`<prefix>30kto0k.nc` in `dir`) on one time axis, 120-0 ka: the step at 30 ka, in both
files, is taken from the second (identical in the first).
"""
function read_regional(dir, prefix, fields)
    files = [joinpath(dir, prefix * p * ".nc") for p in ("120kto30k", "30kto0k")]
    parts = map(files) do file
        NCDataset(file) do ds
            v1 = first(fields)[2][1]
            lon, lat, perm = read_lonlat(ds, v1)
            (; lon, lat, ages=read_ages(ds, v1),
             data=Dict(name => read_field(ds, src, perm) for (name, (src, _)) in fields))
        end
    end
    a, b = parts
    a.lon == b.lon && a.lat == b.lat || error("$prefix: different grids in $(join(basename.(files), ", "))")
    a.ages[end] == b.ages[1] || error("$prefix: the two files do not meet ($(a.ages[end]), $(b.ages[1]))")
    for (name, _) in fields
        a.data[name][:, :, end] == b.data[name][:, :, 1] || error("$prefix: $name differs at $(b.ages[1]) years ago")
    end
    ages = vcat(a.ages[1:end-1], b.ages)
    issorted(ages; rev=true) || error("$prefix: ages not in order")
    data = Dict(name => cat(a.data[name][:, :, 1:end-1], b.data[name]; dims=3) for (name, _) in fields)
    return a.lon, a.lat, ages, data
end

"Write a prepared file: fields `data` (name => (array, units, long_name)) on lon, lat, time."
function write_prepared(file, lon, lat, ages, data; title, references, doi, comment)
    path = joinpath(prepared_dir(SOURCE), file)
    mkpath(dirname(path))
    rm(path; force=true)
    NCDataset(path, "c") do ds
        defVar(ds, "lon", lon, ("lon",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
        defVar(ds, "lat", lat, ("lat",); attrib=["units" => "degrees_north", "standard_name" => "latitude"])
        defVar(ds, "time", ages, ("time",); attrib=["units" => "years ago", "long_name" => "time (years before 1950 CE)"])
        for (name, (A, units, long_name)) in data
            defVar(ds, name, A, ("lon", "lat", "time"); deflatelevel=1,
                   attrib=["units" => units, "long_name" => long_name])
        end
        ds.attrib["title"] = title
        ds.attrib["references"] = join(references, "; ")
        ds.attrib["doi"] = doi
        ds.attrib["license"] = LICENSE
        ds.attrib["comment"] = comment
        foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("icehistory"))
    end
    println("Wrote $path")
end

dir = tarasov_dir()
for (file, prefix, fields, title, refs, doi) in REGIONAL
    lon, lat, ages, data = read_regional(dir, prefix, fields)
    write_prepared(file, lon, lat, ages,
                   [name => (data[name], "m", long_name) for (name, (_, long_name)) in fields];
                   title, references=refs, doi,
                   comment="From $(prefix)120kto30k.nc and $(prefix)30kto0k.nc of " *
                           "https://www.physics.mun.ca/~lev/dataAccess.html (the step at 30 ka from the " *
                           "second); covers only the area of its grid")
end

for (file, key, fields, title) in PMIP4
    src = download_dataset(manifest(), key)
    lon, lat, ages, data = NCDataset(src) do ds
        v1 = first(fields)[2][1]
        lon, lat, perm = read_lonlat(ds, v1)
        lon, lat, read_ages(ds, v1),
        [name => (read_field(ds, v, perm), units, long_name) for (name, (v, units, long_name)) in fields]
    end
    write_prepared(file, lon, lat, ages, data;
                   title=title * " (Tarasov et al., 2012; Briggs et al., 2014; Tarasov and Peltier, 2002)",
                   references=[REF_GR, REF_NA, REF_ANT, REF_EU, REF_AO], doi="10.1016/j.epsl.2011.09.010",
                   comment="From $(basename(src)) of the PMIP4 GLAC-1D data " *
                           "(https://pmip4.lsce.ipsl.fr/doku.php/data:ice_glac_1d): North America nn9894, " *
                           "Greenland GrB, Antarctica nn4041 and Eurasia; elevations relative to the sea " *
                           "level of the time")
end
