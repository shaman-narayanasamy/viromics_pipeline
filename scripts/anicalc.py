#!/usr/bin/env python

"""Calculate pairwise ANI from BLAST tabular output.

Adopted from the CheckV supporting scripts used by the original
cluster_viral_sequences best-practice workflow.
"""

import argparse
import gzip


def parse_blast(handle):
    for line in handle:
        r = line.split()
        yield {
            "qname": r[0],
            "tname": r[1],
            "pid": float(r[2]),
            "len": float(r[3]),
            "qcoords": sorted([int(r[6]), int(r[7])]),
            "tcoords": sorted([int(r[8]), int(r[9])]),
            "qlen": float(r[-2]),
            "tlen": float(r[-1]),
            "evalue": float(r[-4]),
        }


def yield_alignment_blocks(handle):
    key, alns = None, None
    for aln in parse_blast(handle):
        key = (aln["qname"], aln["tname"])
        alns = [aln]
        break
    if alns is None:
        return
    for aln in parse_blast(handle):
        if (aln["qname"], aln["tname"]) == key:
            alns.append(aln)
        else:
            yield alns
            key = (aln["qname"], aln["tname"])
            alns = [aln]
    yield alns


def prune_alns(alns, min_length=0, min_evalue=1e-3):
    keep = []
    cur_aln = 0
    qry_len = alns[0]["qlen"]
    for aln in alns:
        qcoords = aln["qcoords"]
        aln_len = max(qcoords) - min(qcoords) + 1
        if aln_len < min_length or aln["evalue"] > min_evalue:
            continue
        if cur_aln >= qry_len or aln_len + cur_aln >= 1.10 * qry_len:
            break
        keep.append(aln)
        cur_aln += aln_len
    return keep


def compute_ani(alns):
    return round(
        sum(a["len"] * a["pid"] for a in alns) / sum(a["len"] for a in alns), 2
    )


def merge_cov(alns, key, length_key):
    coords = sorted([a[key] for a in alns])
    nr_coords = [coords[0]]
    for start, stop in coords[1:]:
        if start <= (nr_coords[-1][1] + 1):
            nr_coords[-1][1] = max(nr_coords[-1][1], stop)
        else:
            nr_coords.append([start, stop])
    alen = sum([stop - start + 1 for start, stop in nr_coords])
    return round(100.0 * alen / alns[0][length_key], 2)


def compute_cov(alns):
    return merge_cov(alns, "qcoords", "qlen"), merge_cov(alns, "tcoords", "tlen")


def parse_arguments():
    parser = argparse.ArgumentParser()
    parser.add_argument("-i", dest="input", required=True, help="BLAST tabular input")
    parser.add_argument("-o", dest="output", required=True, help="ANI TSV output")
    parser.add_argument("-l", dest="length", type=int, help="minimum alignment length")
    return vars(parser.parse_args())


if __name__ == "__main__":
    args = parse_arguments()
    out = gzip.open(args["output"], "wt") if args["output"].endswith(".gz") else open(args["output"], "w")
    fields = ["qname", "tname", "num_alns", "pid", "qcov", "tcov"]
    out.write("\t".join(fields) + "\n")
    input_handle = gzip.open(args["input"], "rt") if args["input"].endswith(".gz") else open(args["input"])
    for alns in yield_alignment_blocks(input_handle):
        alns = prune_alns(alns, min_length=args["length"] or 0)
        if len(alns) == 0:
            continue
        qname, tname = alns[0]["qname"], alns[0]["tname"]
        ani = compute_ani(alns)
        qcov, tcov = compute_cov(alns)
        row = [qname, tname, len(alns), ani, qcov, tcov]
        out.write("\t".join([str(_) for _ in row]) + "\n")
    input_handle.close()
    out.close()

