# The original datasets of all pipelines, listed in ../datamanifest.toml.

using DataManifest

"DataManifest database of the original datasets."
manifest() = read_dataset(joinpath(dirname(@__DIR__), "datamanifest.toml"); persist=false)
