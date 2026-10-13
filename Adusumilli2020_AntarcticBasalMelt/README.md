# Antarctic basal melt

High-resolution estimates of ice-shelf basal melting and height changes.

Source: https://library.ucsd.edu/dc/object/bb0448974g
Reference: Adusumilli, S., Fricker, H.A., Medley, B. et al.:  Interannual variations in meltwater input to the Southern Ocean from Antarctic ice shelves, Nat. Geosci. 13, 616–620, doi:10.1038/s41561-020-0616-z, 2020.

## Steps

1. Download the data

    ```bash
    mkdir data
    cd data
    wget https://library.ucsd.edu/dc/object/bb0448974g/_1_1.txt/download
    mv download readme
    wget https://library.ucsd.edu/dc/object/bb0448974g/_2_1.h5/download
    mv download iceshelf_height.h5
    wget https://library.ucsd.edu/dc/object/bb0448974g/_3_1.h5/download
    mv download iceshelf_melt.h5
    ```

    Or maybe better from the GitHub site:
    
    ```bash
    wget https://github.com/sioglaciology/ice_shelf_change/archive/refs/heads/master.zip data_github
    ```


