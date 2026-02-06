# PaleoMIST v1.0

Global ice sheet reconstruction for the past 80 kyr.

Source: https://doi.pangaea.de/10.1594/PANGAEA.905800

Citation: Gowan, E.J., Zhang, X., Khosravi, S. et al. A new global ice sheet reconstruction for the past 80 000 years. Nat Commun 12, 1199 (2021). https://doi.org/10.1038/s41467-021-21469-w

## Steps

### Download the original datsets

- Go to this website: https://doi.pangaea.de/10.1594/PANGAEA.905800
- Click "Download dataset".
- Save Gowan_ice_reconstruction.zip locally to this folder.

Then run in the terminal:

```bash
unzip Gowan_ice_reconstruction.zip
rm -r rm -r __MACOSX Gowan_ice_reconstruction.zip
```

### Process the original datsets

In the folder ```Gowan_ice_reconstruction/ice_reconstruction/ice_reconstruction_files``` run the script:
```bash
cp process_paleomist.sh ./Gowan_ice_reconstruction/ice_reconstruction/ice_reconstruction_files/
cd Gowan_ice_reconstruction/ice_reconstruction/ice_reconstruction_files/
bash process_paleomist.sh
```
This will produce a nc file for each region (Antartica, Eurasia, North America and Patagonia). Note that "North America" includes also Greenland. 

