# Figures of gridded products: a row per field (a variable at selected values of its
# other dimensions, e.g. time slices), a column per domain, on one grid of each.

"Most cells along the longer side of the grids shown (see `PX_PER_UNIT`)."
const MAX_SHOWN_CELLS = 800

"Order of the domains (output folders) in the figures."
const FOLDER_ORDER = ["Antarctica", "Amundsen", "Thwaites", "PineIsland", "FilchnerRonne", "Ross", "Amery",
                      "WilkesBasin", "GreenlandPaleo", "Greenland", "Jakobshavn", "NEGIS", "Petermann",
                      "Helheim", "North", "Laurentide", "Eurasia",
                      "Pyrenees", "Alps", "Patagonia", "NorthPatagonianIcefield", "SouthPatagonianIcefield",
                      "SRG", "GranCampoNevado", "CordilleraDarwin", "Himalaya", "DrangDrung", "Svalbard", "NewZealand", "Global"]

"Options of the `figure` table of a product."
const FIGURE_KEYS = ("variables", "select", "colormap", "colorrange", "scale", "hide")

"""
    figure_grids(grids) -> Vector{OutGrid}

The grids shown of a product made on `grids`: of each domain (output folder) the finest
grid with at most `MAX_SHOWN_CELLS` cells along its longer side (e.g. ANT-8KM,
GRL-PAL-4KM, GLOBAL-0.5DEG; the coarsest if all have more), except the crops of a domain
that is shown itself.
"""
function figure_grids(grids::Vector{OutGrid})
    folders = unique(og.folder for og in grids)
    parent(f) = folder_grids(f)[1].folder
    shown = filter(f -> parent(f) == f || !(parent(f) in folders), folders)
    function pick(f)
        gs = filter(og -> og.folder == f, grids)
        small = filter(og -> maximum(size(og.grid)) <= MAX_SHOWN_CELLS, gs)
        return isempty(small) ? argmin(og -> length(og.grid), gs) : argmax(og -> length(og.grid), small)
    end
    return [pick(f) for f in sort(shown; by=f -> something(findfirst(==(f), FOLDER_ORDER), length(FOLDER_ORDER) + 1))]
end

"""
    option(spec, key, var)

An option of the `figure` table for variable `var`: the value, or its entry for `var`
if it is a table by variable (`nothing` if not set).
"""
function option(spec::AbstractDict, key::AbstractString, var::AbstractString)
    v = get(spec, key, nothing)
    return v isa AbstractDict ? get(v, var, nothing) : v
end

function check_figure_spec(spec::AbstractDict, what::AbstractString)
    unknown = setdiff(keys(spec), FIGURE_KEYS)
    isempty(unknown) || error("$what: unknown keys of figure: $(join(unknown, ", ")) ($(join(FIGURE_KEYS, ", ")))")
end

# ---------------------------------------------------------------------------
# Fields: a variable at selected values of its other dimensions
# ---------------------------------------------------------------------------

"""
    Field

A row of a figure: variable `var` at the values `sel` of its dimensions other than the
grid's (dimension => value, nearest in each file).
"""
struct Field
    var::String
    sel::Vector{Pair{String,Float64}}
    label::String
end

const GRID_DIMS = ("xc", "yc", "lon", "lat")

"Values of a dimension: of its coordinate variable (not decoded), or 1..n."
coord_values(ds, d) = haskey(ds, d) ? Float64.(ds[d].var[:]) : collect(1.0:ds.dim[d])

is_years_ago(ds, d) = d == "time" && haskey(ds, d) && get(ds[d].attrib, "units", "") == "years ago"

"""
    default_values(ds, d) -> Vector{Float64}

Values of dimension `d` shown by default: 21 ka and the present for a time in years ago,
the last time of a CF time axis, January and July of a monthly climatology, else the
first.
"""
function default_values(ds, d)
    vals = coord_values(ds, d)
    if is_years_ago(ds, d)
        return unique([vals[argmin(abs.(vals .- t))] for t in (21000.0, 0.0)])
    elseif d == "time"
        return [vals[end]]
    elseif d == "month" && length(vals) == 12
        return vals[[1, 7]]
    end
    return [vals[1]]
