# Precision of the float fields of the output files: each field is rounded to a
# tolerance by its kind (bit rounding: the mantissa bits not needed are zeroed), so that
# it compresses well, and records it in its attributes `precision` and
# `bitround_keepbits`. No package dependencies, so that Publish can parse remap.toml.

"""
    Precision(abs, rel)

Tolerance of the values of a float field: the error of each value is at most `abs` (in
the units of the field) or `rel` times its magnitude, the larger of the two; 0 for no
tolerance of that kind, both 0 for lossless (full Float32).
"""
struct Precision
    abs::Float64
    rel::Float64
end

const LOSSLESS = Precision(0, 0)

"""
    PrecisionClass(kind, name, units, precision)

A kind of field with its default precision, matched by the field name (`name`, a regex)
and its units (`units`, a regex); `nothing` matches any.
"""
struct PrecisionClass
    kind::String
    name::Union{Nothing,Regex}
    units::Union{Nothing,Regex}
    precision::Precision
end

"Kind of the fields in m (elevations, thicknesses), whose precision a domain may set."
const ELEVATION = "elevation, thickness"

"""
Absolute tolerance (m) of elevations and thicknesses, unless their domain sets another
(`elevation_precision` in ../shared/domains.toml).
"""
const DEFAULT_ELEVATION_PRECISION = 0.01

"""
Default precision of the float fields by kind, the first that matches (`default_precision`).
Documented in docs/data_volume.qmd.
"""
const PRECISION_CLASSES = [
    PrecisionClass("longitude, latitude", r"^(lon|lat)(2D)?$", nothing, LOSSLESS),
    PrecisionClass("longitude, latitude", nothing, r"^degrees?_(east|north)$", LOSSLESS),
    PrecisionClass("cell area", r"^area$", nothing, Precision(0, 1e-5)),
    PrecisionClass("fraction", r"^f_", nothing, Precision(1e-3, 0)),
    PrecisionClass("fraction", nothing, r"^1$", Precision(1e-3, 0)),
    PrecisionClass("ice velocity", r"^u(x|y|z|xy)(_|$)", r"^m (yr|a)-1$", Precision(1, 0.01)),
    PrecisionClass("rate", r"^(smb|pr|sf|rf|melt|runoff|subl|evap|bmelt|bmb)(_|$)", nothing, Precision(0, 0.01)),
    PrecisionClass(ELEVATION, nothing, r"^m$", Precision(DEFAULT_ELEVATION_PRECISION, 0)),
    PrecisionClass("temperature", nothing, r"^(K|degC|°C|degree_Celsius)$", Precision(0.01, 0)),
    PrecisionClass("rate, flux", nothing, r"\b(s|d|day|yr|a)-1\b|W m-2", Precision(0, 0.01)),
    PrecisionClass("other", nothing, nothing, Precision(0, 5e-4)),   # 3 significant digits
]

"""
Default precision of a float field with units `units` (see `PRECISION_CLASSES`), with
the absolute tolerance `elevation` (m) for elevations and thicknesses if given (that of
the domain of the grid).
"""
function default_precision(name::AbstractString, units::AbstractString; elevation=nothing)
    matches(re, s) = re === nothing || occursin(re, s)
    c = first(c for c in PRECISION_CLASSES if matches(c.name, name) && matches(c.units, units))
    return c.kind == ELEVATION && elevation !== nothing ? Precision(elevation, 0) : c.precision
end

"""
    parse_precision(value, what) -> Precision

An exception to the default precision of a field (`precision` of a product in
remap.toml): a number, the absolute tolerance in the units of the field; "x%", a
relative tolerance; or "lossless".
"""
function parse_precision(value, what::AbstractString)
    value == "lossless" && return LOSSLESS
    value isa Real && value > 0 && return Precision(value, 0)
    if value isa AbstractString && endswith(value, "%")
        x = tryparse(Float64, chopsuffix(value, "%"))
        x !== nothing && 0 < x < 100 && return Precision(0, x / 100)
    end
    error("$what: precision must be an absolute tolerance (a number > 0), a relative one (\"x%\") or \"lossless\"")
end

"""
    keepbits(p, maxabs) -> Int

Mantissa bits of Float32 values kept for precision `p`, of a field whose largest
magnitude is `maxabs`: rounding to k bits changes a value x by at most 2^-(k+1) |x|,
and by at most 2^(e-k-1) for |x| < 2^(e+1). 23 is lossless.
"""
function keepbits(p::Precision, maxabs::Real)
    k = 23
    p.rel > 0 && (k = min(k, ceil(Int, -log2(p.rel) - 1)))
    p.abs > 0 && maxabs > 0 && (k = min(k, ceil(Int, log2(maxabs / p.abs) - 1)))
    return clamp(k, 1, 23)
end

"""
    bitround!(A, k) -> A

Round the finite values of `A` to `k` mantissa bits (to nearest, ties to even), the other
bits zero; NaN and Inf are kept.
"""
function bitround!(A::AbstractArray{Float32}, k::Integer)
    k >= 23 && return A
    shift = 23 - k
    half = (UInt32(1) << (shift - 1)) - UInt32(1)
    mask = ~((UInt32(1) << shift) - UInt32(1))
    @inbounds for i in eachindex(A)
        isfinite(A[i]) || continue
        u = reinterpret(UInt32, A[i])
        A[i] = reinterpret(Float32, (u + half + ((u >> shift) & UInt32(1))) & mask)
    end
    return A
end

"""
    round_field!(A, p, units) -> attributes

Round the float field `A` (NaN as missing) to precision `p`, and return its attributes
`precision` (e.g. "0.1 m", "1%", "1% or 1 m yr-1", "lossless") and `bitround_keepbits`.
"""
function round_field!(A::AbstractArray{Float32}, p::Precision, units::AbstractString)
    maxabs = maximum(x -> isfinite(x) ? abs(x) : 0f0, A; init=0f0)
    k = p == LOSSLESS ? 23 : keepbits(p, maxabs)
    bitround!(A, k)
    return Pair{String,Any}["precision" => precision_string(p, units), "bitround_keepbits" => Int32(k)]
end

"Precision `p` of a field with units `units`, as written in its attribute `precision`."
function precision_string(p::Precision, units::AbstractString)
    p == LOSSLESS && return "lossless"
    abs = p.abs > 0 ? _number(p.abs) * (units in ("", "1") ? "" : " $units") : nothing
    rel = p.rel > 0 ? _number(100 * p.rel) * "%" : nothing
    return join(filter(!isnothing, [rel, abs]), " or ")
end

"A tolerance as written: 6 significant digits at most, integers without decimals."
_number(x::Real) = (y = round(x; sigdigits=6); isinteger(y) ? string(Int(y)) : string(y))
