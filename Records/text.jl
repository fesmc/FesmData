# Text form of a record (see README.md, Text form): the data of a NetCDF record as a
# whitespace-delimited table with a commented header, for reading without a NetCDF
# library. Made by `fesmdata.jl record` and again by `fesmdata.jl stamp` (../Publish).

using NCDatasets

"Global attributes copied to the header of the text form, if present."
const TEXT_ATTRIB = ("title", "references", "doi", "license", "featureType", "source",
                     "fesmdata_version", "fesmdata_commit")

"""
    text_layout(ds) -> (inst, row)

The instance dimension of a record (that of `lat`: station, region or obs) and the
dimension of the rows of its text form: the other dimension of the data on the
instances (time, sample, depth), or the instances themselves (point data).
"""
function text_layout(ds)
    inst = only(dimnames(ds["lat"]))
    others = Set{String}()
    for (_, v) in ds
        dn = dimnames(v)
        length(dn) == 2 && inst in dn && push!(others, only(d for d in dn if d != inst))
        length(dn) > 2 && error("$(ds.attrib["title"]): variables with $(length(dn)) dimensions have no text form " *
                                "(text = false in records.toml)")
    end
    length(others) > 1 && error("data on the instances along $(join(sort(collect(others)), ", ")): no single row " *
                                "dimension for the text form (text = false in records.toml)")
    return inst, isempty(others) ? inst : only(others)
end

"Labels of the instances in column names: their names (letters, digits and _) if unique, else 1, 2, ..."
function instance_labels(ds, inst)
    n = ds.dim[inst]
    for name in ("site_name", "region_name")
        haskey(ds, name) && dimnames(ds[name]) == (inst,) || continue
        labels = [replace(strip(string(s)), r"[^A-Za-z0-9]+" => "_") for s in ds[name][:]]
        allunique(labels) && all(!isempty, labels) && return labels
    end
    return string.(1:n)
end

"Significant digits of double-precision numbers in the text form (removes the binary noise of decimal values)."
const TEXT_DIGITS = 10

"Values of a variable for the text form: numbers as stored (times not decoded; doubles to `TEXT_DIGITS` significant digits), missing as NaN, strings quoted."
function text_values(v)
    raw = v.var[ntuple(_ -> :, ndims(v))...]
    if nonmissingtype(eltype(raw)) <: Union{AbstractString,Char}
        return [ismissing(s) ? "\"\"" : "\"" * replace(string(s), '"' => '\'') * "\"" for s in raw]
    end
    fill = get(v.attrib, "_FillValue", nothing)
    scale, offset = get(v.attrib, "scale_factor", 1), get(v.attrib, "add_offset", 0)
    short(x) = x isa Float64 ? round(x; sigdigits=TEXT_DIGITS) : x
    num(x) = ismissing(x) || (fill !== nothing && isequal(x, fill)) ? "NaN" :
             string(short(scale == 1 && offset == 0 ? x : x * scale + offset))
    return map(num, raw)
end

"""
    write_record_text(nc, txt)

Write the text form of the record `nc` to `txt`: a header of lines starting with `#`
(the global attributes, the instances with their variables, the columns with their units
and long names), a line of column names, and one line per row (see `text_layout`). A
variable on the rows is one column; on the instances and the rows, one column per
instance (`<name>_<instance>`, or `<name>` for one instance); on the rows and another
dimension (e.g. `time_bnds`), one column per index (`<name>_1`, ...). Variables on the
instances only (not point data) are listed in the header, and the names of variables on
other dimensions only (e.g. lookup tables).
"""
function write_record_text(nc::AbstractString, txt::AbstractString)
    NCDataset(nc) do ds
        inst, row = text_layout(ds)
        nrow, ninst = ds.dim[row], ds.dim[inst]
        labels = instance_labels(ds, inst)
        columns = Tuple{String,String,Vector{String}}[]          # (name, variable, values)
        site_vars, left_out = String[], String[]
        for (name, v) in ds
            dn = dimnames(v)
            row in dn || (push!(dn == (inst,) ? site_vars : left_out, name); continue)
            vals = text_values(v)
            if length(dn) == 1
                push!(columns, (name, name, vals))
            else
                other = only(d for d in dn if d != row)
                m = dn[1] == row ? vals : permutedims(vals)     # (row, other)
                names = other == inst ? (ninst == 1 ? [name] : ["$(name)_$l" for l in labels]) :
                        ["$(name)_$k" for k in 1:size(m, 2)]
                append!(columns, [(names[k], name, m[:, k]) for k in 1:size(m, 2)])
            end
        end
        widths = [max(length(c[1]), maximum(length, c[3]; init=0)) for c in columns]
        open(txt * ".part", "w") do io
            println(io, "# Text form of $(basename(nc)) (FesmData record, see https://fesmc.github.io/FesmData/records.html)")
            for k in TEXT_ATTRIB
                haskey(ds.attrib, k) || continue
                lines = split(string(ds.attrib[k]), '\n')
                println(io, "# $k: ", lines[1])
                foreach(l -> println(io, "#   ", l), lines[2:end])
            end
            if !isempty(site_vars) && row != inst
                println(io, "#\n# $inst ($ninst): label in column names; $(join(site_vars, ", "))")
                vals = Dict(name => text_values(ds[name]) for name in site_vars)
                for i in 1:ninst
                    println(io, "#   ", labels[i], ": ", join(("$name=$(vals[name][i])" for name in site_vars), ", "))
                end
            end
            isempty(left_out) || println(io, "#\n# not in the text form (other dimensions): ", join(left_out, ", "))
            println(io, "#\n# columns: name, units, long name")
            bounds_of = Dict(v.attrib["bounds"] => name for (name, v) in ds if haskey(v.attrib, "bounds"))
            for (name, var, _) in columns
                a = ds[get(bounds_of, var, var)].attrib
                long = get(a, "long_name", get(a, "standard_name", ""))
                println(io, "#   ", name, ", ", get(a, "units", "-"), ", ",
                        haskey(bounds_of, var) ? "bounds of $(bounds_of[var]): $long" : long)
            end
            println(io, "#\n# $nrow rows (one per $row) after the line of column names; missing values are NaN")
            println(io, join((lpad(c[1], w) for (c, w) in zip(columns, widths)), " "))
            for r in 1:nrow
                println(io, join((lpad(c[3][r], w) for (c, w) in zip(columns, widths)), " "))
            end
        end
    end
    mv(txt * ".part", txt; force=true)
    return txt
end
