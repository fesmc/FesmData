# Prepare the PMIP3 (CMIP5) lgm, midHolocene and piControl climatologies for remapping:
# the annual and seasonal means of the CVDP output (cvdp_data files, see README.md), one
# file per model and experiment on the model's own lon-lat grid,
# $FESMDATA_WORK/prepared/PMIP3_cvdp/PMIP3_<model>_<experiment>.nc, and the PMIP3 LGM
# boundary conditions, PMIP3_lgm_boundary_conditions.nc.
#
# Usage:
#     julia --project=PMIP3_cvdp PMIP3_cvdp/prepare.jl
#     julia fesmdata.jl remap $FESMDATA_WORK/prepared/PMIP3_cvdp/PMIP3_CCSM4_lgm.nc all --name=PMIP3-CCSM4-lgm

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))

# cvdp_data file of each model and experiment (years of the climatology in the name)
const FILES = Dict(
    "CCSM4" => ("lgm" => "CCSM4_0_lgm.cvdp_data.1800-1900.nc",
                "midHolocene" => "CCSM4_0_midHolocene.cvdp_data.1000-1300.nc",
                "piControl" => "CCSM4_0_piControl.cvdp_data.250-1300.nc"),
    "CNRM-CM5" => ("lgm" => "CNRM-CM5_0_lgm.cvdp_data.1800-1999.nc",
                   "midHolocene" => "CNRM-CM5_0_midHolocene.cvdp_data.1950-2149.nc",
                   "piControl" => "CNRM-CM5_0_piControl.cvdp_data.2400-2699.nc"),
    "FGOALS-g2" => ("lgm" => "FGOALS-g2_0_lgm.cvdp_data.550-649.nc",
                    "midHolocene" => "FGOALS-g2_0_midHolocene.cvdp_data.801-1000.nc",
                    "piControl" => "FGOALS-g2_0_piControl.cvdp_data.701-900.nc"),
    "GISS-E2-R" => ("lgm" => "GISS-E2-R_0_lgm.cvdp_data.3000-3099.nc",
                    "midHolocene" => "GISS-E2-R_0_midHolocene.cvdp_data.2500-2599.nc",
                    "piControl" => "GISS-E2-R_0_piControl.cvdp_data.3981-4530.nc"),
    "IPSL-CM5A-LR" => ("lgm" => "IPSL-CM5A-LR_0_lgm.cvdp_data.2601-2800.nc",
                       "midHolocene" => "IPSL-CM5A-LR_0_midHolocene.cvdp_data.2301-2800.nc",
                       "piControl" => "IPSL-CM5A-LR_0_piControl.cvdp_data.1800-2799.nc"),
    "MIROC-ESM" => ("lgm" => "MIROC-ESM_0_lgm.cvdp_data.4600-4699.nc",
                    "midHolocene" => "MIROC-ESM_0_midHolocene.cvdp_data.2330-2429.nc",
                    "piControl" => "MIROC-ESM_0_piControl.cvdp_data.1800-2429.nc"),
    "MPI-ESM-P" => ("lgm" => "MPI-ESM-P_0_lgm.cvdp_data.1850-1949.nc",
                    "midHolocene" => "MPI-ESM-P_0_midHolocene.cvdp_data.1850-1949.nc",
                    "piControl" => "MPI-ESM-P_0_piControl.cvdp_data.2400-3000.nc"),
    "MRI-CGCM3" => ("lgm" => "MRI-CGCM3_0_lgm.cvdp_data.2501-2600.nc",
                    "midHolocene" => "MRI-CGCM3_0_midHolocene.cvdp_data.1951-2050.nc",
                    "piControl" => "MRI-CGCM3_0_piControl.cvdp_data.2001-2350.nc"),
)

# Prepared field => (CVDP field, units, long name); CVDP gives degC and mm/day
const FIELDS = [
    "t2m_ann" => ("tas_spatialmean_ann", "degC", "near-surface (2 m) air temperature, annual mean"),
    "t2m_djf" => ("tas_spatialmean_djf", "degC", "near-surface (2 m) air temperature, DJF mean"),
    "t2m_jja" => ("tas_spatialmean_jja", "degC", "near-surface (2 m) air temperature, JJA mean"),
    "pr_ann" => ("pr_spatialmean_ann", "mm d-1", "precipitation (water equivalent), annual mean"),
    "pr_djf" => ("pr_spatialmean_djf", "mm d-1", "precipitation (water equivalent), DJF mean"),
    "pr_jja" => ("pr_spatialmean_jja", "mm d-1", "precipitation (water equivalent), JJA mean"),
    "sst_ann" => ("sst_spatialmean_ann", "degC", "sea surface temperature, annual mean"),
]

