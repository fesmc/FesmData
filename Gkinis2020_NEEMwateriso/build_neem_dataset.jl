#
# Download the NEEM high-resolution water-isotope record (Gkinis et al., 2020,
# PANGAEA https://doi.org/10.1594/PANGAEA.925552) and write it to two NetCDF
# files plus a summary figure:
#
#   NEEM_water_isotopes_depth.nc  -- depth as the dimension, every column of the
#                                    source table carried as a series along depth
#                                    (including all three raw age scales).
#   NEEM_water_isotopes_time.nc   -- time (years, negative = before reference)
#                                    as the dimension, rows resorted to be
#                                    monotonic in the chosen timescale.
#   NEEM_d18O.png                 -- d18O vs depth (top) and d18O vs time (bottom).
#
# Timescale handling
# ------------------
# The source gives three partial age columns that partition by depth:
#   GICC05          (counted)      1210.50 - 1955.90 m,  ~8 - 60 ka b2k
#   GICC05_modelext (model)        1955.95 m -> deep,    ~60 ka b2k ->
#   AICC2012                       1955.95 m -> deep,    ~60 ka b2k ->
# No single column spans the whole core, so a continuous age is built from the
# counted GICC05 for the shared upper part plus a chosen deep scale below it:
#   TIMESCALE = "GICC05"    -> GICC05 (shallow) + GICC05_modelext (deep)  [default]
#   TIMESCALE = "AICC2012"  -> GICC05 (shallow) + AICC2012        (deep)
# The deepest folded ice has no age on any scale; those rows are dropped from the
# time file (count reported) and kept in the depth file.
#
# Run:
#     julia --project=. build_neem_dataset.jl              # default GICC05
#     julia --project=. build_neem_dataset.jl AICC2012     # alternative deep scale
#
cd(@__DIR__)
import Pkg; Pkg.activate(".")

using CSV
using DataFrames
using NCDatasets
using CairoMakie
using Downloads
using Printf

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

const DOI          = "https://doi.org/10.1594/PANGAEA.925552"
const SRC_URL      = "https://doi.pangaea.de/10.1594/PANGAEA.925552?format=textfile"
const SRC_TAB      = "NEEM_Gkinis2020.tab"        # cached raw download

const PATH_DEPTH   = "NEEM_water_isotopes_depth.nc"
const PATH_TIME    = "NEEM_water_isotopes_time.nc"
const PATH_FIG     = "NEEM_d18O.png"

# Reference year for the time axis. The record is on the "b2k" scale
# (years before 2000 CE), so time = -(age in years) relative to 2000 CE.
const REFERENCE_YEAR = 2000

# Timescale: shallow part is always counted GICC05; this selects the deep scale.
# Default is "GICC05" (i.e. GICC05_modelext below the counted section).
const DEEP_COLUMN = Dict(
    "GICC05"   => :age_gicc05_modelext,
    "AICC2012" => :age_aicc2012,
)
# Human-readable name of the deep scale used below the counted GICC05 section.
const DEEP_NAME = Dict(
    "GICC05"   => "GICC05_modelext",
    "AICC2012" => "AICC2012",
)
const TIMESCALE = isempty(ARGS) ? "GICC05" : ARGS[1]

const CITATION = "Gkinis, V. et al. (2020): NEEM ice core High Resolution (0.05m) " *
    "Water Isotope Ratios (18O/16O, 2H/1H) covering 8-129 ky b2k. PANGAEA, " * DOI
const SOURCE_ATTR = "Gkinis et al. (2020), NEEM water isotopes, " * DOI *
    " (CC-BY-4.0). Supplement to Gkinis et al. (2021), Sci. Data 8, 141, " *
    "https://doi.org/10.1038/s41597-021-00916-9"

# Clean column names for the 11 source columns, in file order.
const COLNAMES = [
    :depth,                 # DEPTH, ice/snow [m], bottom of each interval
    :age_gicc05,            # Age [ka b2k] (GICC05, counted)
    :age_gicc05_modelext,   # Age [ka b2k] (GICC05_modelext)
    :age_aicc2012,          # Age [ka b2k] (AICC2012)
    :mce,                   # Maximum Counting Error [a] (GICC05)
    :d18O,                  # d18O, water [per mil SMOW]
    :dD,                    # dD, water [per mil SMOW]
    :d18O_std,              # d18O std dev [per mil]
    :dD_std,                # dD std dev [per mil]
    :offset_d18O,           # accuracy-check offset, d18O [per mil SMOW]
    :offset_dD,             # accuracy-check offset, dD  [per mil SMOW]
]

# ---------------------------------------------------------------------------
# Download + parse
# ---------------------------------------------------------------------------

