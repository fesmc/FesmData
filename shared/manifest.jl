# The original datasets of all pipelines, listed in ../datamanifest.toml.

using DataManifest

include(joinpath(@__DIR__, "provenance.jl"))

"DataManifest database of the original datasets, with `\$datasets_dir` the sources folder (see `fesmdata_dir`)."
manifest() = read_dataset(joinpath(dirname(@__DIR__), "datamanifest.toml"); persist=false,
                          storage_config=Dict("datasets_dir" => fesmdata_dir("sources")))
