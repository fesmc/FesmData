#!/bin/bash
#
# Submit the steps of the topography pipeline for one domain as a chain of jobs,
# each starting when the previous step has succeeded. Step 2 runs one job per source.
# Run from the FesmData root after sourcing the machine environment:
#
#     Topo/jobs/submit_domain.sh DOMAIN [FIRST_STEP] [PRODUCTS]
#
# FIRST_STEP (1-5, default 1) skips the earlier steps. PRODUCTS selects the products
# of steps 2-5: "default" (the default), "variants", "all", or one product (see
# products.toml); step 2 remaps the sources of these products.
#
set -euo pipefail
domain=$1
first=${2:-1}
products=${3:-default}
run=Topo/jobs/run_step.sbatch

sources=$(julia --project=Topo -e 'include("Topo/common.jl"); d = Domain(ARGS[1]);
    println(join(unique(reduce(vcat, [product_sources(d)[p] for p in select_products(d, ARGS[2])]; init=String[])), " "))' \
    "$domain" "$products")
[ -n "$sources" ] || { echo "$domain has no $products products"; exit 1; }
tag=$domain; [ "$products" = default ] || tag=$domain-$products

dep=""
submit() {  # submit NAME TIME SCRIPT ARGS...; prints the job id
    sbatch --parsable $dep --job-name="$1" --time="$2" $run "${@:3}"
}

if [ "$first" -le 1 ]; then
    id=$(submit "grids-$domain" 00:30:00 01_grids.jl "$domain"); dep="--dependency=afterok:$id"
fi
if [ "$first" -le 2 ]; then
    ids=()
    for s in $sources; do
        ids+=("$(submit "src-$domain-$s" 01:00:00 02_regrid_source.jl "$domain" "$s")")
    done
    dep="--dependency=afterok:$(IFS=:; echo "${ids[*]}")"
fi
if [ "$first" -le 3 ]; then
    id=$(submit "merge-$tag" 01:00:00 03_merge.jl "$domain" "$products"); dep="--dependency=afterok:$id"
fi
if [ "$first" -le 4 ]; then
    id=$(submit "grids-all-$tag" 01:00:00 04_grids.jl "$domain" "$products"); dep="--dependency=afterok:$id"
fi
if [ "$first" -le 5 ]; then
    id=$(submit "plots-$tag" 01:00:00 05_plots.jl "$domain" "$products")
fi
squeue -u "$USER" -o "%.10i %.28j %.10T %.12r"
