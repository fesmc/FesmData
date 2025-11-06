# Pan et al. (2022) lithospheric thickness

Global map of lithospheric thickness.

Source: TO DO (Jan?)
Citable as: Pan et al., The influence of lateral Earth structure on inferences of global ice volume during the Last Glacial Maximum, Quarternary Science Reviews, doi:10.1016/j.quascirev.2022.107644, 2022.

## Steps to obtain global raw dataset

1. Obtain original data from the Pan et al. (2022) publication.

    To document.

2. Convert the dataset to a standard 0.5degree lonlat grid.

    To document.

    File is stored in the `isostasy_data` repository ([https://github.com/JanJereczek/isostasy_data/](https://github.com/JanJereczek/isostasy_data/)) as `isostasy_data/earth_structure/lithothickness/pan2022.nc`.

## Steps to remap to a regional grid

1. Make a link to the `isostasy_data` folder on your system:

```bash
ln -s /path/to/isostasy_data ./
```

2. Open `genmap.sh` and modify the target domain and grid name variables to match your goal:

```bash
domain_tgt=Laurentide
grid_name_tgt=LIS-16KM
```

3. Run `genmap.sh` to produce scrip weight files for conservative remapping to the new domain:

```bash
./genmap.sh
```

4. Run `remap.sh` to perform the remapping to the new grid, with arguments matching your target grid:

```bash
# LIS-16KM 
./remap.sh lonlat-0.5deg LIS-16KM isostasy_data/earth_structure/lithothickness/pan2022.nc LIS-16KM_LITH_P22.nc

# LIS-32KM 
./remap.sh lonlat-0.5deg LIS-32KM isostasy_data/earth_structure/lithothickness/pan2022.nc LIS-32KM_LITH_P22.nc
```

That's it. Files are now available on the target grid.
