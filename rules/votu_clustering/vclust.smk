VCLUST_CONFIG = config.get("votu_clustering", {}).get("vclust", {})
VOTU_THRESHOLDS = config.get("votu_clustering", {}).get("thresholds", {})


rule vclust_prefilter:
    input:
        "concatenated.fasta"
    output:
        "vclust/fltr.txt"
    threads:
        int(VCLUST_CONFIG.get("threads", 48))
    params:
        min_ident = VCLUST_CONFIG.get(
            "min_ident", VOTU_THRESHOLDS.get("ani", VCLUST_CONFIG.get("min_ani", 0.95))
        ),
        batch_size = VCLUST_CONFIG.get("batch_size", 0),
        kmers_fraction = VCLUST_CONFIG.get("kmers_fraction", 1.0),
        max_seqs = VCLUST_CONFIG.get("max_seqs", 0)
    conda:
        "../../envs/vclust_env.yml"
    benchmark:
        "vclust/benchmarks/prefilter.txt"
    log:
        "vclust/logs/prefilter.log"
    shell:
        """
        mkdir -p vclust/benchmarks vclust/logs
        vclust prefilter \
          -i {input} \
          -o {output} \
          --min-ident {params.min_ident} \
          --batch-size {params.batch_size} \
          --kmers-fraction {params.kmers_fraction} \
          --max-seqs {params.max_seqs} \
          -t {threads} > {log} 2>&1
        """


rule vclust_align:
    input:
        fasta = "concatenated.fasta",
        filter = "vclust/fltr.txt"
    output:
        ani = "vclust/ani.tsv",
        ids = "vclust/ani.ids.tsv"
    threads:
        int(VCLUST_CONFIG.get("threads", 48))
    params:
        outfmt = VCLUST_CONFIG.get("outfmt", "lite"),
        min_ani = VCLUST_CONFIG.get("min_ani", VOTU_THRESHOLDS.get("ani", 0.95)),
        min_qcov = VCLUST_CONFIG.get(
            "min_qcov", VOTU_THRESHOLDS.get("aligned_fraction", VCLUST_CONFIG.get("min_af", 0.85))
        )
    conda:
        "../../envs/vclust_env.yml"
    benchmark:
        "vclust/benchmarks/align.txt"
    log:
        "vclust/logs/align.log"
    shell:
        """
        mkdir -p vclust/benchmarks vclust/logs
        vclust align \
          -i {input.fasta} \
          -o {output.ani} \
          --filter {input.filter} \
          --outfmt {params.outfmt} \
          --out-ani {params.min_ani} \
          --out-qcov {params.min_qcov} \
          -t {threads} > {log} 2>&1
        test -s {output.ids}
        """


rule vclust_cluster_raw:
    input:
        ani = "vclust/ani.tsv",
        ids = "vclust/ani.ids.tsv"
    output:
        raw = "vclust/clusters.raw.tsv"
    params:
        algorithm = VCLUST_CONFIG.get("algorithm", "leiden"),
        min_ani = VCLUST_CONFIG.get("min_ani", VOTU_THRESHOLDS.get("ani", 0.95)),
        min_qcov = VCLUST_CONFIG.get(
            "min_qcov", VOTU_THRESHOLDS.get("aligned_fraction", VCLUST_CONFIG.get("min_af", 0.85))
        )
    conda:
        "../../envs/vclust_env.yml"
    benchmark:
        "vclust/benchmarks/cluster.txt"
    log:
        "vclust/logs/cluster.log"
    shell:
        """
        mkdir -p vclust/benchmarks vclust/logs
        vclust cluster \
          -i {input.ani} \
          -o {output.raw} \
          --ids {input.ids} \
          --algorithm {params.algorithm} \
          --metric ani \
          --ani {params.min_ani} \
          --qcov {params.min_qcov} \
          --out-repr > {log} 2>&1
        """


rule normalize_vclust_clusters:
    input:
        raw = "vclust/clusters.raw.tsv"
    output:
        clusters = "clusters.tsv",
        summary = "cluster_summary.tsv"
    conda:
        "../../envs/anicalc_env.yml"
    shell:
        """
        python {workflow.basedir}/../scripts/normalize_votu_clusters.py \
          --format vclust \
          --clusters {input.raw} \
          --output {output.clusters} \
          --summary {output.summary}
        """