end

"Label of a value of a dimension, e.g. \"21 ka\", \"2018-06\", \"depth 200 km\"."
function value_label(ds, d, v)
    if is_years_ago(ds, d)
        return v >= 1000 ? "$(round(v / 1000; digits=1)) ka" : "$(round(Int, v)) years ago"
    elseif d == "month" && 1 <= v <= 12
        return Dates.monthname(Int(v))
    elseif d == "time" && haskey(ds, d)
        t = ds[d][argmin(abs.(coord_values(ds, d) .- v))]
        return t isa Dates.AbstractTime ? Dates.format(t, "yyyy-mm") : "time $v"
    end
    i = argmin(abs.(coord_values(ds, d) .- v))
    # A label variable on the dimension (e.g. label(structure)), or names in an attribute
    # of its coordinate (e.g. structure_names), else its value and units
    for (name, var) in ds
        dimnames(var) == (d,) && name != d && eltype(var) <: Union{Missing,AbstractString} && return "$d $(var[i])"
    end
    if haskey(ds, d)
        for (k, names) in ds[d].attrib
            endswith(k, "_names") && return "$d $(split(names)[i])"
        end
    end
    units = haskey(ds, d) ? get(ds[d].attrib, "units", "") : ""
    units == "m" && v >= 1000 && return "$d $(round(v / 1000; sigdigits=4)) km"
    return strip("$d $(round(v; sigdigits=4)) $(units == "1" ? "" : units)")
end

"""
Data variables of a file: neither coordinates, bounds, `crs`, fractions of valid data
nor the member counts `n_<var>` of an ensemble product.
"""
data_variables(ds) = [k for k in keys(ds) if !(k in dimnames(ds)) && k != "crs" && !endswith(k, "_bnds") &&
                                              !startswith(k, "f_valid") && length(dimnames(ds[k])) >= 2 &&
                                              !(startswith(k, "n_") && haskey(ds, k[3:end]))]

"""
    figure_fields(path, variables, spec) -> Vector{Field}

The fields of a figure, from a file of the product: the variables of `spec` (default
the first of the product's `variables`, or of the file), at the values of `select`
(a value or a list for each dimension, default `default_values`).
"""
function figure_fields(path::AbstractString, variables, spec::AbstractDict)
    NCDataset(path) do ds
        vars = haskey(spec, "variables") ? Vector{String}(spec["variables"]) :
               [isempty(variables) ? first(data_variables(ds)) : first(variables)]
        select = get(spec, "select", Dict{String,Any}())
        fields = Field[]
        for v in vars
            haskey(ds, v) || error("$path has no variable $v")
            extra = [d for d in dimnames(ds[v]) if !(d in GRID_DIMS)]
            unknown = setdiff(keys(select), [d for v in vars for d in dimnames(ds[v])])
            isempty(unknown) || error("figure.select: $(join(unknown, ", ")) are no dimensions of $(join(vars, ", "))")
            choices = [haskey(select, d) ? Float64.(vcat(select[d])) : default_values(ds, d) for d in extra]
            units = get(ds[v].attrib, "units", "")
            for combo in Iterators.product(choices...)
                sel = [d => x for (d, x) in zip(extra, combo)]
                label = "$v" * (isempty(units) || units == "1" ? "" : " ($units)") *
                        (isempty(sel) ? "" : "\n" * join([value_label(ds, d, x) for (d, x) in sel], ", "))
                push!(fields, Field(v, sel, label))
            end
        end
        return fields
    end
end

