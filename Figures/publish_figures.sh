#!/bin/bash
#
# Put the figures of datasets on the site: copy docs/figures/<Dataset>/*.png (made by
# `julia fesmdata.jl figures <Dataset>`) into the site branch gh-pages, which keeps a
# single commit, so that the figures are not versioned (see Figures/README.md). Run
# from the FesmData root of a checkout that can push to GitHub, with the figures in
# docs/figures/ (made on Levante: copy them first), before pushing the galleries to
# main, and not while the docs workflow deploys:
#
#     rsync -a levante:<checkout>/docs/figures/Topo/ docs/figures/Topo/
#     Figures/publish_figures.sh Topo
#
set -euo pipefail
[ $# -ge 1 ] || { echo "usage: Figures/publish_figures.sh <Dataset> ..." >&2; exit 1; }
for d in "$@"; do
    compgen -G "docs/figures/$d/*.png" > /dev/null || { echo "no figures in docs/figures/$d" >&2; exit 1; }
done

site=$(mktemp -d)
branch=site-figures-$$
cleanup() { git worktree remove --force "$site" 2>/dev/null || true; git branch -D "$branch" 2>/dev/null || true; rm -rf "$site"; }
trap cleanup EXIT

git fetch --depth 1 origin gh-pages
git worktree add --detach "$site" FETCH_HEAD
for d in "$@"; do
    rm -rf "$site/figures/$d"
    mkdir -p "$site/figures/$d"
    cp docs/figures/$d/*.png "$site/figures/$d/"
    echo "$d: $(ls "$site/figures/$d" | wc -l) figures"
done
git -C "$site" checkout -q --orphan "$branch"
git -C "$site" add -A
git -C "$site" commit -q -m "Built site, with the figures of $*"
git -C "$site" push -f origin "$branch:gh-pages"
