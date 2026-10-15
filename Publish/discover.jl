# Discovery of the products, for `fesmdata.jl search` and `cite`: the products of each dataset,
# from their definitions (<Dataset>/remap.toml, <Dataset>/records.toml,
# ../Topo/products.toml, ../Regions/basins.toml) and the registry (where they are
# released, and the products that only the registry has), with their sources and the
# READMEs of these. Standard library only.

using Unicode

include(joinpath(@__DIR__, "catalog.jl"))
include(joinpath(REPO_DIR, "Records", "datasets.jl"))

"""
    Product

A product of a dataset: its `name` in the dataset (e.g. Lucazeau2019 of GHF), the names
of its files without grid and extension (`stems`: GHF-Lucazeau2019, or one per part of a
record), its `sources` (folders of sources, with README.md and prepare.jl; for Topo and
Regions the names of their sources, see their READMEs), its `variables` (if its definition lists them)
and the domains it is released on (`domains`, empty if not released).
"""
struct Product
    dataset::String
    name::String
    stems::Vector{String}
    sources::Vector{String}
    variables::Vector{String}
    domains::Vector{String}
end

Product(dataset, name, stems, sources, variables=String[]) =
    Product(dataset, name, stems, sources, variables, String[])

"Products of a thematic dataset (<Dataset>/remap.toml); an ensemble product has the sources of its members."
function remap_definitions(dataset::AbstractString)
    spec = TOML.parsefile(remap_spec_file(dataset))["products"]
    sources(p) = haskey(p, "ensemble") ? unique(s for m in p["ensemble"] for s in sources(spec[m])) : String.(vcat(p["source"]))
    return [Product(dataset, name, ["$dataset-$name"], sources(p), String.(get(p, "variables", String[])))
            for (name, p) in spec]
end

"Products of a records dataset (<Dataset>/records.toml): a file per part."
records_definitions(dataset::AbstractString) =
    [Product(dataset, p.name, [part_name(p, part) for (part, _) in p.files], [p.source]) for p in records_products(dataset)]

"Products of Topo (../Topo/products.toml), TOPO-<product>, with the sources of all domains that have them."
function topo_definitions()
    sources = Dict{String,Vector{String}}()
    for (_, d) in TOML.parsefile(joinpath(REPO_DIR, "Topo", "products.toml")), kind in ("products", "variants")
        for (name, srcs) in get(d, kind, Dict())
            union!(get!(sources, name, String[]), srcs)
        end
    end
    return [Product("Topo", name, ["TOPO-$name"], srcs) for (name, srcs) in sources]
end

"Basin sets of Regions (../Regions/basins.toml), BASINS-<name> (its other products come from the registry)."
regions_definitions() =
    [Product("Regions", b["name"], ["BASINS-$(b["name"])"], [b["source"]])
     for b in TOML.parsefile(joinpath(REPO_DIR, "Regions", "basins.toml"))["basins"]]

"Products defined for a dataset (none if it has no definition of its products)."
function defined_products(dataset::AbstractString)
    is_remap_dataset(dataset) && return remap_definitions(dataset)
    is_records_dataset(dataset) && return records_definitions(dataset)
    dataset == "Topo" && return topo_definitions()
    dataset == "Regions" && return regions_definitions()
    return Product[]
end

"Names of the data files of a record without grid and extension (records: <Dataset>-<name>[-<part>])."
function record_stems(domain::AbstractString, files::AbstractDict)
    domain == RECORDS_FOLDER && return unique(splitext(name)[1] for name in keys(files))
    return unique(splitext(product_name(e))[1] for e in values(files) if is_data_file(e))
end

