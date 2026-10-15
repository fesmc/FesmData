# Figures of records: maps of the sites, on the domains that contain them, and their
# data (series, profiles or observations through time).

"Domains (keys) of the maps of records, in order of preference for a site."
const RECORD_MAP_DOMAINS = ["GRL-PAL", "ANT", "NH"]

"Options of the `figure` table of a records product."
const RECORD_FIGURE_KEYS = ("variable",)

"At most this many observations are drawn (evenly spaced in the file)."
const MAX_POINTS = 50_000

"Names of variables that are not data: coordinates, uncertainties, keys and names."
is_not_data(name) = name in ("lat", "lon", "z_srf", "region") || startswith(name, "time") || startswith(name, "depth") ||
                    any(s -> endswith(name, s), ("_sd", "_err", "_min", "_max", "_key", "_bnds"))

"""
    record_variable(ds, inst) -> String

The variable shown of a record by default: the first numeric data variable on the
instance dimension `inst` (station, region or obs).
"""
function record_variable(ds, inst)
    for (name, v) in ds
        is_not_data(name) && continue
        inst in dimnames(v) && nonmissingtype(eltype(v)) <: Real && return name
    end
    error("no data variable on $inst")
end

"""
    map_panels(lon, lat) -> (panels, outside)

The maps of sites: of the domains of `RECORD_MAP_DOMAINS`, those with sites, each site
on the first that contains it, on the grid of the domain shown in figures, as (grid,
indices of its sites); and the number of sites outside all of them.
"""
function map_panels(lon, lat)
    left = collect(eachindex(lon))
    panels = Tuple{OutGrid,Vector{Int}}[]
    for key in RECORD_MAP_DOMAINS
        dom = Domain(key)
        og = only(figure_grids(filter(og -> og.folder == dom.folder, dom.grids)))
        x, y = project(og, lon[left], lat[left])
        inside = [og.grid.xc[1] <= xi <= og.grid.xc[end] && og.grid.yc[1] <= yi <= og.grid.yc[end] for (xi, yi) in zip(x, y)]
        any(inside) && push!(panels, (og, left[inside]))
        left = left[.!inside]
    end
    return panels, length(left)
end

"""
    time_axis(ds, name) -> (values, label, reversed)

A time variable for plotting: in ka for years ago (reversed, the present on the right),
else in years CE.
"""
function time_axis(ds, name)
    t = ds[name][:]
    if get(ds[name].attrib, "units", "") == "years ago"
        return Float64.(coalesce.(t, NaN)) ./ 1000, "time (ka)", true
    end
    year(d) = d isa Dates.AbstractTime ? Dates.year(d) + (Dates.dayofyear(d) - 0.5) / 365.25 : NaN
    return year.(coalesce.(t, NaN)), "year", false
end

"Name of the time variable of a dimension (the variable `time` on it), or `nothing`."
time_of(ds, d) = haskey(ds, "time") && dimnames(ds["time"]) == (d,) ? "time" : nothing

"Names of the instances (sites or regions), if the record has them."
function instance_names(ds, inst)
    for name in ("site_name", "region_name")
        haskey(ds, name) && dimnames(ds[name]) == (inst,) && return String.(ds[name][:])
    end
    return nothing
end

"""
    plot_record(path, files, spec) -> String

The figure of a record product of one or more files (part => path): maps of the sites of
all its files (coloured by the variable shown, for data without a time or depth axis;
none for series of regions without a location) and a panel of the data of each file,
one under the other: series (`timeSeries`), profiles (`profile`) or observations through
time. Returns its caption.
"""
function plot_record(path::AbstractString, files::Vector{Pair{String,String}}, spec::AbstractDict)
    unknown = setdiff(keys(spec), RECORD_FIGURE_KEYS)
    isempty(unknown) || error("$(first(files)[2]): unknown keys of figure: $(join(unknown, ", ")) ($(join(RECORD_FIGURE_KEYS, ", ")))")
    for (_, file) in files
        isfile(file) || error("no $file")
    end
    dss = [NCDataset(file) for (_, file) in files]
    try
        recs = [record_data(ds, spec) for ds in dss]
        lon, lat = reduce(vcat, (r.lon[r.shown] for r in recs)), reduce(vcat, (r.lat[r.shown] for r in recs))
        names = all(r -> r.names !== nothing, recs) ? reduce(vcat, (r.names[r.shown] for r in recs)) : nothing
        # Values at the sites colour the maps when the variable has no other axis
        values = all(r -> r.values !== nothing && r.label == recs[1].label, recs) ?
                 reduce(vcat, (r.values[r.shown] for r in recs)) : nothing
        scale = values === nothing ? nothing : continuous_scale(values)
        nrows = length(recs)

        fig = Figure(; fontsize=10, figure_padding=6)
        # Series of regions without a location (e.g. global means) have no maps
        located = any(isfinite, lat)
        panels, outside = located ? map_panels(lon, lat) : (Tuple{OutGrid,Vector{Int}}[], 0)
        sc = nothing
        for (j, (og, i)) in enumerate(panels)
            ax = map_axis(fig[1:nrows, j], og; title=og.grid.name)
            coastline!(ax, og)
            x, y = project(og, lon[i], lat[i])
            ms = length(i) > 1000 ? 3 : 7
            sc = values === nothing ? scatter!(ax, x, y; color=:black, markersize=ms) :
                 scatter!(ax, x, y; color=values[i], colormap=scale.colormap, colorrange=scale.colorrange, markersize=ms,
                          strokewidth=ms > 3 ? 0.3 : 0)
            if names !== nothing && length(unique(names[i])) <= 12
                first_of = [k for k in eachindex(i) if findfirst(==(names[i[k]]), names[i]) == k]
                text!(ax, x[first_of], y[first_of]; text=names[i[first_of]], fontsize=8, offset=(4, 2))
            end
            colsize!(fig.layout, j, Fixed(round(Int, PANEL_HEIGHT * map_aspect(og.grid))))
        end
        located && isempty(panels) && error("$(first(files)[2]): no sites within the domains $(join(RECORD_MAP_DOMAINS, ", "))")
        values === nothing || Colorbar(fig[1:nrows, length(panels)+1], sc; label=recs[1].label, ticklabelsize=9,
                                       labelsize=10, width=10)
        for (k, (r, ds, (part, _))) in enumerate(zip(recs, dss, files))
            data_panel!(fig[k, located ? length(panels) + 2 : 1], ds, r.v, r.inst, r.other, r.label, r.names, r.shown;
                        title=part)
        end
        height = nrows == 1 ? PANEL_HEIGHT : round(Int, 0.6 * PANEL_HEIGHT)
        foreach(k -> rowsize!(fig.layout, k, Fixed(height)), 1:nrows)
        resize_to_layout!(fig)
        save_figure(path, fig)
        sites = names === nothing ? length(lon) : length(unique(names))
        kind = names === nothing ? "observations" : recs[1].inst == "region" ? "regions" : "sites"
        caption = "$(join((basename(f) for (_, f) in files), ", ")): $sites $kind, $(join(unique(r.var for r in recs), ", "))"
        return caption * (outside > 0 ? " ($outside outside the maps)." : ".")
    finally
        foreach(close, dss)
    end
