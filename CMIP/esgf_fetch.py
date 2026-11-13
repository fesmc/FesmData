#!/usr/bin/env python3
"""Fetch CMIP5/CMIP6 files from ESGF into a local data pool laid out as the ESGF dataset ids.

A dataset id (e.g. cmip5.output1.NCAR.CCSM4.lgm.mon.atmos.Amon.r1i1p1.v20120203 or
CMIP6.PMIP.NCAR.CESM2-FV2.lgm.r1i1p1f1.Amon.pr.gn.v20191120) is stored under
<root>/<id with "." replaced by "/">, the layout of the AWI pool
(/albedo/work/projects/p_pool_clim_data) and of the DKRZ pools. The latest version of the
dataset is taken, from the first data node in --nodes that holds it (else any node). With
--last-years N only the files that overlap the last N years of the run are fetched. Files
already present with the right size, under --root or readable under one of the --skip-in
roots (other pools of the same layout), are skipped. Standard library only.

Examples:
    esgf_fetch.py --root $POOL CMIP5 CCSM4 piControl Amon pr --member r1i1p1 --last-years 100
    esgf_fetch.py --root $POOL CMIP5 CCSM4 lgm fx sftlf --member r0i0p0
    esgf_fetch.py --root $POOL CMIP6 CESM2-FV2 lgm Amon pr --member r1i1p1f1 --last-years 100 --dry-run
"""
import argparse, json, os, re, sys, time, urllib.parse, urllib.request

INDEX = "https://esgf.ceda.ac.uk/esg-search/search"
NODES = ["esgf.ceda.ac.uk", "esgf1.dkrz.de", "esgf-data1.llnl.gov", "esgf.nci.org.au", "esgf-data.dkrz.de"]


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
    p.add_argument("--dry-run", action="store_true")
    a = p.parse_args()

    q = dict(project=a.project, type="File", variable=a.variable, fields="dataset_id,title,url,size,data_node,checksum")
    if a.project == "CMIP5":
        q.update(model=a.model, experiment=a.experiment, cmor_table=a.table, ensemble=a.member)
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
    if a.last_years > 0:
        spans = {f["title"]: span(f["title"]) for f in files}
        if any(s is None for s in spans.values()):
            sys.exit("cannot read the years of " + ", ".join(t for t, s in spans.items() if s is None))
        last = max(s[1] for s in spans.values())
        files = [f for f in files if spans[f["title"]][1] > last - a.last_years]
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
            if os.path.exists(q) and os.access(q, os.R_OK) and (anyversion or os.path.getsize(q) == size):
                return True
        return False
    others = [r for r in a.skip_in.split(":") if r]
    files = [f for f in files if not any(present(r, f["title"], f["size"], anyversion=True) for r in others)]
    if not files:
        print("  all present")
        return
    os.makedirs(dest, exist_ok=True)
    for f in sorted(files, key=lambda f: f["title"]):
        path = os.path.join(dest, f["title"])
        if present(a.root, f["title"], f["size"]):
            continue
        url = next(u.split("|")[0] for u in f["url"] if u.split("|")[2] == "HTTPServer")
        tmp = path + ".part"
        for attempt in range(3):
            try:
                urllib.request.urlretrieve(url, tmp)
                if os.path.getsize(tmp) != f["size"]:
                    raise IOError(f"size {os.path.getsize(tmp)} != {f['size']}")
                os.replace(tmp, path)
                break
            except Exception as e:
                print(f"  retry {f['title']}: {e}", file=sys.stderr)
                time.sleep(20)
        else:
            sys.exit(f"failed: {url}")
        print("  ", f["title"])


if __name__ == "__main__":
    main()
