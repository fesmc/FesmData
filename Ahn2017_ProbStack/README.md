# Probabilistic benthic d18O stack, 5 Myr (Ahn et al., 2017)

The probabilistic stack (Prob-stack) of 180 benthic δ18O records over the last 5 Myr,
constructed with a profile hidden Markov model, with its standard deviation and 95%
interval. From:

Ahn, S., Khider, D., Lisiecki, L. E., and Lawrence, C. E.: A probabilistic
Pliocene-Pleistocene stack of benthic δ18O using a profile hidden Markov model, Dyn. Stat.
Clim. Syst., 2, dzx002, 2017,
[doi:10.1093/climsys/dzx002](https://doi.org/10.1093/climsys/dzx002).

Data: `Prob_stack.txt` of the repository of the authors,
https://github.com/seonminahn/HMM-Stack (no copy in a data centre).

## Licence

GPL-3.0 (the repository of the authors).

## Original data

`Prob_stack.txt` at commit c8125f8 of the repository (last changed in 2016, before the
publication of the article), downloaded by `prepare.jl` (datamanifest key
`ahn2017_probstack`): five columns without header, age (ka), δ18O (‰), its standard
deviation, and the upper and lower bounds of the 95% interval; 2051 values every 1 kyr to
600 ka, then 2, 2.5 and 5 kyr to 5000 ka. The stack of the LR04 cores only
(`Prob_LR04_stack.txt`) is not used.

## Prepare and record

```bash
julia --project=Ahn2017_ProbStack Ahn2017_ProbStack/prepare.jl
julia fesmdata.jl record Stacks ProbStack
```

`prepare.jl` writes `$FESMDATA_PREPARED/Ahn2017_ProbStack/Ahn2017_ProbStack.nc` (see
`Records/README.md`), a global series (dimension `region`, no location): `d18O_benthic`,
`d18O_benthic_sd`, `d18O_benthic_min`, `d18O_benthic_max` (‰).