"""Download the PANGAEA tab-delimited text file (cached locally)."""
function fetch_data(; url=SRC_URL, path=SRC_TAB)
    if isfile(path)
        @info "Using cached source file" path
    else
        @info "Downloading source file" url path
        Downloads.download(url, path)
    end
    return path
end

"""
Read the PANGAEA tab file into a DataFrame with clean column names. The file
starts with a `/* ... */` metadata header followed by a column-header line; data
begins on the line after `*/`. Empty fields become `missing`.
"""
function read_neem(path)
    lines = readlines(path)
    hdr_end = findfirst(l -> startswith(strip(l), "*/"), lines)
    hdr_end === nothing && error("Could not find end of metadata header ('*/') in $path")
    datastart = hdr_end + 2   # skip '*/' line and the column-header line

    df = CSV.read(path, DataFrame;
        delim = '\t',
        header = false,
        skipto = datastart,
        missingstring = "",
    )
    ncol(df) == length(COLNAMES) ||
        error("Expected $(length(COLNAMES)) columns, got $(ncol(df))")
    rename!(df, COLNAMES)
    return df
end

# Float32 vector with NaN in place of `missing`, for CF-friendly output.
tofloat(v) = Float32[ismissing(x) ? NaN32 : Float32(x) for x in v]

# ---------------------------------------------------------------------------
# NetCDF writers
# ---------------------------------------------------------------------------

const VAR_META = Dict(
    :age_gicc05          => ("age_GICC05",          "ka b2k", "Age on GICC05 (layer-counted) timescale"),
    :age_gicc05_modelext => ("age_GICC05_modelext", "ka b2k", "Age on GICC05_modelext timescale"),
    :age_aicc2012        => ("age_AICC2012",        "ka b2k", "Age on AICC2012 timescale"),
    :mce                 => ("mce",                 "a",      "Maximum counting error (GICC05)"),
    :d18O                => ("d18O",                "per mil SMOW", "delta-18O of water (18O/16O)"),
    :dD                  => ("dD",                  "per mil SMOW", "delta-D of water (2H/1H)"),
    :d18O_std            => ("d18O_std",            "per mil", "1-sigma precision of d18O run"),
    :dD_std              => ("dD_std",              "per mil", "1-sigma precision of dD run"),
    :offset_d18O         => ("offset_d18O",         "per mil SMOW", "Accuracy-check offset, d18O"),
    :offset_dD           => ("offset_dD",           "per mil SMOW", "Accuracy-check offset, dD"),
)

function defdatavar!(ds, dimname, name, units, long_name)
    v = defVar(ds, name, Float32, (dimname,); attrib = Dict(
        "units"     => units,
        "long_name" => long_name,
        "_FillValue" => NaN32,
    ))
    return v
end

"""Write the depth-indexed file: all columns as series along depth."""
function write_depth_file(df; path=PATH_DEPTH)
    isfile(path) && rm(path)
    NCDataset(path, "c") do ds
        ds.attrib["title"]      = "NEEM ice core high-resolution water isotopes vs depth"
        ds.attrib["source"]     = SOURCE_ATTR
        ds.attrib["citation"]   = CITATION
        ds.attrib["doi"]        = DOI
        ds.attrib["license"]    = "CC-BY-4.0"
        ds.attrib["site"]       = "NEEM, Greenland (77.45N, 51.06W, 2545 m)"
        ds.attrib["Conventions"] = "CF-1.8"

        defDim(ds, "depth", nrow(df))
        dv = defVar(ds, "depth", Float32, ("depth",); attrib = Dict(
            "units"     => "m",
            "long_name" => "Depth in ice (bottom of each 0.05 m interval)",
            "positive"  => "down",
        ))
        dv[:] = tofloat(df.depth)

        for col in COLNAMES
            col === :depth && continue
            name, units, long_name = VAR_META[col]
            defdatavar!(ds, "depth", name, units, long_name)[:] = tofloat(df[!, col])
        end
    end
    @info "Wrote depth file" path rows=nrow(df)
end

