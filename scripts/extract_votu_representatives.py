#!/usr/bin/env python

"""Extract representative vOTU sequences from a canonical clusters file."""

import argparse


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--fasta", required=True)
    parser.add_argument("--clusters", required=True)
    parser.add_argument("--output", required=True)
    return parser.parse_args()


def read_representatives(path):
    reps = set()
    with open(path) as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            reps.add(line.split("\t", 1)[0])
    return reps


def fasta_records(path):
    seq_id = None
    seq_lines = []
    with open(path) as handle:
        for line in handle:
            if line.startswith(">"):
                if seq_id is not None:
                    yield seq_id, header, seq_lines
                header = line.rstrip()
                seq_id = header[1:].split()[0]
                seq_lines = []
            else:
                seq_lines.append(line)
        if seq_id is not None:
            yield seq_id, header, seq_lines


def main():
    args = parse_args()
    reps = read_representatives(args.clusters)
    found = set()
    with open(args.output, "w") as out:
        for seq_id, header, seq_lines in fasta_records(args.fasta):
            if seq_id in reps:
                found.add(seq_id)
                out.write(header + "\n")
                out.writelines(seq_lines)
    missing = reps - found
    if missing:
        raise SystemExit("Missing representative sequences in FASTA: " + ",".join(sorted(missing)[:20]))


if __name__ == "__main__":
    main()

