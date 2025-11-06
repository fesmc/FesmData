# Pan et al. (2022) lithospheric thickness

Global map of lithospheric thickness.

Source: TO DO (Jan?)
Citable as: Pan et al., The influence of lateral Earth structure on inferences of global ice volume during the Last Glacial Maximum, Quarternary Science Reviews, doi:10.1016/j.quascirev.2022.107644, 2022.

## Steps to obtain global raw dataset

1. Obtain original data from the Pan et al. (2022) publication.

    To document (Jan?).

2. Convert the dataset to a standard 0.5degree lonlat grid.

    To document (Jan?).

    File is stored in the `isostasy_data` repository ([https://github.com/JanJereczek/isostasy_data/](https://github.com/JanJereczek/isostasy_data/)) as `isostasy_data/earth_structure/lithothickness/pan2022.nc`.

## Steps to remap to a regional grid

1. Make a link to the `isostasy_data` folder on your system:

```bash
ln -s /path/to/isostasy_data ./
```

2. Run `remap.sh GRID_NAME` with your target grid name specified as the first argument. For example to produce the file `LIS-32KM_GEO-P22.nc` for the Laurentide 32KM grid, run:

```bash
./remap.sh LIS-32KM
```

That's it. Output file is now available on the target grid, and the map weights have also been saved.
