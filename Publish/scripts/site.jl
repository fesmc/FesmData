# Write the website of the published products (see Publish/README.md).
#
#   julia Publish/scripts/site.jl [DIR]     # default: _site

include(joinpath(@__DIR__, "..", "site.jl"))

println("Wrote ", write_site(isempty(ARGS) ? "_site" : ARGS[1]))
