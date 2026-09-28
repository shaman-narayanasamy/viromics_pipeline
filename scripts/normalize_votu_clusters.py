#!/usr/bin/env python

"""Normalize vOTU cluster outputs to representative<TAB>members."""

import argparse
import csv
from collections import defaultdict


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--clusters", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--summary", required=True)
    parser.add_argument("--format", choices=["best_practice", "vclust"], required=True)
    return parser.parse_args()


def read_best_practice(path):
    clusters = {}
    with open(path) as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            rep, members = line.split("\t", 1)
            clusters[rep] = [m for m in members.split(",") if m]
    return clusters


def read_vclust(path):
    grouped = defaultdict(list)
    with open(path, newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        required = {"object", "cluster"}
        if not reader.fieldnames or not required.issubset(set(reader.fieldnames)):
            raise ValueError("Expected vclust columns: object and cluster")
        for row in reader:
            grouped[row["cluster"]].append(row["object"])
    clusters = {}
    for rep, members in grouped.items():
        ordered = [rep] + sorted([m for m in members if m != rep])
        clusters[rep] = ordered
    return clusters


def source_prefix(member):
    parts = member.split("_")
    if len(parts) < 3:
        return member
    if len(parts) >= 4 and parts[1] == "coassembly":
        return "_".join(parts[:3])
    return "_".join(parts[:3])


def main():
    args = parse_args()
    clusters = read_best_practice(args.clusters) if args.format == "best_practice" else read_vclust(args.clusters)
    with open(args.output, "w") as out, open(args.summary, "w") as summary:
        summary.write("representative\tn_members\tsources\tmembers\n")
        for rep in sorted(clusters):
            members = clusters[rep]
            out.write(rep + "\t" + ",".join(members) + "\n")
            sources = sorted({source_prefix(member) for member in members})
            summary.write(
                rep + "\t" + str(len(members)) + "\t" + ",".join(sources) + "\t" + ",".join(members) + "\n"
            )


if __name__ == "__main__":
    main()

