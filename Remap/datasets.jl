# Thematic datasets made by remapping (e.g. GHF): their products, defined in
# <Dataset>/remap.toml, and the output files, also read by ../Publish. Needs only
# ../shared/domains.jl.

using TOML

"""
    RemapProduct

A product of a thematic dataset (a table of <Dataset>/remap.toml): the fields of a
prepared file of a source, remapped onto the grids of some domains, as
`<GRID>_<Dataset>-<name>.nc`.
"""
struct RemapProduct
    dataset::String
    name::String
    source::String                  # folder of the source, with prepare.jl
    file::String                    # prepared file, in $FESMDATA_WORK/prepared/<source>/
    variables::Union{Nothing,Vector{String}}
    domains::Vector{String}         # output folders (e.g. Greenland, Global)
    method::String
    smooth::Union{String,Float64}
    min_spacing_km::Float64         # grids finer than this are left out (0: none)
end

"Spacing of a grid in km (of a lon-lat grid: its mean latitude spacing)."
spacing_km(g::ProjGrid) = maximum(spacing(g))
spacing_km(g::LonLatGrid) = 111.195 * g.dlat

"Whether a product is made on grid `og`: a grid of its domains, not finer than its `min_spacing_km`."
on_grid(p::RemapProduct, og::OutGrid) = og.folder in p.domains && spacing_km(og.grid) >= p.min_spacing_km - 1e-9

"Grids of a product (see `on_grid`)."
product_grids(p::RemapProduct) = [og for key in domain_keys() for og in Domain(key).grids if on_grid(p, og)]

"Path of the definition of a thematic dataset."
remap_spec_file(dataset::AbstractString) = joinpath(REPO_DIR, dataset, "remap.toml")

"Whether `dataset` is a thematic dataset made by remapping."
is_remap_dataset(dataset::AbstractString) = isfile(remap_spec_file(dataset))

"Release tag of a thematic dataset (provenance attributes, tags <tag>-vX.Y.Z), from Publish/datasets.toml."
function remap_tag(dataset::AbstractString)
    all = read_datasets()
    haskey(all, dataset) || error("add $dataset to Publish/datasets.toml (tag, title, readme, keywords, description)")
    return all[dataset]["tag"]
end

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
        unknown = setdiff(p["domains"], folders)
        isempty(unknown) || error("$dataset/$name: unknown domains $(join(unknown, ", ")), available: $(join(folders, ", "))")
        smooth = get(p, "smooth", "auto")
        push!(products, RemapProduct(dataset, name, p["source"], p["file"],
                                     haskey(p, "variables") ? Vector{String}(p["variables"]) : nothing,
                                     Vector{String}(p["domains"]), get(p, "method", "con"),
                                     smooth isa Real ? Float64(smooth) : String(smooth),
                                     Float64(get(p, "min_spacing_km", 0))))
    end
    return sort(products; by=p -> p.name)
end

"Name of the output files of a product: <GRID>_<name>.nc."
product_name(p::RemapProduct) = "$(p.dataset)-$(p.name)"

"Prepared file of a product."
prepared_file(p::RemapProduct) = joinpath(prepared_dir(p.source), p.file)

"Domains (output folders) of a thematic dataset."
remap_domains(dataset::AbstractString) = sort(unique(d for p in remap_products(dataset) for d in p.domains))

"""
    remap_release_files(dataset, og) -> Vector{String}

Files of a release of a thematic dataset on grid `og`: the products on its domain (see
../Publish).
"""
remap_release_files(dataset::AbstractString, og::OutGrid) =
    sort(["$(og.grid.name)_$(product_name(p)).nc" for p in remap_products(dataset) if on_grid(p, og)])
