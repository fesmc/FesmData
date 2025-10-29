# FesmData

Repository to manage data processing strategies to provide input to FESMs. Each dataset should be managed within its own sub-directory (which serves as the identifying "Key" in the table below). Within a dataset's sub-directory, we should have:

1. README.md file with general information, sources and references, instructions for how to process the data into a useable format (e.g. onto a desired grid) and any additional important notes (like unexpected behavior, exceptions, things to look out for, etc.).
2. Scripts/programs/tools needed to process the data as described in the README.

The data itself most often should not be stored in this repository itself. In fact, it is preferred if the first step of the instructions provided explain how to obtain the original data. This will ensure the processed data can be recreated in the most reliable way possible. See Batchelor2019 as an example.

## List of available datasets/methods (alphabetical order)

| Key | Description | Ref(s) |
|-----|-------------|--------|
Batchelor2019 | Northern Hemisphere ice extent masks | Batchelor et al. (2019) |
