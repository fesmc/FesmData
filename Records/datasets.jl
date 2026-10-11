# Records datasets (non-gridded data, see README.md): their products, defined in
# <Dataset>/records.toml, and the output files, also read by ../Publish. Needs only
# ../shared/provenance.jl.

using TOML

"Output folder of the records under \$ICE_DATA/v2, next to the domain folders."
const RECORDS_FOLDER = "Records"

"""
    RecordProduct

A product of a records dataset (a table of <Dataset>/records.toml): a prepared file of
a source, copied as `$RECORDS_FOLDER/<Dataset>/<Dataset>-<name>.nc`.
"""
struct RecordProduct
    dataset::String
    name::String
    source::String                  # folder of the source, with prepare.jl
    file::String                    # prepared file, in $FESMDATA_WORK/prepared/<source>/
end

"Path of the definition of a records dataset."
records_spec_file(dataset::AbstractString) = joinpath(REPO_DIR, dataset, "records.toml")

"Whether `dataset` is a records dataset."
is_records_dataset(dataset::AbstractString) = isfile(records_spec_file(dataset))

"""
    records_products(dataset) -> Vector{RecordProduct}

Products of a records dataset (<Dataset>/records.toml), by name.
"""
function records_products(dataset::AbstractString)
    is_records_dataset(dataset) || error("no records dataset $dataset (no $(records_spec_file(dataset)))")
    spec = TOML.parsefile(records_spec_file(dataset))
    products = RecordProduct[]
    for (name, p) in spec["products"]
        unknown = setdiff(keys(p), ("source", "file"))
        isempty(unknown) || error("$dataset/$name: unknown keys $(join(unknown, ", ")) (source, file)")
        push!(products, RecordProduct(dataset, name, p["source"], p["file"]))
    end
    return sort(products; by=p -> p.name)
end

"Name of the output file of a product, without extension: <Dataset>-<name>."
product_name(p::RecordProduct) = "$(p.dataset)-$(p.name)"

"Prepared file of a product."
prepared_file(p::RecordProduct) = joinpath(prepared_dir(p.source), p.file)

"Folder of the records of a dataset: \$ICE_DATA/v2/$RECORDS_FOLDER/<Dataset>."
records_dir(dataset::AbstractString) = joinpath(_env("ICE_DATA"), "v2", RECORDS_FOLDER, dataset)

"Output file of a product."
record_path(p::RecordProduct) = joinpath(records_dir(p.dataset), product_name(p) * ".nc")

"Files of a release of a records dataset (see ../Publish)."
records_release_files(dataset::AbstractString) = [product_name(p) * ".nc" for p in records_products(dataset)]
