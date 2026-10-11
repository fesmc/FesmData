# Sediment thickness of ECM1 (Mooney et al., 2023)

Sediment thickness on land and in the oceans on a 1x1° lon-lat grid, from the global
crustal model ECM1 (Earth Crustal Model 1):

Mooney, W. D., Barrera-Lopez, C., Suárez, M. G. and Castelblanco, M. A.: Earth Crustal
Model 1 (ECM1): A 1° x 1° global seismic and density model, Earth-Sci. Rev., 243,
104493, 2023, [doi:10.1016/j.earscirev.2023.104493](https://doi.org/10.1016/j.earscirev.2023.104493).

ECM1 has three sediment layers. Its total sediment thickness differs from that of
CRUST1.0 by up to ±10 km, mostly on the continental margins (Mooney et al., 2023).

## Licence

No licence or terms of use are stated on the web site of the model; the article is
published under the Elsevier standard terms. We assume that derived products may be
published with a citation of Mooney et al. (2023).

## Original data

`ECM1_Sediments.zip` ("Sediment Model", no login) from <https://www.earthcrustmodel1.com/>,
of which `ECM1_Sediments/Sed_ECM1.txt` is used. It is in `datamanifest.toml`
(`ecm1_sediments`) and downloaded and extracted by `prepare.jl` if missing.

## Prepare and remap

```bash
julia --project=Mooney2023_ecm1 Mooney2023_ecm1/prepare.jl
julia fesmdata.jl remap $FESMDATA_WORK/prepared/Mooney2023_ecm1/Mooney2023_ECM1_sed.nc all --name=Sediment-ECM1
```

`prepare.jl` writes `z_sed`, the total sediment thickness, and the thickness of each
sediment layer, `z_sed_upper`, `z_sed_middle` and `z_sed_lower` (m), to
`$FESMDATA_WORK/prepared/Mooney2023_ecm1/Mooney2023_ECM1_sed.nc` (see `Remap/README.md`).
They are the columns `Sed` and `SedT1`-`SedT3` of `Sed_ECM1.txt` (m; `Sed` is the sum
of the layers). The total sediment thickness is also in `ECM1.txt` of the crystalline
crust model (`Sed`, km), used by the v1 product SED-M23 (`ECM1_geo/`).
