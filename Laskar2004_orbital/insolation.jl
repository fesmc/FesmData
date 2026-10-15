# Daily-mean insolation at the top of the atmosphere from the orbital elements of Laskar
# et al. (2004), in closed form (Berger, 1978). A port of the independent Julia reference
# of the insol library (https://github.com/fesmc/insol, scripts/make_reference.jl), with
# the same conventions: the vernal equinox on 21 March at 12:00, the perihelion angle
# measured as in the La2004 tables (pibar, 102.9° at J2000), Kepler's equation solved by
# Newton iteration, and the declination held fixed over the day.

"Day of the vernal equinox (21 March, 12:00) counted from the start of a year of `day_year` days."
const TVEREX = Dict(360 => 80.5, 365 => 79.5, 366 => 80.5)

"Orbital elements of La2004 along time (kyr from J2000, negative in the past): eccentricity, obliquity and perihelion (degrees)."
struct OrbitTable
    time::Vector{Float64}
    ecc::Vector{Float64}
    obl::Vector{Float64}
    per::Vector{Float64}
end

"Rows of a La2004 table (t, e, obliquity, pibar in radians; Fortran D exponents) with |t| <= tmax (kyr)."
function read_la2004(path::AbstractString, tmax::Real)
    rows = NTuple{4,Float64}[]
    for line in eachline(path)
        parts = split(line)
        length(parts) == 4 || error("$path: malformed line: $line")
        r = ntuple(i -> parse(Float64, replace(parts[i], 'D' => 'E', 'd' => 'e')), 4)
        abs(r[1]) > tmax && break
        push!(rows, r)
    end
    return rows
end

"""
    OrbitTable(past, future)

The orbital elements from the rows of the table of the past (0 to -t) and of the future
(0 to +t), joined in increasing time (the row at 0, in both, once).
"""
function OrbitTable(past::Vector{NTuple{4,Float64}}, future::Vector{NTuple{4,Float64}})
    rows = vcat(reverse(past)[1:end-1], future)
    tab = OrbitTable([r[1] for r in rows], [r[2] for r in rows], [rad2deg(r[3]) for r in rows], [rad2deg(r[4]) for r in rows])
    all(diff(tab.time) .> 0) || error("the orbital table is not increasing in time")
    return tab
end

"""
    orbital_par(tab, t_ka; day_year=365) -> (ecc, obl, per, tper, zavexpe)

Orbital elements at `t_ka` (kyr in the time of the table), interpolated linearly
(the perihelion unwrapped), with the time of perihelion `tper` (days from the start of
the year) and the angle `zavexpe` (radians) of the solar geometry.
"""
function orbital_par(tab::OrbitTable, t_ka::Real; day_year::Integer=365)
    (t_ka < first(tab.time) || t_ka > last(tab.time)) && error("t = $t_ka ka outside the orbital table")
    n2 = clamp(searchsortedfirst(tab.time, t_ka), 2, length(tab.time))
    n1 = n2 - 1
    w = (t_ka - tab.time[n1]) / (tab.time[n2] - tab.time[n1])
    ecc = (1 - w) * tab.ecc[n1] + w * tab.ecc[n2]
    obl = (1 - w) * tab.obl[n1] + w * tab.obl[n2]
    p1, p2 = tab.per[n1], tab.per[n2]
    p2 < p1 && (p2 += 360.0)
    per = mod((1 - w) * p1 + w * p2, 360.0)
    # Time of perihelion (Monin, 1986): from the angle of the perihelion from the autumnal
    # equinox, the eccentric then the mean anomaly
    zavexpe = deg2rad(mod(per - 180.0, 360.0))
    ecc_anom = 2 * atan(sqrt((1 - ecc) / (1 + ecc)) * tan(zavexpe / 2))
    mean_anom = ecc_anom - ecc * sin(ecc_anom)
    tper = mod(mod(mean_anom / (2pi) * day_year, day_year) + TVEREX[day_year], day_year)
    return ecc, obl, per, tper, zavexpe
end

"Solar declination (radians) and the inverse-square distance factor (a/r)^2 on a day of the year."
function solar_geometry(day::Real, ecc, obl, tper, zavexpe; day_year::Integer=365)
    m = day / day_year * 2pi - 2pi * tper / day_year
    e = m
    for _ in 1:100
        de = (m + ecc * (sin(e) - e * cos(e))) / (1 - ecc * cos(e)) - e
        e += de
        abs(de) < 1e-14 && break
    end
    dist2 = (1 / (1 - ecc * cos(e)))^2
    true_anom = 2 * atan(sqrt((1 + ecc) / (1 - ecc)) * tan(e / 2))
    decl = asin(sin(deg2rad(obl)) * sin(true_anom + zavexpe))
    return decl, dist2
end

"Daily-mean insolation (W m-2) at latitude `lat` (degrees), in closed form."
function insol_day(lat::Real, decl, dist2; S0::Real)
    sinlat, coslat = sincos(deg2rad(lat))
    sindec, cosdec = sincos(decl)
    denom = coslat * cosdec
    cosH0 = abs(denom) < 1e-14 ? -sign(sinlat * sindec) : -sinlat * sindec / denom
    H0 = cosH0 >= 1 ? 0.0 : cosH0 <= -1 ? pi : acos(cosH0)
    return S0 / pi * dist2 * (H0 * sinlat * sindec + coslat * cosdec * sin(H0))
end

"Daily-mean insolation (W m-2) at `lat` on the days `days`, averaged, at time `t_ka` of the table."
function insolation(tab::OrbitTable, t_ka::Real, lat::Real, days; S0::Real, day_year::Integer=365)
    ecc, obl, _, tper, zavexpe = orbital_par(tab, t_ka; day_year)
    return sum(insol_day(lat, solar_geometry(d, ecc, obl, tper, zavexpe; day_year)...; S0) for d in days) / length(days)
end
