# Monthly climatologies of CMIP model output (PMIP3_cmip5, PMIP4_cmip6): the mean of each
# calendar month over the last years of a run, its seasonal means, and the writing of the
# prepared file. Needs Dates and NCDatasets in the calling environment.

using Dates
using NCDatasets

"Data pool roots of an environment variable: a ':'-separated list, searched in order."
pool_roots(var, default) = filter(!isempty, split(get(ENV, var, default), ':'))

"Whether the file can be opened for reading (the AWI pool holds files readable only by their owner)."
readable(f) = try
    open(identity, f)
    true
catch
    false
end

"""
    latest_version(candidates) -> Vector{String}

The files of the latest version among `candidates`, (version folder name, files) pairs in the
order of the pool roots, whose files are all readable; the first root wins a tie; [] if none.
"""
function latest_version(candidates)
    key(v) = (d = replace(v, r"\D" => ""); (length(d), d))
    ok = filter(c -> !isempty(c[2]) && all(readable, c[2]), candidates)
    isempty(ok) && return String[]
    best = maximum(key(c[1]) for c in ok)
    return first(c for c in ok if key(c[1]) == best)[2]
end

"Whether two coordinate vectors are the same grid (to 0.001°; fx and Amon files differ in rounding, e.g. CCSM4)."
same_grid(a, b) = length(a) == length(b) && maximum(abs.(Float64.(a) .- Float64.(b))) < 1e-3

"""
    time_records(files) -> records

Time records (file, index, year, month, length in days) of `files`. The month is that of the
middle of the time bounds if there are bounds (CESM's CAM and POP history files stamp a
monthly mean at the end of its month), else of the time itself.
"""
function time_records(files)
    recs = NamedTuple[]
    for f in files
        NCDataset(f) do ds
            t = decoded_time(ds, "time", :)
            bname = get(ds["time"].attrib, "bounds", "")
            b = haskey(ds, bname) ? decoded_time(ds, bname, :, :) : nothing
            for i in eachindex(t)
                if b === nothing
                    mid, days = t[i], Dates.daysinmonth(t[i])
                else
                    len = b[2, i] - b[1, i]
                    mid, days = b[1, i] + Dates.Millisecond(div(Dates.value(len), 2)), Dates.value(len) / 86_400_000
                end
                push!(recs, (file=f, i=i, year=Dates.year(mid), month=Dates.month(mid), days=days))
            end
        end
    end
    return recs
end

"""
    decoded_time(ds, name, indices...) -> times

The time variable `name` (time or its bounds) at `indices`, decoded with the units of time;
also where the units lack the day of the reference date (FGOALS-g2 ocean: days since 0001-01),
which NCDatasets leaves undecoded.
"""
function decoded_time(ds, name, indices...)
    m = match(r"^(\w+) since (-?\d+)-(\d+)$", strip(get(ds["time"].attrib, "units", "")))
    m === nothing && return ds[name][indices...]
    return NCDatasets.CFTime.timedecode(Float64.(ds[name].var[indices...]), "$(m[1]) since $(m[2])-$(m[3])-01",
                                        get(ds["time"].attrib, "calendar", "standard"))
end

"Years with all 12 months in the time records `recs`."
complete_years(recs) = [y for y in unique(r.year for r in recs) if count(r -> r.year == y, recs) == 12]

"The last complete year of `files`."
last_complete_year(files) = maximum(complete_years(time_records(files)))

