# Basin sets of each domain (basins.toml) and the output files of the regions, also
# read by ../Publish. Needs only ../shared/domains.jl.

using TOML

"""
    BasinSet

A basin set of basins.toml.
"""
struct BasinSet
    name::String
    domains::Vector{String}
    region::String
    source::String
    id_field::String
    group_field::Union{Nothing,String}
    no_extension::Vector{String}
end

function read_basin_sets(path=joinpath(@__DIR__, "basins.toml"))
    return [BasinSet(b["name"], b["domains"], b["region"], b["source"], b["id_field"],
                     get(b, "group_field", nothing), get(b, "no_extension", String[]))
            for b in TOML.parsefile(path)["basins"]]
end

"Basin sets of a domain."
basin_sets(dom::Domain) = filter(b -> dom.key in b.domains, read_basin_sets())

"Output file of the regions (codes, zone, distance to the shelf break) on a grid."
regions_file(og::OutGrid) = joinpath(outdir(og), "$(og.grid.name)_REGIONS.nc")

"Output file of a basin set on a grid."
basins_file(og::OutGrid, set::BasinSet) = joinpath(outdir(og), "$(og.grid.name)_BASINS-$(set.name).nc")

"""
    regions_release_files(dom, og) -> Vector{String}

Files of a release of the regions on grid `og` of `dom`: the regions and the basin sets
of the domain (see ../Publish).
"""
regions_release_files(dom::Domain, og::OutGrid) =
    sort(vcat(basename(regions_file(og)), [basename(basins_file(og, set)) for set in basin_sets(dom)]))