"""
    read_field(path, f) -> (data, names)

A field on its grid (Float32, NaN where missing) and, for an integer variable, the
names of its codes (`flag_names`; `nothing` for a continuous field).
"""
function read_field(path::AbstractString, f::Field)
    NCDataset(path) do ds
        v = ds[f.var]
        sel = Dict(f.sel)
        idx = [d in GRID_DIMS ? Colon() : argmin(abs.(coord_values(ds, d) .- sel[d])) for d in dimnames(v)]
        data = Float32.(coalesce.(v[idx...], NaN))
        return data, nonmissingtype(eltype(v)) <: Integer ? flag_names(v.attrib) : nothing
    end
end

"""
    field_scale(f, fields, names, spec) -> ColorScale

Colour scale of a field from its data on all panels: classes for an integer variable,
else continuous, with the options `colormap`, `colorrange` and `scale` ("log10").
"""
function field_scale(f::Field, data, names, spec::AbstractDict)
    names === nothing || return class_scale(Iterators.flatten(data), names)
    cmap, crange, scale = (option(spec, k, f.var) for k in ("colormap", "colorrange", "scale"))
    scale in (nothing, "log10") || error("figure.scale of $(f.var): \"log10\" or none")
    return continuous_scale(collect(Iterators.flatten(data)); colormap=cmap === nothing ? nothing : Symbol(cmap),
                            colorrange=crange === nothing ? nothing : Tuple(crange), log=scale == "log10")
end

"""
    Panel

A column of a figure: a file on a grid, its title, and optionally the window shown
(xmin, xmax, ymin, ymax, in km; default the whole grid).
"""
struct Panel
    og::OutGrid
    path::String
    title::String
    window::Union{Nothing,NTuple{4,Float64}}
end

Panel(og::OutGrid, path::AbstractString) = Panel(og, path, og.grid.name, nothing)

"""
    plot_gridded(path, title, panels, variables, spec) -> String

The figure of a gridded product: a row per field (`figure_fields`), a column per panel,
with a colour bar per row. Returns its caption.
"""
function plot_gridded(path::AbstractString, title::AbstractString, panels::Vector{Panel}, variables,
                      spec::AbstractDict)
    check_figure_spec(spec, title)
    isempty(panels) && error("$title: no grids")
    missing_files = [p.path for p in panels if !isfile(p.path)]
    isempty(missing_files) || error("$title: missing files:\n  " * join(missing_files, "\n  "))
    fields = figure_fields(panels[1].path, variables, spec)
    fig = Figure(; fontsize=10, figure_padding=6)
    for (i, f) in enumerate(fields)
        hide = option(spec, "hide", f.var)
        read = [read_field(p.path, f) for p in panels]
        hide === nothing || foreach(((d, _),) -> replace!(d, Float32(hide) => NaN32), read)
        scale = field_scale(f, [window_data(p, d) for (p, (d, _)) in zip(panels, read)], last(read[1]), spec)
        hm = nothing
        for (j, p) in enumerate(panels)
            ax = map_axis(fig[i, j], p.og; title=i == 1 ? p.title : "", window=p.window)
            hm = field!(ax, p.og, read[j][1], scale)
        end
        scale_bar(fig[i, length(panels)+1], hm, scale; label=f.label)
    end
    for (j, p) in enumerate(panels)
        aspect = p.window === nothing ? map_aspect(p.og.grid) : (p.window[2] - p.window[1]) / (p.window[4] - p.window[3])
        colsize!(fig.layout, j, Fixed(round(Int, PANEL_HEIGHT * aspect)))
    end
    foreach(i -> rowsize!(fig.layout, i, Fixed(PANEL_HEIGHT)), 1:length(fields))
    resize_to_layout!(fig)
    save_figure(path, fig)
    return "$title on $(join(unique(p.og.grid.name for p in panels), ", ")): $(join(unique(f.var for f in fields), ", "))."
end

"The data of a panel within its window (for the colour scale)."
function window_data(p::Panel, data)
    p.window === nothing && return data
    x, y = map_coords(p.og.grid)
    ix = findall(v -> p.window[1] <= v <= p.window[2], x)
    iy = findall(v -> p.window[3] <= v <= p.window[4], y)
    return data[ix, iy]
end