"""
    monthly_climatology(files, name, nyears; y1=last complete year, transform=identity) -> (M, days, years)

Mean of each calendar month of the variable `name` over the `nyears` complete years in
`files` up to `y1`, or the fewer contiguous complete years up to `y1` if a year before is
incomplete or missing (a pool may miss files of a run): the dimensions of the variable
without time, × 12 (NaN for missing values); the mean length of each month in days (from the time bounds, else from the
calendar), and the first and last year used. `transform` is applied to each value before
averaging (e.g. an indicator x >= 15 for the sea-ice extent).
"""
function monthly_climatology(files, name, nyears; y1=nothing, transform=identity)
    recs = time_records(files)
    complete = complete_years(recs)
    isempty(complete) && error("$name: no complete year in $(join(basename.(files), ", "))")
    y1 === nothing && (y1 = maximum(complete))
    y1 in complete || error("$name: year $y1 not complete in $(join(basename.(files), ", "))")
    # the last contiguous complete years up to y1 (a pool may miss files of a run)
    y0 = y1
    while y0 > y1 - nyears + 1 && (y0 - 1) in complete
        y0 -= 1
    end
    sel = filter(r -> y0 <= r.year <= y1, recs)

    S = nothing
    n = zeros(Int, 12)
    days = zeros(12)
    for f in unique(r.file for r in sel)
        rs = filter(r -> r.file == f, sel)
        i = [r.i for r in rs]
        i == first(i):last(i) || error("$f: time steps not contiguous")
        NCDataset(f) do ds
            v = ds[name]
            A = Float64.(coalesce.(v[ntuple(_ -> Colon(), ndims(v) - 1)..., first(i):last(i)], NaN))
            transform === identity || (A = transform.(A))
            S === nothing && (S = zeros(size(A)[1:end-1]..., 12))
            for (k, r) in enumerate(rs)
                selectdim(S, ndims(S), r.month) .+= selectdim(A, ndims(A), k)
                n[r.month] += 1
                days[r.month] += r.days
            end
        end
    end
    all(==(y1 - y0 + 1), n) || error("$name: months missing in $y0-$y1")
    return S ./ reshape(n, ntuple(_ -> 1, ndims(S) - 1)..., 12), days ./ n, (y0, y1)
end

"Mean over the months `months` of a monthly climatology, weighted by month length."
season(M, days, months) = sum(M[:, :, m] .* days[m] for m in months) ./ sum(days[months])

"""
    tp_fields(tas, pr, days) -> (fields, monthly)

The prepared near-surface temperature [degC] and precipitation [mm d-1] fields of the
monthly climatologies `tas` [K] and `pr` [kg m-2 s-1] (either `nothing` if missing): annual,
DJF and JJA means (weighted by month length) and the monthly means, as (name, array, units,
long_name) tuples.
"""
function tp_fields(tas, pr, days)
    fields, monthly = [], []
    for (v, M, units, what) in (("t2m", tas === nothing ? nothing : tas .- 273.15, "degC", "near-surface (2 m) air temperature"),
                                ("pr", pr === nothing ? nothing : pr .* 86400, "mm d-1", "precipitation (water equivalent)"))
        M === nothing && continue
        push!(fields, ("$(v)_ann", season(M, days, 1:12), units, "$what, annual mean"),
              ("$(v)_djf", season(M, days, [12, 1, 2]), units, "$what, DJF mean"),
              ("$(v)_jja", season(M, days, 6:8), units, "$what, JJA mean"))
        push!(monthly, ("$(v)_mon", M, units, "$what, monthly mean"))
    end
    return fields, monthly
end

"""
    write_climatology(path, lon, lat, fields, monthly, attrib)

Write the 2-D `fields` (lon × lat) and `monthly` fields (lon × lat × month), each a tuple
(name, array, units, long_name), with the global attributes `attrib` (pairs).
"""
function write_climatology(path, lon, lat, fields, monthly, attrib)
    NCDataset(path, "c") do ds
        defVar(ds, "lon", Float64.(lon), ("lon",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
        defVar(ds, "lat", Float64.(lat), ("lat",); attrib=["units" => "degrees_north", "standard_name" => "latitude"])
        defVar(ds, "month", Int32.(1:12), ("month",); attrib=["units" => "1", "long_name" => "month of the year"])
        for (name, F, units, long_name) in fields
            defVar(ds, name, Float32.(F), ("lon", "lat"); fillvalue=NaN32, deflatelevel=1,
                   attrib=["units" => units, "long_name" => long_name])
        end
        for (name, F, units, long_name) in monthly
            defVar(ds, name, Float32.(F), ("lon", "lat", "month"); fillvalue=NaN32, deflatelevel=1,
                   attrib=["units" => units, "long_name" => long_name])
        end
        foreach(((k, v),) -> ds.attrib[k] = v, attrib)
    end
end
