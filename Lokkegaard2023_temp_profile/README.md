# Greenland and Canadian Arctic ice temperature profiles database

Article citation: Løkkegaard, A., Mankoff, K. D., Zdanowicz, C., Clow, G. D., Lüthi, M. P., Doyle, S. H., Thomsen, H. H., Fisher, D., Harper, J., Aschwanden, A., Vinther, B. M., Dahl-Jensen, D., Zekollari, H., Meierbachtol, T., McDowell, I., Humphrey, N., Solgaard, A., Karlsson, N. B., Khan, S. A., Hills, B., Law, R., Hubbard, B., Christoffersen, P., Jacquemart, M., Seguinot, J., Fausto, R. S., and Colgan, W. T.: Greenland and Canadian Arctic ice temperature profiles database, The Cryosphere, 17, 3829–3845, https://doi.org/10.5194/tc-17-3829-2023, 2023. 

Database citation: Mankoff, Ken; Løkkegaard, Anja; Colgan, William; Thomsen, Henrik; Clow, Gary; Fisher, David; Zdanowicz, Christian; Lüthi, Martin P.; Vinther, Bo; MacGregor, Joseph A.; McDowell, Ian; Zekollari, Harry; Meierbachtol, Toby; Doyle, Samuel; Law, Robert; Hills, Benjamin; Harper, Joel; Humphrey, Neil; Hubbard, Bryn; Christoffersen, Poul; Jacquemart, Mylène; Seguinot, Julien; Welty, Ethan, 2022, "Greenland and Canadian Arctic ice temperature profiles database", https://doi.org/10.22008/FK2/3BVF9V, GEUS Dataverse, V4 

## Steps
Download the original database of the temperature profiles in depth at different boreholes here:

https://dataverse.geus.dk/dataset.xhtml?persistentId=doi:10.22008/FK2/3BVF9V

Run the jupyter notebook `process_data.ipynb` to convert the original data into a single netCDF file with the temperature profiles and the associated metadata. The resulting file will be saved in the `output` directory as `temp_profiles.nc`.