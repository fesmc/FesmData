# Helpers of the prepare.jl of record sources (see ../Records/README.md): readers of the
# text tables of the data centres (NOAA NCEI template, PANGAEA), a writer of time series
# at sites (featureType timeSeries), and the AICC2023 ages of the Antarctic cores and
# NGRIP (../Bouchet2023_AICC2023). Include after provenance.jl; needs NCDatasets.

using NCDatasets

const B2K_TO_BP = 50.0          # years before 2000 CE -> years before 1950 CE

# ---------------------------------------------------------------------------
# Text tables
# ---------------------------------------------------------------------------

"""
    Table

Columns of a text table by name, in order: numbers (Float64, `missing` where empty or
a missing value) where all values of a column are numbers, else strings.
"""
struct Table
    path::String
    names::Vector{String}
    columns::Vector{Vector}
end

"Values that mean missing in the text tables."
const MISSING_STRINGS = ("", "NaN", "nan", "NA", "N/A", "-")

function _parse_column(values::Vector{<:AbstractString}, missing_values)
    parse_number(s) = s in MISSING_STRINGS ? missing : something(tryparse(Float64, s), s)
    v = parse_number.(strip.(values))
    any(x -> x isa AbstractString, v) && return [x === missing ? "" : string(x) for x in v]
    return Union{Missing,Float64}[x === missing || x in missing_values ? missing : x for x in v]
end

"""
    Table(path, header, rows; missing_values=())

A table from its column names and rows of fields; numeric values in `missing_values`
(e.g. -999) become `missing`.
"""
function Table(path::AbstractString, header::Vector{<:AbstractString}, rows::Vector{<:Vector{<:AbstractString}};
               missing_values=())
    n = length(header)
    for (i, r) in enumerate(rows)
        length(r) <= n || error("$path: row $i has $(length(r)) fields, the header $n")
    end
    columns = Vector[_parse_column([j <= length(r) ? r[j] : "" for r in rows], missing_values) for j in 1:n]
    return Table(String(path), String.(strip.(header)), columns)
end

"""
    column(t, name) -> Vector

The column of a table with the name `name` (a string: exact name; a regex: the only
matching name).
"""
function column(t::Table, name::Union{AbstractString,Regex})
    idx = name isa Regex ? findall(n -> occursin(name, n), t.names) : findall(==(name), t.names)
    length(idx) == 1 || error("$(t.path): $(isempty(idx) ? "no" : "several") columns $name in " *
                              join(t.names, " | "))
    return t.columns[only(idx)]
end

"Number of rows of a table."
nrows(t::Table) = isempty(t.columns) ? 0 : length(t.columns[1])

"Lines of a text file, with \\r\\n or \\r line ends, decoded as UTF-8 or else Latin-1."
function read_lines(path::AbstractString)
    bytes = read(path)
    s = isvalid(String, bytes) ? String(bytes) : String(map(Char, bytes))   # Latin-1: bytes are code points
    return split(s, r"\r\n|\r|\n")
end

"""
    read_noaa(path; missing_values=()) -> Table

A table of the NOAA NCEI template (version 4 and later): header lines starting with
`#`, then a line of tab-separated column names and the tab-separated data.
"""
function read_noaa(path::AbstractString; missing_values=())
    lines = filter(l -> !startswith(l, "#") && !isempty(strip(l)), read_lines(path))
    isempty(lines) && error("$path: no data after the # header")
    return Table(path, split(lines[1], '\t'), [split(l, '\t') for l in lines[2:end]]; missing_values)
end

"""
    read_pangaea(path; missing_values=()) -> Table

A table of a PANGAEA dataset (`?format=textfile`): a `/* ... */` metadata header, a
line of tab-separated column names (e.g. "Depth ice/snow [m]") and the data.
"""
function read_pangaea(path::AbstractString; missing_values=())
    lines = read_lines(path)
    h = findfirst(l -> startswith(l, "*/"), lines)
    h === nothing && error("$path: no end of the PANGAEA metadata header (*/)")
    data = filter(l -> !isempty(strip(l)), lines[h+2:end])
    return Table(path, split(lines[h+1], '\t'), [split(l, '\t') for l in data]; missing_values)
end

"""
    noaa_site(path) -> NamedTuple

Name, location (degrees) and elevation (m, `nothing` if not given) of the site in the
header of a file of the NOAA NCEI template.
"""
function noaa_site(path::AbstractString)
    lines = read_lines(path)
    function field(key)
        i = findfirst(l -> occursin(Regex("^#\\s*$key:"), l), lines)
        i === nothing && return nothing
        return strip(split(lines[i], ':'; limit=2)[2])
    end
    name, lat, lon, z = field("Site_Name"), field("Northernmost_Latitude"), field("Easternmost_Longitude"), field("Elevation_m")
    (name === nothing || lat === nothing || lon === nothing) && error("$path: no Site_Name/Northernmost_Latitude/Easternmost_Longitude")
    return (name=name, lat=parse(Float64, lat), lon=parse(Float64, lon),
            z_srf=z === nothing || isempty(z) ? nothing : parse(Float64, z))
