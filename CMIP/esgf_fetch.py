#!/usr/bin/env python3
"""Fetch CMIP5/CMIP6 files from ESGF into a local data pool laid out as the ESGF dataset ids.

A dataset id (e.g. cmip5.output1.NCAR.CCSM4.lgm.mon.atmos.Amon.r1i1p1.v20120203 or
CMIP6.PMIP.NCAR.CESM2-FV2.lgm.r1i1p1f1.Amon.pr.gn.v20191120) is stored under
<root>/<id with "." replaced by "/">, the layout of the AWI pool
(/albedo/work/projects/p_pool_clim_data) and of the DKRZ pools. The latest version of the
dataset is taken, from the first data node in --nodes that holds it (else any node). With
--last-years N only the files that overlap the last N years of the run are fetched. Files
already present with the right size, under --root or readable under one of the --skip-in
roots (other pools of the same layout), are skipped. With --subset-depth D (3-D ocean
fields) only the levels down to D m (and the last N years) are fetched, by OPeNDAP with ncks
(NCO), as compressed netCDF-4 files under the same names. A file that fails on the chosen node
is fetched from another node holding the same version. Standard library only.

Examples:
    esgf_fetch.py --root $POOL CMIP5 CCSM4 piControl Amon pr --member r1i1p1 --last-years 100
    esgf_fetch.py --root $POOL CMIP5 CCSM4 lgm fx sftlf --member r0i0p0
    esgf_fetch.py --root $POOL CMIP6 CESM2-FV2 lgm Amon pr --member r1i1p1f1 --last-years 100 --dry-run
    esgf_fetch.py --root $POOL CMIP5 MPI-ESM-P piControl Omon thetao --member r1i1p1 --last-years 30 --subset-depth 3000
"""
import argparse, json, os, re, subprocess, sys, time, urllib.parse, urllib.request

INDEX = "https://esgf.ceda.ac.uk/esg-search/search"
NODES = ["esgf.ceda.ac.uk", "esgf1.dkrz.de", "esgf-data1.llnl.gov", "esgf.nci.org.au", "esgf-data.dkrz.de"]
# CMIP5 models whose search facet differs from the name in the dataset ids
CMIP5_FACET = {"bcc-csm1-1": "BCC-CSM1.1", "bcc-csm1-1-m": "BCC-CSM1.1(m)", "CSIRO-Mk3-6-0": "CSIRO-Mk3.6.0"}


def search(params):
    q = dict(params, format="application/solr+json", limit=10000, distrib="true")
    url = INDEX + "?" + urllib.parse.urlencode(q)
    for attempt in range(3):
        try:
            return json.load(urllib.request.urlopen(url, timeout=180))["response"]["docs"]
        except Exception as e:
            if attempt == 2:
                raise
            time.sleep(10)


