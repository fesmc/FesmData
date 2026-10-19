# Records datasets (non-gridded data, see README.md): their products, defined in
# <Dataset>/records.toml, and the output files, also read by ../Publish. Needs only
# ../shared/provenance.jl.

using TOML

"""
    RecordProduct

A product of a records dataset (a table of <Dataset>/records.toml): one or more prepared
files of a source, copied as `$RECORDS_FOLDER/<Dataset>/<Dataset>-<name>.nc` (one file)
or `<Dataset>-<name>-<part>.nc` (one per part), each with its text form (`.txt`, see
text.jl) unless `text = false`.
"""
struct RecordProduct
    dataset::String
    name::String
    source::String                  # folder of the source, with prepare.jl
    files::Vector{Pair{String,String}}   # part => prepared file in $FESMDATA_PREPARED/<source>/ (part "": one file)
    text::Bool                      # whether each file has its text form
    figure::Union{Nothing,Dict{String,Any}}   # options of its figure on the website, nothing: none
end

"Path of the definition of a records dataset."
records_spec_file(dataset::AbstractString) = joinpath(REPO_DIR, dataset, "records.toml")

"Whether `dataset` is a records dataset."
is_records_dataset(dataset::AbstractString) = isfile(records_spec_file(dataset))

"""
    records_products(dataset) -> Vector{RecordProduct}

Products of a records dataset (<Dataset>/records.toml), by name. A product has either
`file` (one prepared file) or `files` (a table part => prepared file, in the order of
the parts).
"""
function records_products(dataset::AbstractString)
    is_records_dataset(dataset) || error("no records dataset $dataset (no $(records_spec_file(dataset)))")
    spec = TOML.parsefile(records_spec_file(dataset))
    products = RecordProduct[]
    for (name, p) in spec["products"]
        what = "$dataset/$name"
        unknown = setdiff(keys(p), ("source", "file", "files", "text", "figure"))
        isempty(unknown) || error("$what: unknown keys $(join(unknown, ", ")) (source, file, files, text, figure)")
        haskey(p, "file") == haskey(p, "files") && error("$what: give either file or files")
        files = if haskey(p, "file")
            ["" => p["file"]]
        else
            p["files"] isa AbstractDict && !isempty(p["files"]) || error("$what: files must be a table part = file")
            parts = sort(collect(keys(p["files"])))
            all(part -> occursin(r"^[A-Za-z0-9_]+$", part), parts) ||
                error("$what: parts may only have letters, digits and _: $(join(parts, ", "))")
            [part => p["files"][part] for part in parts]
        end
        push!(products, RecordProduct(dataset, name, p["source"], files, get(p, "text", true),
                                      figure_spec(get(p, "figure", Dict()), what)))
    end
    return sort(products; by=p -> p.name)
end

"Name of a product: <Dataset>-<name>."
product_name(p::RecordProduct) = "$(p.dataset)-$(p.name)"

"Name of the output file of a part of a product, without extension: <Dataset>-<name>[-<part>]."
part_name(p::RecordProduct, part::AbstractString) = isempty(part) ? product_name(p) : "$(product_name(p))-$part"

"Prepared files of a product, part => path."
prepared_files(p::RecordProduct) = [part => joinpath(prepared_dir(p.source), f) for (part, f) in p.files]

"Folder of the records of a dataset: \$FESMDATA/$RECORDS_FOLDER/<Dataset>."
records_dir(dataset::AbstractString) = joinpath(fesmdata_dir("products"), RECORDS_FOLDER, dataset)

"Output files (NetCDF) of a product, part => path."
record_paths(p::RecordProduct) = [part => joinpath(records_dir(p.dataset), part_name(p, part) * ".nc") for (part, _) in p.files]

"Text form of an output file: the same path with .txt instead of .nc."
text_path(path::AbstractString) = splitext(path)[1] * ".txt"

"Files of a release of a records dataset (see ../Publish): the NetCDF files and their text forms."
records_release_files(dataset::AbstractString) =
    [name * ext for p in records_products(dataset) for (part, _) in p.files
     for name in (part_name(p, part),) for ext in (p.text ? (".nc", ".txt") : (".nc",))]