end

"""
    pangaea_event(path) -> NamedTuple

Name, location (degrees) and elevation (m, `nothing` if not given) of the first event
(site) in the metadata header of a PANGAEA dataset.
"""
function pangaea_event(path::AbstractString)
    lines = read_lines(path)
    i = findfirst(l -> startswith(l, "Event(s):"), lines)
    i === nothing && error("$path: no Event(s) in the metadata header")
    l = lines[i]
    field(key) = (m = match(Regex("\\* $key: ([-0-9.]+)"), l); m === nothing ? nothing : parse(Float64, m[1]))
    lat, lon = field("LATITUDE"), field("LONGITUDE")
    (lat === nothing || lon === nothing) && error("$path: no LATITUDE/LONGITUDE in $l")
    name = replace(strip(split(l[length("Event(s):")+1:end], '*')[1]), r"\s*\(URI: [^)]*\)" => "")
    return (name=name, lat=lat, lon=lon, z_srf=field("ELEVATION"))
end

"""
    read_columns(path, header; skipto, stop=nothing, missing_values=()) -> Table

A whitespace-separated table of a text file without a usable header line: the lines
from `skipto` up to the first empty line (or line `stop`), with the column names
`header`.
"""
function read_columns(path::AbstractString, header::Vector{<:AbstractString}; skipto::Integer,
                      stop::Union{Nothing,Integer}=nothing, missing_values=())
    lines = read_lines(path)
    last_line = something(stop, something(findnext(l -> isempty(strip(l)), lines, skipto), length(lines) + 1) - 1)
    return Table(path, header, [split(l) for l in lines[skipto:last_line]]; missing_values)
end

"Float64 values with missing as NaN."
nan64(v) = Float64[ismissing(x) ? NaN : Float64(x) for x in v]

"Ages in years b2k (before 2000 CE) as years ago (before 1950 CE)."
years_ago_b2k(age) = nan64(age) .- B2K_TO_BP

# ---------------------------------------------------------------------------
# Time series at sites
# ---------------------------------------------------------------------------

"A site of a record: name, location (degrees) and, if known, surface elevation (m)."
struct Site
    name::String
    lat::Float64
    lon::Float64
    z_srf::Union{Nothing,Float64}
end
Site(name, lat, lon; z_srf=nothing) = Site(name, lat, lon, z_srf)

"""
    Var(name, data, units, long_name; T=Float32, attrib=Pair{String,String}[])

A variable of a record: `data` is a vector (on the axis, or on the axis of the only
site) or a matrix (axis x site), with `missing` or NaN for missing values; written as
type `T`.
"""
struct Var
    name::String
    data::AbstractArray
    units::String
    long_name::String
    T::Type
    attrib::Vector{Pair{String,String}}
end
Var(name, data, units, long_name; T::Type=Float32, attrib=Pair{String,String}[]) =
    Var(name, data, units, long_name, T, attrib)

_values(T, data) = T[ismissing(x) || (x isa AbstractFloat && isnan(x)) ? T(NaN) : T(x) for x in data]