def span(title):
    """First and last year of a file from its name (..._YYYYMM-YYYYMM.nc and similar)."""
    m = re.search(r"_(\d{4,8})-(\d{4,8})(?:-clim)?\.nc$", title)
    if not m:
        return None
    a, b = m.group(1), m.group(2)
    return int(a[:4] if len(a) > 6 else a[:-2]), int(b[:4] if len(b) > 6 else b[:-2])


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("project", choices=["CMIP5", "CMIP6"])
    p.add_argument("model")
    p.add_argument("experiment")
    p.add_argument("table", help="MIP table, e.g. Amon, Omon, OImon, SImon, fx, Ofx")
    p.add_argument("variable")
    p.add_argument("--member", required=True, help="ensemble member / variant label")
    p.add_argument("--root", required=True, help="pool root written to (holds cmip5/ and CMIP6/)")
    p.add_argument("--skip-in", default="", help="other pool roots (':'-separated) whose readable files are not fetched again")
    p.add_argument("--last-years", type=int, default=0, help="only files overlapping the last N years (0: all)")
    p.add_argument("--nodes", default=",".join(NODES), help="preferred data nodes, in order")
    p.add_argument("--subset-depth", type=float, default=0,
                   help="only the levels down to this depth [m], by OPeNDAP with ncks (0: whole files by HTTP)")
    p.add_argument("--level-dim", default="lev", help="vertical dimension of --subset-depth")
    p.add_argument("--dry-run", action="store_true")
    a = p.parse_args()

    q = dict(project=a.project, type="File", variable=a.variable, fields="dataset_id,title,url,size,data_node,checksum")
    if a.project == "CMIP5":
        q.update(model=CMIP5_FACET.get(a.model, a.model), experiment=a.experiment, cmor_table=a.table, ensemble=a.member)
    else:
        q.update(source_id=a.model, experiment_id=a.experiment, table_id=a.table, variant_label=a.member)
    docs = search(q)
    if not docs:
        sys.exit(f"no {a.project} {a.model} {a.experiment} {a.table} {a.variable} {a.member} on ESGF")
    byver = {}
    for d in docs:
        ds = d["dataset_id"].split("|")[0]
        ver = ds.split(".")[-1]
        byver.setdefault(ver, {}).setdefault(d["data_node"], []).append(d)
    vkey = lambda v: re.sub(r"\D", "", v).zfill(8)
    # the latest version on the first preferred node that has the dataset, else the latest anywhere
    pref = a.nodes.split(",")
    held = [(n, max((v for v in byver if n in byver[v]), key=vkey)) for n in pref
            if any(n in byver[v] for v in byver)]
    if held:
        node, ver = held[0]
    else:
        ver = max(byver, key=vkey)
        node = sorted(byver[ver])[0]
    files = list({f["title"]: f for f in byver[ver][node]}.values())
    last = None
    if a.last_years > 0:
        spans = {f["title"]: span(f["title"]) for f in files}
        if any(s is None for s in spans.values()):
            sys.exit("cannot read the years of " + ", ".join(t for t, s in spans.items() if s is None))
        last = max(s[1] for s in spans.values())
        files = [f for f in files if spans[f["title"]][1] > last - a.last_years]
    if a.subset_depth > 0:      # nodes with an OPeNDAP service only
        files = [f for f in files if any(u.split("|")[2] == "OPENDAP" for u in f["url"])]
        if not files:
            sys.exit(f"no OPeNDAP service on {node}")
    dsid = next(iter(files))["dataset_id"].split("|")[0]
    parts = dsid.split(".")
    if a.project == "CMIP5":
        parts[0] = "cmip5"
    dest = os.path.join(a.root, *parts)
    total = sum(f["size"] for f in files)
    print(f"{dsid} from {node}: {len(files)} files, {total / 1e6:.0f} MB -> {dest}")
    if a.dry_run:
        for f in sorted(files, key=lambda f: f["title"]):
            print("  ", f["title"], f"{f['size'] / 1e6:.0f} MB")
        return
    def present(root, title, size, anyversion=False):
        vdir = os.path.join(root, *parts[:-1])
        vers = [parts[-1]] + (sorted(os.listdir(vdir)) if anyversion and os.path.isdir(vdir) else [])
        for v in vers:
            q = os.path.join(vdir, v, title)
            if os.path.exists(q) and os.access(q, os.R_OK) and (anyversion or a.subset_depth > 0 or os.path.getsize(q) == size):
                return True
        return False
    others = [r for r in a.skip_in.split(":") if r]
    files = [f for f in files if not any(present(r, f["title"], f["size"], anyversion=True) for r in others)]
    if not files:
        print("  all present")
        return
    os.makedirs(dest, exist_ok=True)
    first = last - a.last_years + 1 if a.last_years > 0 else None
    service = "OPENDAP" if a.subset_depth > 0 else "HTTPServer"
    for f in sorted(files, key=lambda f: f["title"]):
        path = os.path.join(dest, f["title"])
        if present(a.root, f["title"], f["size"]):
            continue
        # the file on the chosen node, then on the other nodes with the same version
        urls = [u.split("|")[0] for n in [node] + sorted(set(byver[ver]) - {node})
                for g in byver[ver][n] if g["title"] == f["title"]
                for u in g["url"] if u.split("|")[2] == service]
        tmp = path + ".part"
        for url in [u for u in urls for _ in range(2)]:       # two attempts per node
            try:
                if a.subset_depth > 0:
                    opendap_subset(url[:-5] if url.endswith(".html") else url, a, f["title"], first, tmp)
                else:
                    urllib.request.urlretrieve(url, tmp)
                    if os.path.getsize(tmp) != f["size"]:
                        raise IOError(f"size {os.path.getsize(tmp)} != {f['size']}")
                os.replace(tmp, path)
                break
            except Exception as e:
                print(f"  failed {url}: {e}", file=sys.stderr)
                time.sleep(10)
        else:
            sys.exit(f"failed: {f['title']} ({len(urls)} nodes)")
        print("  ", f["title"])


def opendap_subset(url, a, title, first, path):
    """The levels down to a.subset_depth of the monthly file `url` (from the year `first` on,
    if given), by OPeNDAP in pieces of a year (servers limit the size of a request)."""
    run = lambda *cmd: subprocess.run(cmd, check=True, stdout=subprocess.PIPE, universal_newlines=True).stdout
    nt = int(re.search(r"time = (?:UNLIMITED ; // \()?(\d+)", run("ncks", "-m", "-v", "time", url)).group(1))
    start = re.search(r"_(\d{4,8})-\d{4,8}(?:-clim)?\.nc$", title).group(1)
    y0, m0 = int(start[:-2] if len(start) <= 6 else start[:4]), int(start[-2:] if len(start) <= 6 else start[4:6])
    i0 = max(0, (first - y0) * 12 - (m0 - 1)) if first else 0
    pieces = []
    for i in range(i0, nt, 12):
        piece = f"{path}.{len(pieces):03d}"
        run("ncks", "-O", "-4", "-L", "1", "-v", a.variable, "-d", f"{a.level_dim},0.,{a.subset_depth}",
            "-d", f"time,{i},{min(i + 11, nt - 1)}", url, piece)
        pieces.append(piece)
    run("ncrcat", "-O", "-4", "-L", "1", *pieces, path)
    for piece in pieces:
        os.remove(piece)


if __name__ == "__main__":
    main()
