#!/usr/bin/env python

"""Centroid-based viral sequence clustering from ANI edges.

Adopted from the CheckV supporting scripts used by the original
cluster_viral_sequences best-practice workflow.
"""

import argparse
import gzip
import platform
import resource
import time


def parse_seqs(path):
    handle = gzip.open(path, "rt") if path.endswith(".gz") else open(path)
    seq_id = next(handle).split()[0][1:]
    seq = ""
    for line in handle:
        if line[0] == ">":
            yield seq_id, seq
            seq_id = line.split()[0][1:]
            seq = ""
        else:
            seq += line.rstrip()
    yield seq_id, seq
    handle.close()


def max_mem_usage():
    max_mem_self = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
    max_mem_child = resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss
    if platform.system() == "Linux":
        return round((max_mem_self + max_mem_child) / float(1e6), 2)
    return round((max_mem_self + max_mem_child) / float(1e9), 2)


def log_time(start):
    current_time = time.time()
    program_time = round(current_time - start, 2)
    peak_ram = round(max_mem_usage(), 2)
    print("time: %s seconds, peak RAM: %s GB" % (program_time, peak_ram))


def parse_arguments():
    parser = argparse.ArgumentParser(
        formatter_class=argparse.RawTextHelpFormatter,
        description="Centroid based sequence clustering",
    )
    parser.add_argument("--fna", required=True, help="nucleotide FASTA")
    parser.add_argument("--ani", required=True, help="ANI TSV")
    parser.add_argument("--out", required=True, help="cluster output")
    parser.add_argument("--exclude", help="sequence IDs to exclude")
    parser.add_argument("--keep", help="sequence IDs to keep")
    parser.add_argument("--min_ani", type=float, default=95)
    parser.add_argument("--min_qcov", type=float, default=0)
    parser.add_argument("--min_tcov", type=float, default=85)
    parser.add_argument("--min_length", type=float, default=1)
    return vars(parser.parse_args())


start = time.time()
args = parse_arguments()

print("\nreading sequences...")
seqs = {}
exclude = set([_.rstrip() for _ in open(args["exclude"])]) if args["exclude"] else None
keep = set([_.rstrip() for _ in open(args["keep"])]) if args["keep"] else None
for seq_id, seq in parse_seqs(args["fna"]):
    if len(seq) < args["min_length"]:
        continue
    if exclude and seq_id in exclude:
        continue
    if keep and seq_id not in keep:
        continue
    seqs[seq_id] = len(seq)
seqs = [x[0] for x in sorted(seqs.items(), key=lambda x: x[1], reverse=True)]
print("%s sequences retained from fna" % len(seqs))
log_time(start)

print("\nstoring edges...")
num_edges = 0
edges = dict([(x, []) for x in seqs])
handle = gzip.open(args["ani"], "rt") if args["ani"].endswith(".gz") else open(args["ani"])
for line in handle:
    qname, tname, num_alns, ani, qcov, tcov = line.split()
    if qname == "qname":
        continue
    if qname == tname:
        continue
    if qname not in edges or tname not in edges:
        continue
    if float(qcov) < args["min_qcov"] or float(tcov) < args["min_tcov"] or float(ani) < args["min_ani"]:
        continue
    edges[qname].append(tname)
    num_edges += 1
handle.close()
print("%s edges retained from blastani" % num_edges)
print("%s edges currently stored" % sum([len(_) for _ in edges.values()]))
log_time(start)

print("\nclustering...")
clust_to_seqs = {}
seq_to_clust = {}
for seq_id in seqs:
    if seq_id in seq_to_clust:
        continue
    clust_to_seqs[seq_id] = [seq_id]
    seq_to_clust[seq_id] = seq_id
    for mem_id in edges[seq_id]:
        if mem_id not in seq_to_clust:
            clust_to_seqs[seq_id].append(mem_id)
            seq_to_clust[mem_id] = seq_id
print("%s total clusters" % len(clust_to_seqs))
log_time(start)

print("\nwriting clusters...")
with open(args["out"], "w") as out:
    for seq_id, mem_ids in clust_to_seqs.items():
        out.write(seq_id + "\t" + ",".join(mem_ids) + "\n")
log_time(start)