"""
    all_products(cat=RegistryCatalog()) -> Vector{Product}

The products of all datasets (../Publish/datasets.toml), by dataset and name: those
defined, and those that only the registry has (e.g. REGIONS of Regions), each with the
domains it is released on.
"""
function all_products(cat::RegistryCatalog=RegistryCatalog())
    # Definitions of a product on several domains (e.g. a basin set of Regions) as one
    defined = Dict{Tuple{String,String},Product}()
    for s in sort(collect(keys(read_site_datasets()))), p in defined_products(s)
        q = get!(defined, (p.dataset, p.name), p)
        q === p || (union!(q.stems, p.stems); union!(q.sources, p.sources); union!(q.variables, p.variables))
    end
    products = collect(values(defined))
    by_stem = Dict((p.dataset, stem) => p for p in products for stem in p.stems)
    for (domain, dataset) in cat.records, stem in record_stems(domain, cat.files_of[(domain, dataset)])
        p = get!(by_stem, (dataset, stem)) do
            name = startswith(stem, "$dataset-") ? stem[ncodeunits(dataset)+2:end] : stem
            push!(products, Product(dataset, name, [stem], String[]))[end]
        end
        domain in p.domains || push!(p.domains, domain)
    end
    return sort(products; by=p -> (p.dataset, p.name))
end

"README of a source folder (nothing if it has none, e.g. a source of Topo)."
function source_readme(source::AbstractString)
    path = joinpath(REPO_DIR, source, "README.md")
    return isfile(path) ? path : nothing
end

"Title of a README (its first heading) and its introduction (the text before the first section)."
function readme_intro(path::AbstractString)
    lines = readlines(path)
    title = something(findfirst(startswith("# "), lines), 0)
    stop = something(findnext(startswith("## "), lines, title + 1), length(lines) + 1)
    return (title=title == 0 ? "" : lines[title][3:end], intro=join(lines[title+1:stop-1], "\n"))
end

"Text in which `search` looks for the terms, normalized (lower case, without accents)."
normalized(s::AbstractString) = lowercase(Unicode.normalize(s; stripmark=true))

"""
    search_texts(products) -> Dict{Product,String}

The text of each product in which `search` looks: its dataset and the title of it
(../Publish/datasets.toml), its name, files, sources with the title and introduction of
their READMEs (authors, references), variables and domains.
"""
function search_texts(products)
    meta = read_site_datasets()
    intros = Dict{String,String}()
    source_text(s) = get!(intros, s) do
        path = source_readme(s)
        path === nothing ? s : (r = readme_intro(path); "$s\n$(r.title)\n$(r.intro)")
    end
    dataset_text(s) = haskey(meta, s) ? "$s\n$(meta[s]["title"])" : s
    return Dict(p => join([dataset_text(p.dataset), p.name, p.stems..., source_text.(p.sources)..., p.variables...,
                           p.domains...], "\n") for p in products)
end

"""
    domains_text(p, subs)

Domains of a product as shown by `search`: the domains, and the nests and crops (`subs`,
see `sub_domains`) whose parent does not have it, then how many other nests and crops
have it.
"""
function domains_text(p::Product, subs::AbstractDict)
    isempty(p.domains) && return "(not released)"
    top = filter(d -> !haskey(subs, d) || !(subs[d].parent in p.domains), p.domains)
    n = length(p.domains) - length(top)
    return join(top, " ") * (n == 0 ? "" : "$(isempty(top) ? "" : " + ")$n nests/crops")
end