"""
Write the time-indexed file for the chosen timescale. Rows are resorted to be
monotonic in time (years, negative = before REFERENCE_YEAR). Rows with no age on
the chosen scale are dropped.
"""
function write_time_file(df, timescale; path=PATH_TIME)
    haskey(DEEP_COLUMN, timescale) ||
        error("Unknown timescale '$timescale'. Choose one of: $(join(keys(DEEP_COLUMN), ", "))")
    deepcol = DEEP_COLUMN[timescale]

    # Continuous age: counted GICC05 up top, chosen deep scale below.
    merged_age = coalesce.(df.age_gicc05, df[!, deepcol])   # ka b2k, may be missing
    keep = findall(!ismissing, merged_age)
    dropped = nrow(df) - length(keep)

    age_ka = Float64.(merged_age[keep])
    time_yr = -1000.0 .* age_ka                 # years relative to REFERENCE_YEAR
    perm = sortperm(time_yr)                     # oldest (most negative) first

    idx = keep[perm]
    time_sorted = Float32.(time_yr[perm])

    isfile(path) && rm(path)
    NCDataset(path, "c") do ds
        ds.attrib["title"]      = "NEEM ice core water isotopes vs time ($timescale)"
        ds.attrib["source"]     = SOURCE_ATTR
        ds.attrib["citation"]   = CITATION
        ds.attrib["doi"]        = DOI
        ds.attrib["license"]    = "CC-BY-4.0"
        ds.attrib["site"]       = "NEEM, Greenland (77.45N, 51.06W, 2545 m)"
        ds.attrib["Conventions"] = "CF-1.8"
        ds.attrib["timescale"]   = timescale
        ds.attrib["timescale_construction"] =
            "GICC05 (counted) above 1955.90 m; $(DEEP_NAME[timescale]) below"
        ds.attrib["reference_year"] = REFERENCE_YEAR
        ds.attrib["reference_note"] =
            "time = years relative to $REFERENCE_YEAR CE (b2k); negative = before"

        defDim(ds, "time", length(idx))
        tv = defVar(ds, "time", Float32, ("time",); attrib = Dict(
            "units"          => "a",
            "long_name"      => "Time relative to $REFERENCE_YEAR CE (negative = before present)",
            "reference_year" => REFERENCE_YEAR,
        ))
        tv[:] = time_sorted

        # Age on the chosen scale (ka b2k) as a convenience variable.
        defVar(ds, "age", Float32, ("time",); attrib = Dict(
            "units"     => "ka b2k",
            "long_name" => "Age before 2000 CE on the $timescale timescale",
        ))[:] = Float32.(age_ka[perm])

        # Depth carried along as a data variable.
        defVar(ds, "depth", Float32, ("time",); attrib = Dict(
            "units"     => "m",
            "long_name" => "Depth in ice (bottom of each 0.05 m interval)",
        ))[:] = tofloat(df.depth[idx])

        for col in (:mce, :d18O, :dD, :d18O_std, :dD_std, :offset_d18O, :offset_dD)
            name, units, long_name = VAR_META[col]
            defdatavar!(ds, "time", name, units, long_name)[:] = tofloat(df[!, col][idx])
        end
    end
    @info "Wrote time file" path timescale rows=length(idx) dropped_no_age=dropped
    return dropped
end

# ---------------------------------------------------------------------------
# Figure
# ---------------------------------------------------------------------------

"""d18O vs depth (top) and d18O vs time (bottom)."""
function make_figure(df, timescale; path=PATH_FIG)
    deepcol = DEEP_COLUMN[timescale]
    merged_age = coalesce.(df.age_gicc05, df[!, deepcol])
    keep = findall(!ismissing, merged_age)
    time_yr = -1000.0 .* Float64.(merged_age[keep])
    perm = sortperm(time_yr)
    idx = keep[perm]

    fig = Figure(size = (1000, 700))

    # x = -depth so deep/old is on the left and shallow/recent on the right,
    # matching the orientation of the time panel below.
    ax1 = Axis(fig[1, 1];
        xlabel = "−Depth (m)",
        ylabel = "δ¹⁸O (‰ SMOW)",
        title  = "NEEM water isotopes (Gkinis et al., 2020)")
    lines!(ax1, .-tofloat(df.depth), tofloat(df.d18O); linewidth = 0.4, color = :steelblue)

    ax2 = Axis(fig[2, 1];
        xlabel = "Time (years relative to $REFERENCE_YEAR CE, negative = before present)",
        ylabel = "δ¹⁸O (‰ SMOW)",
        title  = "Timescale: $timescale")
    lines!(ax2, Float32.(time_yr[perm]), tofloat(df.d18O[idx]);
        linewidth = 0.4, color = :firebrick)

    save(path, fig)
    @info "Wrote figure" path
end

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

function main()
    haskey(DEEP_COLUMN, TIMESCALE) ||
        error("Unknown timescale '$TIMESCALE'. Choose one of: $(join(keys(DEEP_COLUMN), ", "))")
    @info "Building NEEM dataset" timescale=TIMESCALE

    df = read_neem(fetch_data())
    @printf("Parsed %d rows, depth %.2f - %.2f m\n",
            nrow(df), minimum(df.depth), maximum(df.depth))

    write_depth_file(df)
    write_time_file(df, TIMESCALE)
    make_figure(df, TIMESCALE)
    @info "Done"
end

main()
