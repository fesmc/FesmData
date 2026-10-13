# Prepare the Antarctic ice-shelf basal melt rates of Rignot et al. (2013) for remapping:
# the 1 km grid of Ant_MeltingRate.v2.nc (Dryad) as a prepared NetCDF file,
# $FESMDATA_PREPARED/Rignot2013_bmelt/Rignot2013_BMELT.nc, with the actual and
# steady-state melt rates in m yr-1 ice equivalent (positive for melting), and their
# means over the drainage basins (Regions basin set Zwally2012 on ANT-1KM, which must
# be made first), one value per basin, set on the grids by the basins of each grid
# (see RegionField in ../Remap/remap.jl).
#
# Usage:
#     julia --project=Rignot2013_bmelt Rignot2013_bmelt/prepare.jl

using FesmUtils
using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "manifest.jl"))
include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "..", "shared", "domains.jl"))

const PROJ = "+proj=stere +lat_0=-90 +lat_ts=-71 +lon_0=0 +k=1 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs"

# The melt rates of the file are in m yr-1 water equivalent (see README): converted to
# ice equivalent with the densities used by Rignot et al. (2013)
const RHO_W = 1000.0
const RHO_I = 917.0

# Fields: name, source name, long name
const FIELDS = [
    ("bmelt", "melt_actual", "basal melt rate of ice shelves, 2007-2008 (positive for melting)"),
    ("bmelt_ss", "melt_steadystate", "steady-state basal melt rate of ice shelves (no thickness change; positive for melting)"),
]

# Basin set of the basin means (Regions), on the base grid of the domain (ANT-1KM), whose
# cells include those of the source grid
const BASIN_SET = "Zwally2012"

# Groups of Zwally2012 basins of bmelt_reese and bmelt_eq_reese: those of bm_ac_reese and
# bm_eq_reese of the v1 product (BMELT-R13), recovered from its values (see README)
const REESE_GROUPS = [[1, 2, 3], [4], [5], [6], [7, 8], [9, 10, 11], [12], [13], [14], [15, 16],
                      [17, 18, 19], [20], [21, 22], [23], [24], [25], [26], [27]]

# Basins without ice-shelf cells of the source (basin 25, the northern Antarctic
# Peninsula): their mean is taken over the ice shelves of these basins instead
const NO_DATA_BASINS = Dict(25 => [24, 26])

# Basin means: name, field averaged, groups (nothing: each basin), long name
const BASIN_FIELDS = [
    ("bmelt_basin", "bmelt", nothing,
     "basal melt rate of ice shelves, 2007-2008, mean over the ice shelves of each Zwally et al. (2012) basin (positive for melting)"),
    ("bmelt_eq_basin", "bmelt_ss", nothing,
     "steady-state basal melt rate of ice shelves, mean over the ice shelves of each Zwally et al. (2012) basin (positive for melting)"),
    ("bmelt_reese", "bmelt", REESE_GROUPS,
     "basal melt rate of ice shelves, 2007-2008, mean over the ice shelves of groups of Zwally et al. (2012) basins as bm_ac_reese of FesmData v1 (positive for melting)"),
    ("bmelt_eq_reese", "bmelt_ss", REESE_GROUPS,
     "steady-state basal melt rate of ice shelves, mean over the ice shelves of groups of Zwally et al. (2012) basins as bm_eq_reese of FesmData v1 (positive for melting)"),
]

"""
    source_basins(x, y) -> B

Basins of the Regions set `BASIN_SET` on the source grid (cell centres `x`, `y` in m),
extended over the whole grid: each cell outside the basins (open ocean) gets the
nearest basin.
"""
function source_basins(x, y)
    og = Domain("ANT").grids[1]
    path = joinpath(outdir(og), "$(og.grid.name)_BASINS-$BASIN_SET.nc")
    Bb, xb, yb = NCDataset(path) do ds
        Int.(coalesce.(ds["basin"][:, :], 0)), 1e3 .* Float64.(ds["xc"][:]), 1e3 .* Float64.(ds["yc"][:])
    end
    ix, jy = indexin(x, xb), indexin(y, yb)
    (any(isnothing, ix) || any(isnothing, jy)) && error("$path: grid does not contain the source grid")
    B = Bb[Int.(ix), Int.(jy)]
    return extend_labels(B, trues(size(B)), 1.0)
end

