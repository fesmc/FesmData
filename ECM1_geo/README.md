# Earth Crustal Model 1

Global sediment thickness data.

Source: https://www.earthcrustmodel1.com/
Citation: Mooney et al., Earth Crustal Model 1 (ECM1): A 1◦x1◦ Global Seismic and Density Model, Earth Science Reviews, doi:10.1016/j.earscirev.2023.104493, 2023.

## Steps

### Download the original datset

    - Go to this website: https://www.earthcrustmodel1.com/
    - Click the first "DOWNLOAD HERE" box for Crystalline Earth Crustal Model 1 (ECM1)
    - Save ECM1.zip locally to this folder.
    - Then:

```bash
unzip ECM1.zip
rm -r rm -r __MACOSX ECM1.zip

wget https://www.earthcrustmodel1.com/_files/archives/b6b6a8_f3827eed2fb947978b38244a7448985b.zip?dn=ECM1.zip
```

You should now have the folder "ECM1" with the original data in CSV format in "ECM1/ECM1.txt".

### Process the data

Run `julia map_ecm1.jl`. This will produce a 1x1deg lonlat file "Mooney2023_Sediments.nc" with the variable `H_sed` representing the sediment thickness.

### Produce the corresponding grid description file

```bash
cdo griddes Mooney2023_Sediments.nc > ../maps/grid_lonlat-1.0deg-360x180.txt
```

### Map to grid as needed using CDO

