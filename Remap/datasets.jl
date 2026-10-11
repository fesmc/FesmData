# Thematic datasets made by remapping (e.g. GHF): their products, defined in
# <Dataset>/remap.toml, and the output files, also read by ../Publish. Needs only
# ../shared/domains.jl.

using TOML

"""
    RemapProduct

A product of a thematic dataset (a table of <Dataset>/remap.toml): the fields of a
prepared file of a source, remapped onto grids of some domains, as
`<GRID>_<Dataset>-<name>.nc`. `grids` gives them by domain (output folder): a minimum
spacing in km (the standard grids of the domain not finer than this; 0: all), or the
names of the grids (any grid of the domain, also those made on request, e.g. Gaussian
grids). A product is not made on the domains not in `grids`.
"""
struct RemapProduct
    dataset::String
    name::String
    source::String                  # folder of the source, with prepare.jl
    file::String                    # prepared file, in $FESMDATA_WORK/prepared/<source>/
    variables::Union{Nothing,Vector{String}}
    grids::Dict{String,Union{Float64,Vector{String}}}   # by domain: minimum spacing (km) or grid names
    method::String
    smooth::Union{String,Float64}
    release::Bool                   # part of the releases of the dataset
    figure::Dict{String,Any}        # options of its figure on the website (see ../Figures)
end

"Domains (output folders) of a product."
product_domains(p::RemapProduct) = sort(collect(keys(p.grids)))

"Spacing of a grid in km (of a lon-lat grid: its mean latitude spacing)."
spacing_km(g::ProjGrid) = maximum(spacing(g))
spacing_km(g::LonLatGrid) = 111.195 * g.dlat

"""
    on_grid(p, og) -> Bool

Whether a product is made on grid `og`: by the entry of its domain in `p.grids`, a
standard grid not finer than the minimum spacing, or a grid named in the list.
"""
function on_grid(p::RemapProduct, og::OutGrid)
    spec = get(p.grids, og.folder, nothing)
    spec === nothing && return false
    spec isa Vector && return og.grid.name in spec
    return !og.on_request && spacing_km(og.grid) >= spec - 1e-9
end

"""
    product_grid_spec(grids, what) -> Dict{String,Union{Float64,Vector{String}}}

The `grids` table of a product in remap.toml, checked: domains (output folders) with a
minimum spacing in km or a list of grid names of that domain.
"""
function product_grid_spec(grids, what)
    grids isa AbstractDict && !isempty(grids) ||
        error("$what: grids must be a table by domain, e.g. { Antarctica = 4, Global = 4 }")
    spec = Dict{String,Union{Float64,Vector{String}}}()
    for (folder, v) in grids
        names = [og.grid.name for og in folder_grids(folder)[2]]
        if v isa Real
            spec[folder] = Float64(v)
        elseif v isa AbstractVector
            unknown = setdiff(v, names)
            isempty(unknown) || error("$what: grids $(join(unknown, ", ")) are not grids of $folder, " *
                                      "available: $(join(names, ", "))")
            spec[folder] = Vector{String}(v)
        else
            error("$what: grids.$folder must be a minimum spacing in km or a list of grid names")
        end
    end
    return spec
end

"Grids of a product (see `on_grid`)."
product_grids(p::RemapProduct) = [og for key in domain_keys() for og in Domain(key).grids if on_grid(p, og)]

"Path of the definition of a thematic dataset."
remap_spec_file(dataset::AbstractString) = joinpath(REPO_DIR, dataset, "remap.toml")

"Whether `dataset` is a thematic dataset made by remapping."
is_remap_dataset(dataset::AbstractString) = isfile(remap_spec_file(dataset))

"""
    remap_products(dataset) -> Vector{RemapProduct}

Products of a thematic dataset (<Dataset>/remap.toml), by name.
"""
function remap_products(dataset::AbstractString)
    is_remap_dataset(dataset) || error("no thematic dataset $dataset (no $(remap_spec_file(dataset)))")
    spec = TOML.parsefile(remap_spec_file(dataset))
    folders = domain_folders()
    products = RemapProduct[]
    for (name, p) in spec["products"]
        keys_ = setdiff(keys(p), ("source", "file", "variables", "grids", "method", "smooth", "release", "figure"))
        isempty(keys_) || error("$dataset/$name: unknown keys $(join(keys_, ", "))")
        haskey(p, "grids") || error("$dataset/$name: no grids (a table by domain)")
        unknown = setdiff(keys(p["grids"]), folders)
        isempty(unknown) || error("$dataset/$name: unknown domains $(join(unknown, ", ")), available: $(join(folders, ", "))")
        smooth = get(p, "smooth", "auto")
        push!(products, RemapProduct(dataset, name, p["source"], p["file"],
                                     haskey(p, "variables") ? Vector{String}(p["variables"]) : nothing,
                                     product_grid_spec(p["grids"], "$dataset/$name"), get(p, "method", "con"),
                                     smooth isa Real ? Float64(smooth) : String(smooth),
                                     get(p, "release", true), get(p, "figure", Dict{String,Any}())))
    end
    return sort(products; by=p -> p.name)
end

"Name of the output files of a product: <GRID>_<name>.nc."
product_name(p::RemapProduct) = "$(p.dataset)-$(p.name)"

"Prepared file of a product."
prepared_file(p::RemapProduct) = joinpath(prepared_dir(p.source), p.file)

"Domains (output folders) on which a thematic dataset is released."
remap_domains(dataset::AbstractString) =
    sort(unique(d for p in remap_products(dataset) if p.release for d in product_domains(p)))

"""
    remap_release_files(dataset, og) -> Vector{String}

Files of a release of a thematic dataset on grid `og`: the products on its domain,
except those with `release = false` (see ../Publish).
"""
remap_release_files(dataset::AbstractString, og::OutGrid) =
    sort(["$(og.grid.name)_$(product_name(p)).nc" for p in remap_products(dataset) if p.release && on_grid(p, og)])
