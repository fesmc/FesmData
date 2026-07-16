## McManus et al. (2004) - North Atlantic Core GGC5 231Pa/230Th Meridional Circulation Data

Reconstruction of the Atlantic meridional overturning circulation (AMOC) for the last
deglaciation, based on 231Pa/230Th measurements in sediment core OCE326-GGC5 (Bermuda Rise, western subtropical North
Atlantic), together with the companion G. inflata delta-18O record from the same core.

Source: https://www.ncei.noaa.gov/access/paleo-search/study/6406

Citation: McManus, J.F., Francois, R., Gherardi, J.-M., Keigwin, L.D., Brown-Leger, S.
Collapse and rapid resumption of Atlantic meridional circulation linked to deglacial
climate changes. Nature 428, 834-837 (2004). https://doi.org/10.1038/nature02494

## Download the data

The original data (`mcmanus2004.txt`) can be downloaded in .txt format here: https://www.ncei.noaa.gov/access/paleo-search/study/6406

The script `process_data.py` produces the `mcmanus2004.nc` file with the following structure:

**Dimensions**
- `age_pa_th` [kyr BP]: age axis of the 231Pa/230Th record 
- `age_d18o` [kyr BP]: age axis of the d18O record 

**Variables**
| Variable   | Dim         | Description                                          | Units           |
|------------|-------------|-------------------------------------------------------|-----------------|
| `pa_th238` | `age_pa_th` | 231Pa/230Th, 238-based age model (AMOC proxy)          | activity ratio  |
| `error238` | `age_pa_th` | Error of `pa_th238`                                    | activity ratio  |
| `pa_th232` | `age_pa_th` | 231Pa/230Th, 232-based age model (AMOC proxy)          | activity ratio  |
| `error232` | `age_pa_th` | Error of `pa_th232`                                    | activity ratio  |
| `d18O`     | `age_d18o`  | G. inflata delta-18O                                   | permil (VPDB)   |

