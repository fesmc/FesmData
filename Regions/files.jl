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
    features::Vector{String}
    no_extension::Vector{String}
    params::Dict{String,Any}        # [basins.<source>] of a rule source (e.g. negis)
end

function read_basin_sets(path=joinpath(@__DIR__, "basins.toml"))
    return [BasinSet(b["name"], b["domains"], b["region"], b["source"], get(b, "id_field", ""),
                     get(b, "group_field", nothing), get(b, "features", String[]),
                     get(b, "no_extension", String[]), get(b, b["source"], Dict{String,Any}()))
            for b in TOML.parsefile(path)["basins"]]
end

"Keys of the domains with regions: all projected domains."
regions_domains() = filter(k -> Domain(k).base isa ProjGrid, domain_keys())

"Basin sets of a domain."
basin_sets(dom::Domain) = filter(b -> dom.key in b.domains, read_basin_sets())

"Output file of the regions (codes, zone, distance to the shelf break) on a grid."
regions_file(og::OutGrid) = joinpath(outdir(og), "$(og.grid.name)_REGIONS.nc")

"Output file of a basin set on a grid."
basins_file(og::OutGrid, set::BasinSet) = joinpath(outdir(og), "$(og.grid.name)_BASINS-$(set.name).nc")

"Output file of the masks of the nests and crops of the family of a domain on a grid."
domains_file(og::OutGrid) = joinpath(outdir(og), "$(og.grid.name)_DOMAINS.nc")

"Key of the root domain of a domain or nest `key` (itself, or the root of its parent)."
function root_key(key::AbstractString, all::AbstractDict=read_domains())
    parent = get(all[key], "parent", nothing)
    return parent === nothing ? String(key) : root_key(parent, all)
end

"""
    family_subdomains(key) -> Vector{NamedTuple}

The active nests and crops of the family of domain or nest `key`, its root domain with
all its nests and crops (also those of nests), sorted by key: their `key`, output
`folder`, `kind` ("nest" or "crop") and `parent` (key). A crop is active if its domain
is.
"""
function family_subdomains(key::AbstractString)
    all = read_domains()
    root = root_key(key, all)
    active(k) = get(all[k], "active", true)
    subs = NamedTuple{(:key, :folder, :kind, :parent),NTuple{4,String}}[]
    for (k, d) in all
        root_key(k, all) == root || continue
        haskey(d, "parent") && active(k) && push!(subs, (key=k, folder=d["folder"], kind="nest", parent=d["parent"]))
        for (ck, c) in get(d, "crops", Dict())
            active(k) && push!(subs, (key=ck, folder=c["folder"], kind="crop", parent=k))
        end
    end
    return sort(subs; by=s -> s.key)
end

"""
    regions_release_files(dom, og) -> Vector{String}

Files of a release of the regions on grid `og` of `dom`: the regions, the basin sets
of the domain and, in a family with nests or crops, their masks (see ../Publish).
"""
function regions_release_files(dom::Domain, og::OutGrid)
    files = vcat(basename(regions_file(og)), [basename(basins_file(og, set)) for set in basin_sets(dom)])
    isempty(family_subdomains(dom.key)) || push!(files, basename(domains_file(og)))
    return sort(files)
end