"""
    basin_mean(F, B, basins, groups) -> Vector{Float32}

Mean of `F` (NaN outside the ice shelves) over the cells of each group of basins of `B`
(cells of equal area), for each of `basins`: the mean of its group. A group without
ice-shelf cells takes the mean over the basins of `NO_DATA_BASINS` instead.
"""
function basin_mean(F, B, basins, groups)
    mean_over(g) = (v = F[in.(B, Ref(Set(g))) .& isfinite.(F)]; isempty(v) ? NaN : sum(Float64, v) / length(v))
    M = Dict{Int,Float32}()
    for g in groups
        m = mean_over(g)
        if isnan(m)
            all(in(keys(NO_DATA_BASINS)), g) || error("basins $g have no ice-shelf cells")
            m = mean_over(unique(vcat((NO_DATA_BASINS[b] for b in g)...)))
        end
        foreach(b -> M[b] = Float32(m), g)
    end
    return [M[b] for b in basins]
end

input = get_dataset_path(manifest(), "rignot2013_melt_v2")

path = joinpath(prepared_dir("Rignot2013_bmelt"), "Rignot2013_BMELT.nc")
mkpath(dirname(path))
NCDataset(input) do src
    x = Float64.(src["xaxis"][:])
    y = Float64.(src["yaxis"][:])
    ix, jy = sortperm(x), sortperm(y)                  # y is descending in the source

    F = Dict{String,Matrix{Float32}}()
    for (name, srcname, _) in FIELDS
        A = Float64.(coalesce.(src[srcname][ix, jy], NaN))    # Julia order (x, y)
        # 0 outside the ice shelves (no data)
        F[name] = Float32[a == 0 || !isfinite(a) ? NaN : a * RHO_W / RHO_I for a in A]
    end

    B = source_basins(x[ix], y[jy])
    basins = [b for b in sort(unique(B)) if b != 0]
    sort(vcat(REESE_GROUPS...)) == basins || error("the groups of bmelt_eq_reese are not the basins $basins")
    M = Dict(name => basin_mean(F[field], B, basins, something(groups, [[b] for b in basins]))
             for (name, field, groups, _) in BASIN_FIELDS)

    NCDataset(path, "c") do ds
        defVar(ds, "x", x[ix], ("x",); attrib=["units" => "m", "standard_name" => "projection_x_coordinate"])
        defVar(ds, "y", y[jy], ("y",); attrib=["units" => "m", "standard_name" => "projection_y_coordinate"])
        defVar(ds, "crs", Int32(0), (); attrib=["grid_mapping_name" => "polar_stereographic",
                                                 "proj_params" => PROJ, "epsg_code" => "EPSG:3031"])
        for (name, _, long_name) in FIELDS
            defVar(ds, name, F[name], ("x", "y"); fillvalue=NaN32, deflatelevel=1,
                   attrib=["units" => "m yr-1", "long_name" => long_name * ", ice equivalent",
                           "grid_mapping" => "crs"])
        end
        # Basin means: one value per basin, set on the grids by their basins (Remap)
        defVar(ds, "basin", Int32.(basins), ("basin",);
               attrib=["units" => "1", "long_name" => "basin number of the Regions basin set $BASIN_SET"])
        for (name, _, _, long_name) in BASIN_FIELDS
            defVar(ds, name, M[name], ("basin",);
                   attrib=["units" => "m yr-1", "long_name" => long_name * ", ice equivalent",
                           "regions" => "BASINS-$BASIN_SET"])
        end
        ds.attrib["title"] = "Basal melt rates of Antarctic ice shelves (Rignot et al., 2013)"
        ds.attrib["references"] = "Rignot, E., Jacobs, S., Mouginot, J., and Scheuchl, B.: Ice-shelf melting " *
                                  "around Antarctica, Science, 341, 266-270, 2013, doi:10.1126/science.1235798; " *
                                  "data: Dryad, doi:10.5061/dryad.5hqbzkhg2"
        ds.attrib["doi"] = "10.5061/dryad.5hqbzkhg2"
        ds.attrib["license"] = "CC0 1.0"
        ds.attrib["comment"] = "Melt rates converted from water to ice equivalent (x $RHO_W / $RHO_I); " *
                               "cells with 0 in the original file (outside the ice shelves) are missing. " *
                               "Basin means (*_basin, *_reese, one value per basin) over the ice-shelf cells " *
                               "of the basins of the Regions basin set $BASIN_SET (ANT-1KM, extended to the " *
                               "nearest basin over the open ocean); *_reese over the groups of basins of " *
                               "bm_eq_reese of FesmData v1: " * join(join.(REESE_GROUPS, "+"), ", ") *
                               "; basins without ice-shelf cells: " *
                               join(("$b over the ice shelves of basins $(join(g, "+"))" for (b, g) in NO_DATA_BASINS), ", ")
        foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib("basalmelt"))
    end
end
println("Wrote $path")
