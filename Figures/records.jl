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
    plot_record(path, file, spec) -> String

The figure of a record: maps of its sites (coloured by the variable shown, for data
without a time or depth axis) and a panel of the data: series (`timeSeries`), profiles
(`profile`) or observations through time. Returns its caption.
"""
function plot_record(path::AbstractString, file::AbstractString, spec::AbstractDict)
    unknown = setdiff(keys(spec), RECORD_FIGURE_KEYS)
    isempty(unknown) || error("$file: unknown keys of figure: $(join(unknown, ", ")) ($(join(RECORD_FIGURE_KEYS, ", ")))")
    isfile(file) || error("no $file")
    NCDataset(file) do ds
        inst = only(dimnames(ds["lat"]))
        lon, lat = Float64.(coalesce.(ds["lon"][:], NaN)), Float64.(coalesce.(ds["lat"][:], NaN))
        var = get(spec, "variable", record_variable(ds, inst))
        v = ds[var]
        units = get(v.attrib, "units", "")
        label = var * (isempty(units) || units == "1" ? "" : " ($units)")
        names = instance_names(ds, inst)
        other = [d for d in dimnames(v) if d != inst]
        n = length(lon)
        shown = n > MAX_POINTS ? round.(Int, range(1, n; length=MAX_POINTS)) : collect(1:n)
        # Values at the sites colour the maps when the variable has no other axis
        values = isempty(other) ? Float64.(coalesce.(v[:], NaN)) : nothing
        scale = values === nothing ? nothing : continuous_scale(values[shown])

        fig = Figure(; fontsize=10, figure_padding=6)
        panels, outside = map_panels(lon[shown], lat[shown])
        sc = nothing
        for (j, (og, idx)) in enumerate(panels)
            ax = map_axis(fig[1, j], og; title=og.grid.name)
            coastline!(ax, og)
            i = shown[idx]
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
        isempty(panels) && error("$file: no sites within the domains $(join(RECORD_MAP_DOMAINS, ", "))")
        values === nothing || Colorbar(fig[1, length(panels)+1], sc; label=label, ticklabelsize=9, labelsize=10, width=10)
        data_panel!(fig[1, length(panels)+2], ds, v, inst, other, label, names, shown)
        rowsize!(fig.layout, 1, Fixed(PANEL_HEIGHT))
        resize_to_layout!(fig)
        save(path, fig; px_per_unit=1)
        caption = "$(basename(file)): $(length(unique(names === nothing ? (1:n) : names))) " *
                  "$(names === nothing ? "observations" : inst == "region" ? "regions" : "sites"), $var"
        return caption * (outside > 0 ? " ($outside outside the maps)." : ".")
    end
end

"""
    data_panel!(pos, ds, v, inst, other, label, names, shown)

The data of a record next to its maps: a line per instance against time or depth (the
other dimension of the variable), or the observations against their time; nothing for
data at sites only.
"""
function data_panel!(pos, ds, v, inst, other, label, names, shown)
    if isempty(other)
        t = time_of(ds, inst)
        t === nothing && return
        x, xlabel, rev = time_axis(ds, t)
        ax = Axis(pos; xlabel=xlabel, ylabel=label, xreversed=rev, width=2 * PANEL_HEIGHT)
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
        ax = Axis(pos; xlabel=label, ylabel="depth (m)", yreversed=true, width=round(Int, 1.2 * PANEL_HEIGHT))
        depth = Float64.(ds["depth"][:])
        for k in axes(data, 1)
            lines!(ax, data[k, :], depth; label=labels[k])
        end
    else
        t = time_of(ds, d)
        t === nothing && error("$label: no time on its dimension $d")
        x, xlabel, rev = time_axis(ds, t)
        ax = Axis(pos; xlabel=xlabel, ylabel=label, xreversed=rev, width=2 * PANEL_HEIGHT)
        for k in axes(data, 1)
            ok = isfinite.(data[k, :])
            lines!(ax, x[ok], data[k, ok]; label=labels[k], linewidth=0.8)
        end
    end
    size(data, 1) <= 8 && axislegend(ax; labelsize=8, framevisible=false, patchsize=(10, 6))
end