"""
    search(terms; sandbox=false)

`fesmdata.jl search`: the products whose dataset, name, files, sources (with the titles
and introductions of their READMEs: authors, references), variables or domains contain
all `terms` (ignoring case and accents), by dataset, with their sources and the domains
they are released on. Without any, the words of these close to the terms.
"""
function search(terms; sandbox::Bool=false)
    products = all_products(RegistryCatalog(; sandbox=sandbox))
    texts = search_texts(products)
    found = filter(p -> all(t -> occursin(normalized(t), normalized(texts[p])), terms), products)
    if isempty(found)
        println("No products with $(join(terms, " and "))")
        words = unique(w for t in values(texts) for w in eachsplit(t, r"[^\p{L}\p{N}_]+") if length(w) >= 3)
        for t in terms
            any(p -> occursin(normalized(t), normalized(texts[p])), products) && continue
            close = close_names(t, words)
            isempty(close) || println("$t: did you mean $(join(close, ", "))?")
        end
        return
    end
    meta = read_site_datasets()
    subs = sub_domains()
    wn = maximum(p -> length(p.name), found) + 2
    ws = maximum(p -> length(join(p.sources, " ")), found) + 2
    for (k, s) in enumerate(unique(p.dataset for p in found))
        k > 1 && println()
        println(s, haskey(meta, s) ? ": $(meta[s]["title"])" : "")
        for p in filter(p -> p.dataset == s, found)
            println("  ", rpad(p.name, wn), rpad(join(p.sources, " "), ws), domains_text(p, subs))
        end
    end
    n = length(unique(p.dataset for p in found))
    println("\n$(length(found)) product$(length(found) == 1 ? "" : "s") of $n dataset$(n == 1 ? "" : "s"); the files of a dataset: julia fesmdata.jl list <Dataset>, ",
            "its references: julia fesmdata.jl cite <Dataset> [<product> ...]")
end

"""
    select_products(dataset, names; sandbox=false) -> Vector{Product}

Products of a dataset, all or those named by `names` (product names, or names of their
files without grid and extension, e.g. GHF-Lucazeau2019), with close names for unknown
ones.
"""
function select_products(dataset::AbstractString, names; sandbox::Bool=false)
    datasets = collect(keys(read_site_datasets()))
    dataset in datasets ||
        error("unknown dataset $dataset" * (isempty(close_names(dataset, datasets)) ? "" :
              ", did you mean $(join(close_names(dataset, datasets), ", "))?") * "\nDatasets: $(join(sort(datasets), ", "))")
    products = filter(p -> p.dataset == dataset, all_products(RegistryCatalog(; sandbox=sandbox)))
    isempty(names) && return products
    all_names = [n for p in products for n in [p.name; p.stems]]
    unknown = setdiff(names, all_names)
    isempty(unknown) || error(join(["no product $u of $dataset" *
                                    (isempty(close_names(u, all_names)) ? "" : ", did you mean $(join(close_names(u, all_names), ", "))?")
                                    for u in unknown], "\n") * "\nProducts: $(join((p.name for p in products), ", "))")
    return filter(p -> any(in(names), [p.name; p.stems]), products)
end

"""
    cite(args; sandbox=false)

`fesmdata.jl cite <Dataset> [<product> ...]`: where to find the references of the
products of a dataset (all, or those named): the README of each of their sources (with
the references and licence), with the products from it, and the README of the dataset
(with the references of the sources without a folder of their own, e.g. those of Topo).
"""
function cite(args; sandbox::Bool=false)
    isempty(args) && error("cite: give a dataset (and products)")
    dataset, names = args[1], args[2:end]
    products = select_products(dataset, names; sandbox=sandbox)
    meta = read_site_datasets()[dataset]
    println("$dataset: $(meta["title"])\n  README: $(joinpath(REPO_DIR, meta["readme"]))")
    sources = unique(s for p in products for s in p.sources)
    for s in filter(s -> source_readme(s) !== nothing, sources)
        path = source_readme(s)
        println("\n$s: $(readme_intro(path).title)\n  README: $path")
        println("  Products: ", join((p.name for p in products if s in p.sources), ", "))
    end
    others = filter(s -> source_readme(s) === nothing, sources)
    isempty(others) || println("\nSources with their references in the README of $dataset: ", join(others, ", "))
    unsourced = [p.name for p in products if isempty(p.sources)]
    isempty(unsourced) || println("\nMade by $dataset itself (see its README): ", join(unsourced, ", "))
    doi = unique(record_doi(read_record(d, dataset; sandbox=sandbox)[1]) for p in products for d in p.domains)
    filter!(!isempty, doi)
    isempty(doi) || println("\nDOI of the releases: ", join(("https://doi.org/$d" for d in doi), ", "))
end
