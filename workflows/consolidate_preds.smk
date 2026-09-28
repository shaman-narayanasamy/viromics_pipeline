import subprocess
import pandas as pd

tmp_dir = os.environ.get("tmp_dir", config['tmp_dir'])

## Define output directory
output_dir = os.path.join(config['output_dir'], "consolidated_seqs")

import pandas as pd

# Load table
samples = pd.read_table(config["data_table"], sep="\t", comment="#", dtype={"sample_alias": str})
samples.set_index(["sample_alias", "assembly_type"], drop=False, inplace=True)

# Define function to retrieve input files
def get_input_files(sample, assembly_type):
    """Retrieve all relevant input files based on assembly type."""

    base_path = os.path.join(config["output_dir"], "identification", sample, assembly_type)

    inputs = {
        "virsorter2": f"{base_path}/virsorter2/final-viral-combined_fixed.fa",
        "genomad": f"{base_path}/genomad/final.contigs_summary/final.contigs_virus.fna",
        "viralm": f"{base_path}/viralm/virus_{sample}.fasta",
    }
    
    # Add deepmicroclass only where multiomics produces co-assembled contigs.
    if assembly_type in {"coassembly", "coassembly_megahit", "megahit_mg"}:
        inputs["deepmicroclass"] = f"{config['deepmicroclass_input']}/{sample}/DeepMicroClass/prokaryotic_viruses.fa"

    return inputs

# Precompute outputs
output_mapping = {
    (sample, assembly): f"{sample}/{assembly}/all_pred.viral_seqs.fasta"
    for sample, assembly in samples.index
}

# Sample-level concatenation (final output)
sample_final_outputs = {
    sample: f"{sample}/all_pred.viral_seqs.fasta"
    for sample in samples.index.get_level_values("sample_alias").unique()
}

workdir:
    output_dir

include:
    '../rules/identification/consolidate_preds.smk'

# Define the `all` rule
rule all:
    input:
        list(sample_final_outputs.values())
