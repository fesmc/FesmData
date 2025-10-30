# FesmData

Repository to manage data processing strategies to provide input to FESMs or for data analysis or comparison. Each dataset should be managed within its own sub-directory (which serves as the identifying "Key" in the table below). Within a dataset's sub-directory, we should at least have:

1. A README.md file with general information, sources and references, instructions for how to process the data into a useable format (e.g. onto a desired grid) and any additional important notes (like unexpected behavior, exceptions, things to look out for, etc.).
2. Scripts/programs/tools needed to process the data as described in the README.

The data itself most often should not be stored in this repository itself. In fact, it is preferred if the first step of the instructions provided explain how to obtain the original data. As a rule of thumb, if the original dataset is < 10 Mb, consider including it directly within the repository for convenience, but please still document how it can be obtained. This will ensure the processed data can be recreated in the most reliable way possible. See Batchelor2019_NHIceMasks as an example.

## Shared resources

Some resources are used across datasets, in particular grid definitions that may be targets and the end of the data processing.

`maps` : this folder contains predefined grid description files following the `cdo` conventions.
`grids` : this folder contains some tools to generate files corresponding to specific grid definitions as in `maps`.

Eventually we may include a `remapping` folder dedicated to taking processed datasets (on their own, or a convenient, resolution) and mapping them to become input datasets on a specific grid.

## Alternative and past approaches

In the past, we used the `gridding` (https://github.com/alex-robinson/gridding)[https://github.com/alex-robinson/gridding] program to handle remapping (and preprocessing) of a wide variety of datasets that were relevant for ice-sheet modeling. This was how the original `ice_data` repository of gridded datasets was populated. It worked well, but was difficult to modify for new datasets, since it is entirely in Fortran, and requires configuration and compilation. For this reason, remapping via conservative interpolation using `cdo` became the favored approach for individual datasets. What was not included then was the preprocessing steps needed before applying interpolation. Hopefully this repository solves that problem.

## List of available datasets/methods (alphabetical order)

| Category | Key | Description | Ref(s) |
|----------|-----|-------------|--------|
| masks    | regions                  | Ice relevant regions                 | Robinson et al.  - no ref |
| topo     | Batchelor2019_NHIceMasks | Northern Hemisphere ice extent masks | Batchelor et al. (2019)   |
| topo     | Morlighem2017_BedMachine | Bedmachine ice topography data       | Morlighem et al. (2017)   |
| topo     | RTOPO2                   | RTopo2 global topography data        | Schaeffer et al. (2019)   |