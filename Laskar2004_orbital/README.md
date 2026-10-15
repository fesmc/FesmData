# Orbital elements and insolation, 5 Ma to 1 Ma in the future (Laskar et al., 2004)

The eccentricity, obliquity and longitude of perihelion of the La2004 solution, and
insolation series at 65°N and 65°S computed from them, every 1 kyr from 5 Ma ago to 1 Ma
in the future. From:

Laskar, J., Robutel, P., Joutel, F., Gastineau, M., Correia, A. C. M., and Levrard, B.: A
long-term numerical solution for the insolation quantities of the Earth, Astron.
Astrophys., 428, 261-285, 2004,
[doi:10.1051/0004-6361:20041335](https://doi.org/10.1051/0004-6361:20041335).

Insolation: Berger, A.: Long-term variations of daily insolation and Quaternary climatic
changes, J. Atmos. Sci., 35, 2362-2367, 1978.

## Licence

No licence stated: the files are © ASD/IMCCE. We assume the data may be published.

## Original data

The La2004 tables of IMCCE, https://ssp.imcce.fr/insola/earth/online/earth/La2004/ (no
login), downloaded by `prepare.jl` (datamanifest keys `laskar2004_past`,
`laskar2004_future`): `INSOLN.LA2004.BTL.ASC` (0 to -51 Myr) and `INSOLP.LA2004.BTL.ASC`
(0 to +21 Myr), every 1 kyr: time (kyr from J2000), eccentricity, obliquity (radians)
and pibar, the longitude of the perihelion from the moving equinox (radians), with
Fortran D exponents. The first 5 Myr and 1 Myr are the tables of the insol library
(`input/LA2004.INSOLN.5Ma.txt`, `input/LA2004.INSOLP.1Ma.txt`).

## Prepare and record

```bash
julia --project=Laskar2004_orbital Laskar2004_orbital/prepare.jl
julia fesmdata.jl record Orbital La2004
```

`prepare.jl` writes `$FESMDATA_PREPARED/Laskar2004_orbital/Laskar2004_orbital.nc` (see
`Records/README.md`), a global series (dimension `region`, no location) every 1 kyr from
-1 Ma to 5 Ma (years before 1950 CE, negative in the future):

- `ecc`, `obl` (degree), `per` (degree, pibar: 102.9° at J2000, as ω of Berger, 1978),
  `prec` = e sin(per), the climatic precession index;
- `insol_65n_jun21`, `insol_65n_jja`, `insol_65s_dec21`, `insol_65s_djf` (W m-2): the
  daily-mean insolation at the top of the atmosphere on 21 June and 21 December, and its
  mean over June-August and December-February.

The elements are interpolated linearly (the perihelion unwrapped) at the times of the
record: t years before 1950 CE is -(t + 50) years from J2000. `insolation.jl` computes the
insolation in closed form as the insol library (a port of its independent Julia
reference, `scripts/make_reference.jl`): S0 = 1365 W m-2, a year of 365 days, the vernal
equinox on 21 March at 12:00. It reproduces the 1440 reference values of insol
(`tests/reference/insol_reference.txt`, both calendars) to 1e-12 W m-2.