const REFERENCES =
    "Braconnot, P., Harrison, S. P., Kageyama, M., et al.: Evaluation of climate models using " *
    "palaeoclimatic data, Nat. Clim. Change, 2, 417-424, 2012, doi:10.1038/nclimate1456; " *
    "Phillips, A. S., Deser, C., and Fasullo, J.: Evaluating modes of variability in climate " *
    "models, Eos, 95, 453-455, 2014, doi:10.1002/2014EO490002 (NCAR Climate Variability " *
    "Diagnostics Package, CVDP); Brierley, C. and Wainer, I.: Inter-annual variability in the " *
    "tropical Atlantic from the Last Glacial Maximum into future climate projections simulated " *
    "by CMIP5/PMIP3, Clim. Past, 14, 1377-1390, 2018, doi:10.5194/cp-14-1377-2018"

const LICENSE =
    "CMIP5 model output (terms of use: https://pcmdi.llnl.gov/mips/cmip5/terms-of-use.html; " *
    "for some models non-commercial research and education only), processed with the NCAR " *
    "CVDP (free for non-commercial use; acknowledge the NCAR Climate Analysis Section's " *
    "Climate Variability Diagnostics Package)"

_float(A) = Float32.(coalesce.(A, NaN32))

function _write_lonlat(ds, lon, lat)
    defVar(ds, "lon", Float64.(lon), ("lon",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
    defVar(ds, "lat", Float64.(lat), ("lat",); attrib=["units" => "degrees_north", "standard_name" => "latitude"])
end

function prepare_cvdp(model, experiment, input, outdir)
    years = match(r"\.cvdp_data\.(\d+-\d+)\.nc$", input)[1]
    path = joinpath(outdir, "PMIP3_$(model)_$(experiment).nc")
    NCDataset(input) do src
        NCDataset(path, "c") do ds
            _write_lonlat(ds, src["lon"][:], src["lat"][:])
            for (name, (cvdp, units, long_name)) in FIELDS
                # Not every simulation has every field (e.g. no sst for GISS-E2-R piControl)
                haskey(src, cvdp) || (println("  $model $experiment: no $cvdp"); continue)
                defVar(ds, name, _float(src[cvdp][:, :]), ("lon", "lat"); fillvalue=NaN32, deflatelevel=1,
                       attrib=["units" => units, "long_name" => long_name])
            end
            ds.attrib["title"] = "PMIP3 $model $experiment climatology (years $years of the simulation)"
            ds.attrib["model"] = model
            ds.attrib["experiment"] = experiment
            ds.attrib["years"] = years
            ds.attrib["references"] = REFERENCES
            ds.attrib["doi"] = "10.1038/nclimate1456"
            ds.attrib["license"] = LICENSE
            ds.attrib["original_file"] = basename(input)
            foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("paleoclimate"))
        end
    end
    println("Wrote $path")
end

# PMIP3 LGM boundary conditions on their 1° grid: LGM-PI surface elevation change, land
# and ice fractions (the protocol's mask: land where sftlf = 100 %)
function prepare_bc(outdir)
    db = manifest()
    path = joinpath(outdir, "PMIP3_lgm_boundary_conditions.nc")
    read2d(key, name) = NCDataset(ds -> (ds["lon"][:], ds["lat"][:], _float(ds[name][:, :])),
                                  download_dataset(db, key))
    lon, lat, dz = read2d("pmip3_21k_orog_diff", "orog_diff")
    lon2, lat2, sftlf = read2d("pmip3_21k_sftlf", "sftlf")
    lon3, lat3, sftgif = read2d("pmip3_21k_sftgif", "sftgif")
    lon == lon2 == lon3 && lat == lat2 == lat3 || error("PMIP3 LGM boundary conditions on different grids")
    NCDataset(path, "c") do ds
        _write_lonlat(ds, lon, lat)
        for (name, F, units, long_name) in (
                ("dz_srf", dz, "m", "change of surface elevation, LGM - preindustrial"),
                ("f_land", sftlf ./ 100, "1", "land area fraction at the LGM"),
                ("f_ice", sftgif ./ 100, "1", "land ice area fraction at the LGM"))
            defVar(ds, name, Float32.(F), ("lon", "lat"); fillvalue=NaN32, deflatelevel=1,
                   attrib=["units" => units, "long_name" => long_name])
        end
        ds.attrib["title"] = "PMIP3/CMIP5 Last Glacial Maximum boundary conditions (ice sheets, v0)"
        ds.attrib["references"] = "Abe-Ouchi, A., Saito, F., Kageyama, M., et al.: Ice-sheet configuration " *
                                  "in the CMIP5/PMIP3 Last Glacial Maximum experiments, Geosci. Model " *
                                  "Dev., 8, 3621-3637, 2015"
        ds.attrib["doi"] = "10.5194/gmd-8-3621-2015"
        ds.attrib["license"] = "No licence stated (PMIP3 experimental design, https://pmip3.lsce.ipsl.fr)"
        foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("paleoclimate"))
    end
    println("Wrote $path")
end

outdir = prepared_dir("PMIP3_cvdp")
mkpath(outdir)
indir = get_dataset_path(manifest(), "pmip3_cvdp")
for model in sort(collect(keys(FILES))), (experiment, file) in FILES[model]
    input = joinpath(indir, file)
    isfile(input) || error("$input is missing: copy it from the PIK archive (PMIP3_cvdp/README.md)")
    prepare_cvdp(model, experiment, input, outdir)
end
prepare_bc(outdir)
