BEST_PRACTICE_CONFIG = config.get("votu_clustering", {}).get("best_practice", {})
BEST_PRACTICE_SPLITS = int(BEST_PRACTICE_CONFIG.get("split", 250))


rule make_blast_db:
    input:
        concatenated_fasta = "concatenated.fasta"
    output:
        donefile = touch("best_practice/makeblastdb.done")
    params:
        db_prefix = "best_practice/concatenated_seqs_db"
    threads:
        int(BEST_PRACTICE_CONFIG.get("makeblastdb_threads", 1))
    resources:
        mem_mb = int(BEST_PRACTICE_CONFIG.get("makeblastdb_mem_mb", 120000)),
        runtime = int(BEST_PRACTICE_CONFIG.get("makeblastdb_runtime", 7200))
    conda:
        "../../envs/blast_env.yml"
    benchmark:
        "best_practice/benchmarks/make_blast_db.txt"
    shell:
        """
        mkdir -p best_practice/benchmarks
        makeblastdb -in {input.concatenated_fasta} -dbtype nucl -out {params.db_prefix}
        """


rule split_fasta_for_blast:
    input:
        concatenated_fasta = "concatenated.fasta"
    output:
        temp(expand(
            "best_practice/chunks/concatenated.part_{i}.fasta",
            i = range(1, BEST_PRACTICE_SPLITS + 1)
        ))
    params:
        splits = BEST_PRACTICE_SPLITS
    threads:
        int(BEST_PRACTICE_CONFIG.get("split_threads", 24))
    resources:
        mem_mb = int(BEST_PRACTICE_CONFIG.get("split_mem_mb", 100000)),
        runtime = int(BEST_PRACTICE_CONFIG.get("split_runtime", 7200))
    conda:
        "../../envs/seqkit_env.yml"
    benchmark:
        "best_practice/benchmarks/split_fasta.txt"
    shell:
        """
        mkdir -p best_practice/chunks best_practice/benchmarks
        seqkit split {input.concatenated_fasta} --by-part {params.splits} \
          --out-dir best_practice/chunks --force -j {threads}

        for file in best_practice/chunks/concatenated.part_*.fasta; do
            num=$(basename "$file" | sed -E 's/.*part_0*([0-9]+)\\.fasta/\\1/')
            new_file="best_practice/chunks/concatenated.part_${{num}}.fasta"
            if [[ "$file" != "$new_file" ]]; then
                mv "$file" "$new_file"
            fi
        done
        """


rule blast_chunks:
    input:
        donefile = "best_practice/makeblastdb.done",
        chunk = "best_practice/chunks/concatenated.part_{chunk}.fasta"
    output:
        temp("best_practice/results/{chunk}.blast")
    threads:
        int(BEST_PRACTICE_CONFIG.get("blast_threads", 48))
    params:
        db_prefix = "best_practice/concatenated_seqs_db"
    resources:
        mem_mb = int(BEST_PRACTICE_CONFIG.get("blast_mem_mb", 120000)),
        runtime = int(BEST_PRACTICE_CONFIG.get("blast_runtime", 7200))
    conda:
        "../../envs/blast_env.yml"
    benchmark:
        "best_practice/benchmarks/blast_chunks/{chunk}.txt"
    shell:
        """
        mkdir -p best_practice/results best_practice/benchmarks/blast_chunks
        blastn -query {input.chunk} -db {params.db_prefix} -task 'blastn' \
          -outfmt '6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore qlen slen' \
          -num_threads {threads} > {output}
        """


rule combine_blast_results:
    input:
        expand("best_practice/results/{chunk}.blast", chunk=range(1, BEST_PRACTICE_SPLITS + 1))
    output:
        "best_practice/final_blast.tsv"
    benchmark:
        "best_practice/benchmarks/combine_results.txt"
    shell:
        """
        mkdir -p best_practice/benchmarks
        cat {input} > {output}
        sed -i '1i qseqid\\tsseqid\\tpident\\tlength\\tmismatch\\tgapopen\\tqstart\\tqend\\tsstart\\tsend\\tevalue\\tbitscore\\tqlen\\tslen' {output}
        """


rule calculate_best_practice_ani:
    input:
        blast = "best_practice/final_blast.tsv"
    output:
        ani = "best_practice/ani.tsv"
    resources:
        mem_mb = int(BEST_PRACTICE_CONFIG.get("ani_mem_mb", 64000)),
        runtime = int(BEST_PRACTICE_CONFIG.get("ani_runtime", 7200))
    conda:
        "../../envs/anicalc_env.yml"
    benchmark:
        "best_practice/benchmarks/calculate_ani.txt"
    shell:
        """
        sed '1d' {input.blast} | \
          python {workflow.basedir}/../scripts/anicalc.py -i /dev/stdin -o {output.ani}
        """


rule cluster_best_practice_ani:
    input:
        concatenated_fasta = "concatenated.fasta",
        ani = "best_practice/ani.tsv"
    output:
        raw = "best_practice/clusters.raw.tsv"
    params:
        min_ani = BEST_PRACTICE_CONFIG.get("min_ani", 95),
        min_qcov = BEST_PRACTICE_CONFIG.get("min_qcov", 0),
        min_tcov = BEST_PRACTICE_CONFIG.get("min_tcov", 85),
        min_length = BEST_PRACTICE_CONFIG.get("min_length", 1)
    resources:
        mem_mb = int(BEST_PRACTICE_CONFIG.get("cluster_mem_mb", 64000)),
        runtime = int(BEST_PRACTICE_CONFIG.get("cluster_runtime", 7200))
    conda:
        "../../envs/anicalc_env.yml"
    benchmark:
        "best_practice/benchmarks/cluster_ani.txt"
    shell:
        """
        python {workflow.basedir}/../scripts/aniclust.py \
          --fna {input.concatenated_fasta} \
          --ani {input.ani} \
          --out {output.raw} \
          --min_ani {params.min_ani} \
          --min_tcov {params.min_tcov} \
          --min_qcov {params.min_qcov} \
          --min_length {params.min_length}
        """


rule normalize_best_practice_clusters:
    input:
        raw = "best_practice/clusters.raw.tsv"
    output:
        clusters = "clusters.tsv",
        summary = "cluster_summary.tsv"
    conda:
        "../../envs/anicalc_env.yml"
    shell:
        """
        python {workflow.basedir}/../scripts/normalize_votu_clusters.py \
          --format best_practice \
          --clusters {input.raw} \
          --output {output.clusters} \
          --summary {output.summary}
        """

