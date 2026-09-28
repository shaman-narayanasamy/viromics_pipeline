#!/usr/bin/env python3
"""Build a viromics input table from multiomics_pipeline assembly outputs."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path


ASSEMBLY_TYPES = (
    "metatranscriptomics_megahit",
    "metatranscriptomics_penguin",
    "metagenomics_penguin",
    "coassembly_megahit",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Create a sample_alias/assembly_type/fasta table for viromics "
            "identification from multiomics_pipeline outputs."
        )
    )
    parser.add_argument("--metadata", required=True, type=Path, help="Multiomics sample metadata TSV.")
    parser.add_argument("--multiomics-output-dir", required=True, type=Path, help="Project-specific multiomics output directory.")
    parser.add_argument("--output", required=True, type=Path, help="Output viromics input TSV.")
    parser.add_argument(
        "--require-existing",
        action="store_true",
        help="Write only rows whose expected FASTA already exists.",
    )
    parser.add_argument(
        "--assembly-type",
        choices=ASSEMBLY_TYPES,
        action="append",
        help="Restrict output to one or more assembly types. Defaults to all supported types.",
    )
    return parser.parse_args()


def read_sample_omics(metadata: Path) -> dict[str, set[str]]:
    sample_omics: dict[str, set[str]] = {}
    with metadata.open(newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        for row in reader:
            sample = row.get("biological_sample_alias") or row.get("sample_alias")
            omics = row.get("omics")
            if not sample or not omics:
                continue
            sample_omics.setdefault(str(sample), set()).add(str(omics))
    return sample_omics


def expected_fastas(output_dir: Path, sample: str) -> dict[str, Path]:
    return {
        "metatranscriptomics_megahit": output_dir
        / "metatranscriptomics"
        / "assembly"
        / sample
        / "megahit_assembly"
        / f"{sample}.megahit_contigs.fa",
        "metatranscriptomics_penguin": output_dir
        / "metatranscriptomics"
        / "assembly"
        / sample
        / "penguin_assembly"
        / f"{sample}.penguin_contigs.fa",
        "metagenomics_penguin": output_dir
        / "metagenomics"
        / "assembly"
        / sample
        / "penguin_assembly"
        / f"{sample}.penguin_contigs.fa",
        "coassembly_megahit": output_dir / "coassembly" / sample / f"{sample}.coassembly_contigs.fa",
    }


def main() -> None:
    args = parse_args()
    requested_types = set(args.assembly_type or ASSEMBLY_TYPES)
    sample_omics = read_sample_omics(args.metadata)

    rows = []
    for sample in sorted(sample_omics):
        available_omics = sample_omics[sample]
        paths = expected_fastas(args.multiomics_output_dir, sample)

        if "MT" in available_omics:
            for assembly_type in ("metatranscriptomics_megahit", "metatranscriptomics_penguin"):
                fasta = paths[assembly_type]
                if assembly_type in requested_types and (fasta.exists() or not args.require_existing):
                    rows.append((sample, assembly_type, fasta))

        if "MG" in available_omics:
            assembly_type = "metagenomics_penguin"
            fasta = paths[assembly_type]
            if assembly_type in requested_types and (fasta.exists() or not args.require_existing):
                rows.append((sample, assembly_type, fasta))

        if {"MG", "MT"}.issubset(available_omics):
            assembly_type = "coassembly_megahit"
            fasta = paths[assembly_type]
            if assembly_type in requested_types and (fasta.exists() or not args.require_existing):
                rows.append((sample, assembly_type, fasta))

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", newline="") as handle:
        writer = csv.writer(handle, delimiter="\t")
        writer.writerow(["sample_alias", "assembly_type", "fasta"])
        writer.writerows((sample, assembly_type, str(fasta)) for sample, assembly_type, fasta in rows)


if __name__ == "__main__":
    main()
