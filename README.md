# Viromics pipeline

Snakemake workflows for viral identification, catalogue construction and
annotation from assembled contigs.

## Inputs

Supply a tab-separated table with `sample_alias`, `assembly_type` and `fasta`.
The multiomics input helper prepares this table from project metadata:

```sh
python scripts/prepare_multiomics_contig_table.py \
  --metadata /path/to/multiomics_samples.tsv \
  --multiomics-output-dir /path/to/project/output \
  --output /path/to/viromics_contigs.tsv
```

Add `--require-existing` to include only assemblies already present. Supported
sources include MEGAHIT metatranscriptomes and coassemblies, and Penguin
metagenomes and metatranscriptomes.

## Workflows

| Source | Task |
| --- | --- |
| `workflows/identification.smk` | geNomad, VirSorter2 and ViralM identification |
| `workflows/consolidate_preds.smk` | Combine viral predictions |
| `workflows/votu_clustering.smk` | Build the project-wide vOTU catalogue |
| `workflows/annotation.smk` | Viral annotation and quality assessment |

Copy `config/examples/multiomics_identification_config.yml`, set the database
and output paths, then run:

```sh
snakemake --snakefile workflows/identification.smk \
  --configfile config/my_project.yml --use-conda --cores 24 --dry-run
```

Use the same command structure with the subsequent workflow files. Viral
predictions are stored under `consolidated_seqs/{sample}/all_pred.viral_seqs.fasta`.
Catalogue outputs under `votu_clustering/` include `clusters.tsv`,
`cluster_summary.tsv` and `vOTUs.fasta`.

The clustering configuration accepts `vclust` and `best_practice`. The vclust
defaults are 0.95 nucleotide identity and 0.85 aligned fraction/query coverage.
The alternative retains the BLASTN, ANI-calculation and centroid-clustering
workflow. Annotation rules include CheckV, Cenote-Taker 3, NeoRdRp and vContact3.

## PRJEB79569 analysis

Downstream analysis: [phage_uv_ecology_analysis](https://github.com/shaman-narayanasamy/phage_uv_ecology_analysis).
Raw data: https://www.ebi.ac.uk/ena/browser/view/PRJEB79569.
Keep databases, temporary files and generated catalogues in project storage.
