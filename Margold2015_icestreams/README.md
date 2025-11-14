# Ice stream outlines

Source: [https://www.tandfonline.com/doi/figure/10.1080/17445647.2014.912036](https://www.tandfonline.com/doi/figure/10.1080/17445647.2014.912036)
Citation: Margold, M., Stokes, C. R., Clark, C. D. & Kleman, J.: Ice streams in the Laurentide Ice Sheet: a new mapping inventory, J. Maps 11, 380–395, doi:10.1080/17445647.2014.912036, 2015.

## Steps

1. Download data from the link below into a zip file. This must be done by hand.

    [https://www.tandfonline.com/doi/figure/10.1080/17445647.2014.912036](https://www.tandfonline.com/doi/figure/10.1080/17445647.2014.912036)

2. Unzip the data to a new folder:

    ```bash
    unzip ISshp.zip -d ISshp
    rm ISshp.zip
    ```

3. Run step by step through the script `map_icestreams.jl` to first generate a NetCDF file with the data on the native grid projection (Margold2015_icestreams.nc) and then to produce a remapped version on a grid of choice (e.g., LIS-16KM_Margold2015_icestreams.nc).
