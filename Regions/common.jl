# Shared definitions for the regions v2 scripts. Domains, grids and the output paths
# are those of the topography pipeline (../Topo).

include(joinpath(@__DIR__, "..", "Topo", "common.jl"))
include(joinpath(@__DIR__, "shapes.jl"))
include(joinpath(@__DIR__, "sources.jl"))
include(joinpath(@__DIR__, "tree.jl"))
include(joinpath(@__DIR__, "zone.jl"))
include(joinpath(@__DIR__, "basins.jl"))

merge!(VARINFO, Dict(
    "region_1" => ("1", "region code, level 1 (hemisphere)"),
    "region_2" => ("1", "region code, level 2"),
    "region_3" => ("1", "region code, level 3"),
    "zone" => ("1", "zone: open ocean, shelf-break buffer, continental shelf, land"),
    "dist_shelfbreak" => ("km", "distance to the shelf break, positive in the open ocean"),
    "basin" => ("1", "basin, extended over land and shelf up to the shelf break"),
    "basin_mask" => ("1", "within the original basins"),
    "basin_group" => ("1", "group of basins"),
))

"Folder for intermediate files: \$FESMDATA_WORK/regions."
regions_workdir() = joinpath(_env("FESMDATA_WORK"), "regions")

"Intermediate file of a field set (e.g. \"regions\", \"zone\") on the base grid of a domain."
regions_work_file(dom::Domain, what::AbstractString) =
    joinpath(regions_workdir(), dom.base.name, "$(dom.base.name)_$(what).nc")

"Flag values and meanings of a variable in a file, as code => name (empty without flags)."
function read_flags(path::AbstractString, var::AbstractString)
    NCDataset(path) do ds
        haskey(ds, var) && haskey(ds[var].attrib, "flag_values") || return Dict{Int,String}()
        a = ds[var].attrib
        return Dict(zip(Int.(a["flag_values"]), split(a["flag_meanings"])))
    end
end

"Flag attributes for the classes of `flags` (code => name) present in field `L`."
function flag_attrib(flags::AbstractDict, L::AbstractArray)
    present = Set(L)
    codes = sort(filter(in(present), collect(keys(flags))))
    return region_flag_attrib(codes, [flags[c] for c in codes])
end