"""
    write_series(path; sites, time, vars, axis_vars=Var[], axis="time", time_comment,
                 time_bnds=nothing, title, references, doi, license, tag)

Write a record of time series at `sites` on a common axis (`axis`, \"time\" or, when
ages repeat or are not sorted, \"sample\"): `time` (years ago, before 1950 CE, with
`time_comment` on its time scale, no missing values) and `time_bnds` (2 x n, optional) on the axis; the
`axis_vars` (other time scales, counting errors) on the axis; the `vars` on the axis and
the sites (`site_name` described as `site_long_name`). The global attributes are the CF
and provenance attributes of `tag`.
"""
function write_series(path::AbstractString; sites::Vector{Site}, time::AbstractVector, vars::Vector{Var},
                      axis_vars::Vector{Var}=Var[], axis::AbstractString="time", time_comment::AbstractString,
                      time_bnds=nothing, title::AbstractString, references::AbstractString,
                      doi::AbstractString, license::AbstractString, tag::AbstractString,
                      site_long_name::AbstractString="ice core site")
    nt, ns = length(time), length(sites)
    axis == "time" && any(<=(0), diff(nan64(time))) &&
        error("$path: time is not increasing, use axis = \"sample\"")
    mkpath(dirname(path))
    rm(path; force=true)
    NCDataset(path, "c") do ds
        defDim(ds, "station", ns)
        defDim(ds, axis, nt)
        defVar(ds, "site_name", [s.name for s in sites], ("station",);
               attrib=["long_name" => site_long_name, "cf_role" => "timeseries_id"])
        defVar(ds, "lat", [s.lat for s in sites], ("station",); attrib=["units" => "degrees_north", "standard_name" => "latitude"])
        defVar(ds, "lon", [s.lon for s in sites], ("station",); attrib=["units" => "degrees_east", "standard_name" => "longitude"])
        if all(s -> s.z_srf !== nothing, sites)
            defVar(ds, "z_srf", [s.z_srf for s in sites], ("station",);
                   attrib=["units" => "m", "long_name" => "present surface elevation of the site"])
        end
        tattrib = ["units" => "years ago", "long_name" => "time (years before 1950 CE)", "comment" => time_comment]
        time_bnds === nothing || push!(tattrib, "bounds" => "time_bnds")
        any(x -> ismissing(x) || isnan(x), time) && error("$path: time has missing values")
        defVar(ds, "time", _values(Float64, time), (axis,); attrib=tattrib)
        if time_bnds !== nothing
            size(time_bnds) == (2, nt) || error("$path: time_bnds must be 2 x $nt")
            defDim(ds, "nv", 2)
            defVar(ds, "time_bnds", _values(Float64, time_bnds), ("nv", axis))
        end
        for v in axis_vars
            length(v.data) == nt || error("$path: $(v.name) has $(length(v.data)) values, the axis $nt")
            defVar(ds, v.name, _values(v.T, v.data), (axis,); fillvalue=v.T(NaN), deflatelevel=1,
                   attrib=["units" => v.units, "long_name" => v.long_name, v.attrib...])
        end
        for v in vars
            data = v.data isa AbstractVector ? reshape(v.data, :, 1) : v.data
            size(data) == (nt, ns) || error("$path: $(v.name) is $(size(data)), not $axis x station ($nt x $ns)")
            defVar(ds, v.name, _values(v.T, data), (axis, "station"); fillvalue=v.T(NaN), deflatelevel=1,
                   attrib=["units" => v.units, "long_name" => v.long_name, "coordinates" => "time lat lon", v.attrib...])
        end
        ds.attrib["title"] = title
        ds.attrib["references"] = references
        ds.attrib["doi"] = doi
        ds.attrib["license"] = license
        ds.attrib["featureType"] = "timeSeries"
        ds.attrib["Conventions"] = "CF-1.11"
        foreach(((k, v),) -> ds.attrib[k] = v, provenance_attrib(tag))
    end
    println("Wrote $path")
    return path
end

# ---------------------------------------------------------------------------
# AICC2023 ages
# ---------------------------------------------------------------------------

"Cores with AICC2023 ages (files of ../Bouchet2023_AICC2023)."
const AICC2023_CORES = ("EDC", "EDML", "NGRIP", "TALDICE", "Vostok")

"Prepared file of the AICC2023 depth-age table of a core."
aicc2023_file(core::AbstractString) = joinpath(prepared_dir("Bouchet2023_AICC2023"), "AICC2023_$core.nc")

"""
    aicc2023_age(core, depth; kind="ice") -> Vector{Float64}

Ages (years ago, before 1950 CE) on AICC2023 (Bouchet et al., 2023) of the ice
(`kind="ice"`) or of the gas (`"gas"`) at the depths `depth` (m) of a core of
`AICC2023_CORES`, interpolated linearly in depth in its table (prepared first if
missing); NaN outside the table or where it has no age.
"""
function aicc2023_age(core::AbstractString, depth::AbstractVector; kind::AbstractString="ice")
    core in AICC2023_CORES || error("no AICC2023 ages of $core, only $(join(AICC2023_CORES, ", "))")
    kind in ("ice", "gas") || error("kind must be ice or gas")
    file = aicc2023_file(core)
    isfile(file) || run_prepare("Bouchet2023_AICC2023")
    zt, at = NCDataset(file) do ds
        Float64.(ds["depth"][:]), nan64(ds["age_$(kind)_aicc2023"][:, 1])
    end
    return [interp_linear(zt, at, z) for z in nan64(depth)]
end

"Linear interpolation of (x, y) at x0 (x increasing); NaN outside x or next to a NaN of y."
function interp_linear(x::Vector{Float64}, y::Vector{Float64}, x0::Real)
    (isnan(x0) || x0 < x[1] || x0 > x[end]) && return NaN
    i = clamp(searchsortedlast(x, x0), 1, length(x) - 1)
    w = (x0 - x[i]) / (x[i+1] - x[i])
    return w == 0 ? y[i] : w == 1 ? y[i+1] : (1 - w) * y[i] + w * y[i+1]
end
