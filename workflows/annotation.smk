import subprocess
import pandas as pd

tmp_dir = os.environ.get("tmp_dir", config['tmp_dir'])

## Define output directory
output_dir = os.path.join(config['output_dir'],  "annotation")

if "single_sample" in config:
    # Override with single fasta and sample
    print(f"Using single sample: {config['single_sample']['sample_alias']} with fasta: {config['single_sample']['fasta']}")
    samples = pd.DataFrame({
        "sample_alias": [config["single_sample"]["sample_alias"]],
        "assembly_type": [config["single_sample"]["assembly_type"]],
        "fasta": [config["single_sample"]["fasta"]]
    })

    samples.set_index(["sample_alias", "assembly_type"], drop=False, inplace=True)

else:

    # Use the table by default
    samples = pd.read_table(config["data_table"], sep="\t", comment="#", dtype={"sample_alias": str})
    samples = samples.dropna(subset=["fasta"])
    samples.set_index(["sample_alias", "assembly_type"], drop=False, inplace=True)

sample_assembly_pairs = list(samples.index)

workdir:
    output_dir

include:
    "../rules/annotation/cenotetaker3.smk"

include:
    "../rules/annotation/vcontact3.smk"

include:
    "../rules/annotation/checkv.smk"

include:
    "../rules/annotation/neordrp.smk"

rule all:
     input:
        expand(
            "{sample}/{assembly_type}/cenotetaker3",
            zip,
            sample=[pair[0] for pair in sample_assembly_pairs],
            assembly_type=[pair[1] for pair in sample_assembly_pairs]
        ),
        expand(
            "{sample}/{assembly_type}/vcontact3",
            zip,
            sample=[pair[0] for pair in sample_assembly_pairs],
            assembly_type=[pair[1] for pair in sample_assembly_pairs]
        ),
        expand(
            "{sample}/{assembly_type}/checkv",
            zip,
            sample=[pair[0] for pair in sample_assembly_pairs],
            assembly_type=[pair[1] for pair in sample_assembly_pairs]
        ),
        expand(
            "{sample}/{assembly_type}/neordrp/output.tsv",
            zip,
            sample=[pair[0] for pair in sample_assembly_pairs],
            assembly_type=[pair[1] for pair in sample_assembly_pairs]
        )
