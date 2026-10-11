# Records (see README.md): check the prepared files of non-gridded data and copy them to
# $ICE_DATA/v2/Records/<Dataset>/ (`julia fesmdata.jl record`).

using NCDatasets

include(joinpath(@__DIR__, "..", "shared", "provenance.jl"))
include(joinpath(@__DIR__, "datasets.jl"))

"Feature types of the CF discrete sampling geometries used for records."
const FEATURE_TYPES = ("point", "timeSeries", "profile", "timeSeriesProfile")

"Global attributes of a prepared record, besides the provenance attributes."
const RECORD_ATTRIB = ("title", "references", "license", "featureType")

"""
    check_record(path) -> Vector{String}

Problems of a prepared file against the form of a record (README.md, File form): the
global attributes, `featureType`, the coordinates `lat`/`lon` (and `time`, `depth` for
the feature types that need them) and the units of the variables. Empty if none.
"""
function check_record(path::AbstractString)
    problems = String[]
    NCDataset(path) do ds
        for k in (RECORD_ATTRIB..., PROVENANCE_KEYS...)
            haskey(ds.attrib, k) || push!(problems, "global attribute $k is missing")
        end
        ft = get(ds.attrib, "featureType", nothing)
        ft === nothing || ft in FEATURE_TYPES ||
            push!(problems, "featureType $ft is not one of $(join(FEATURE_TYPES, ", "))")
        for (name, units) in (("lat", "degrees_north"), ("lon", "degrees_east"))
            if !haskey(ds, name)
                push!(problems, "variable $name is missing")
            elseif get(ds[name].attrib, "units", "") != units
                push!(problems, "$name: units must be $units")
            end
        end
        ft in ("timeSeries", "timeSeriesProfile") && !haskey(ds, "time") && push!(problems, "variable time is missing")
        if haskey(ds, "time")
            u = get(ds["time"].attrib, "units", "")
            u == "years ago" || occursin(" since ", u) ||
                push!(problems, "time: units must be \"years ago\" or \"<unit> since <date>\", not \"$u\"")
        end
        if ft in ("profile", "timeSeriesProfile")
            if !haskey(ds, "depth")
                push!(problems, "variable depth is missing")
            elseif get(ds["depth"].attrib, "positive", "") != "down"
                push!(problems, "depth: attribute positive must be \"down\"")
            end
        end
        bounds = Set(v.attrib["bounds"] for (_, v) in ds if haskey(v.attrib, "bounds"))
        for (name, v) in ds
            T = nonmissingtype(eltype(v))
            (ndims(v) == 0 || T <: Union{AbstractString,Char} || name in bounds ||
             haskey(v.attrib, "flag_values")) && continue
            haskey(v.attrib, "units") || push!(problems, "$name: units are missing")
        end
    end
    return problems
end

"""
    record_dataset(dataset, args=String[]; overwrite=false) -> Vector{String}

Make the products of a records dataset (<Dataset>/records.toml): all, or those named in
`args`. A prepared file that is missing is made first by the prepare.jl of its source;
each is checked (`check_record`) and copied to `\$ICE_DATA/v2/Records/<Dataset>/`.
"""
function record_dataset(dataset::AbstractString, args=String[]; overwrite::Bool=false)
    products = records_products(dataset)
    unknown = setdiff(args, [p.name for p in products])
    isempty(unknown) || error("$dataset has no products $(join(unknown, ", ")), " *
                              "available: $(join((p.name for p in products), ", "))")
    selected = isempty(args) ? products : filter(p -> p.name in args, products)
    paths = String[]
    for p in selected
        out = record_path(p)
        if isfile(out) && !overwrite
            println("$(basename(out)): exists, skipped (--overwrite to replace)")
            continue
        end
        src = prepared_file(p)
        isfile(src) || run_prepare(p.source)
        isfile(src) || error("$(p.source)/prepare.jl did not write $src")
        problems = check_record(src)
        isempty(problems) || error("$src is not a record (see Records/README.md):\n  " * join(problems, "\n  "))
        mkpath(dirname(out))
        cp(src, out * ".part"; force=true)
        mv(out * ".part", out; force=true)
        println("$(product_name(p)): $out")
        push!(paths, out)
    end
    return paths
end

"`julia fesmdata.jl record <Dataset> [<product> ...]`"
function record_command(args; overwrite::Bool=false)
    isempty(args) && error("give a records dataset")
    return record_dataset(args[1], args[2:end]; overwrite)
end
