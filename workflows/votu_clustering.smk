import os
import pandas as pd

tmp_dir = os.environ.get("tmp_dir", config["tmp_dir"])

votu_config = config.get("votu_clustering", {})
backend = votu_config.get("backend", "vclust")
allowed_backends = {"vclust", "best_practice"}
if backend not in allowed_backends:
    raise ValueError(
        f"Unsupported votu_clustering.backend={backend!r}; expected one of {sorted(allowed_backends)}"
    )

output_dir = os.path.join(config["output_dir"], votu_config.get("output_subdir", "votu_clustering"))
consolidated_dir = votu_config.get(
    "input_dir", os.path.join(config["output_dir"], "consolidated_seqs")
)

samples = pd.read_table(config["data_table"], sep="\t", comment="#", dtype={"sample_alias": str})
sample_ids = sorted(samples["sample_alias"].dropna().astype(str).unique())
sample_fastas = {
    sample: os.path.join(consolidated_dir, sample, "all_pred.viral_seqs.fasta")
    for sample in sample_ids
}

workdir:
    output_dir

include:
    "../rules/votu_clustering/common.smk"

if backend == "vclust":
    include:
        "../rules/votu_clustering/vclust.smk"
else:
    include:
        "../rules/votu_clustering/best_practice.smk"

rule all:
    input:
        "concatenated.fasta",
        "clusters.tsv",
        "cluster_summary.tsv",
        "vOTUs.fasta"