end

"""
    record_data(ds, spec) -> NamedTuple

What the figure of a record shows of one file: its instance dimension, sites, the
variable shown (`spec["variable"]` or the first data variable), its label and other
dimensions, the values at the sites (for a variable without other dimensions) and the
indices of the instances drawn (at most `MAX_POINTS`).
"""
function record_data(ds, spec)
    inst = only(dimnames(ds["lat"]))
    lon, lat = Float64.(coalesce.(ds["lon"][:], NaN)), Float64.(coalesce.(ds["lat"][:], NaN))
    var = get(spec, "variable", record_variable(ds, inst))
    v = ds[var]
    units = get(v.attrib, "units", "")
    label = var * (isempty(units) || units == "1" ? "" : " ($units)")
    other = [d for d in dimnames(v) if d != inst]
    n = length(lon)
    shown = n > MAX_POINTS ? round.(Int, range(1, n; length=MAX_POINTS)) : collect(1:n)
    values = isempty(other) ? Float64.(coalesce.(v[:], NaN)) : nothing
    return (; inst, lon, lat, names=instance_names(ds, inst), var, v, label, other, values, shown)
end

"""
    data_panel!(pos, ds, v, inst, other, label, names, shown; title="")

The data of a record next to its maps: a line per instance against time or depth (the
other dimension of the variable), or the observations against their time; nothing for
data at sites only.
"""
function data_panel!(pos, ds, v, inst, other, label, names, shown; title::AbstractString="")
    if isempty(other)
        t = time_of(ds, inst)
        t === nothing && return
        x, xlabel, rev = time_axis(ds, t)
        ax = Axis(pos; xlabel=xlabel, ylabel=label, xreversed=rev, width=2 * PANEL_HEIGHT, title=title, titlesize=10)
        y = Float64.(coalesce.(v[:], NaN))[shown]
        scatter!(ax, x[shown], y; markersize=length(shown) > 1000 ? 2 : 5, color=(:black, 0.5))
        # The bulk of the observations, without the outliers
        ok = isfinite.(x[shown]) .& isfinite.(y)
        if count(ok) > 100
            xlims!(ax, quantile(x[shown][ok], (0.005, 0.995))...)
            ylims!(ax, quantile(y[ok], (0.005, 0.995))...)
        end
        return
    end
    d = only(other)
    data = Float64.(coalesce.(dimnames(v)[1] == inst ? v[:, :] : permutedims(v[:, :]), NaN))   # (instance, d)
    labels = names === nothing ? string.(1:size(data, 1)) : names
    if d == "depth"
        ax = Axis(pos; xlabel=label, ylabel="depth (m)", yreversed=true, width=round(Int, 1.2 * PANEL_HEIGHT), title=title,
                  titlesize=10)
        depth = Float64.(ds["depth"][:])
        for k in axes(data, 1)
            lines!(ax, data[k, :], depth; label=labels[k])
        end
    else
        t = time_of(ds, d)
        t === nothing && error("$label: no time on its dimension $d")
        x, xlabel, rev = time_axis(ds, t)
        ax = Axis(pos; xlabel=xlabel, ylabel=label, xreversed=rev, width=2 * PANEL_HEIGHT, title=title, titlesize=10)
        for k in axes(data, 1)
            ok = isfinite.(data[k, :])
            lines!(ax, x[ok], data[k, ok]; label=labels[k], linewidth=0.8)
        end
    end
    size(data, 1) <= 8 && axislegend(ax; labelsize=8, framevisible=false, patchsize=(10, 6))
end
