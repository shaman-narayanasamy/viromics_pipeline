rule virsorter2:
    input:
        fasta=lambda wildcards: samples.at[(wildcards.sample, wildcards.assembly_type), "fasta"]
    output:
        result = "{sample}/{assembly_type}/virsorter2/final-viral-score.tsv",
        fasta = "{sample}/{assembly_type}/virsorter2/final-viral-combined.fa"
    params:
        db = config["virsorter2"]["db"],
        threads = config["virsorter2"]["threads"],
        dramv_flag = "--prep-for-dramv" if config["virsorter2"].get("prep_for_dramv", False) else ""
    conda: "../../envs/virsorter2_env.yml"
    benchmark: "{sample}/{assembly_type}/virsorter2/benchmarks/{sample}_{assembly_type}.txt"
    log: "{sample}/{assembly_type}/virsorter2/logs/{sample}_{assembly_type}.txt"
    shell:
       """
       virsorter run -w {wildcards.sample}/{wildcards.assembly_type}/virsorter2 \
       -i {input.fasta} --include-groups "dsDNAphage,NCLDV,RNA,ssDNA,lavidaviridae" \
       -j {params.threads} -d {params.db} {params.dramv_flag}
       """

rule get_virsorter2_viral_seqs:
    """
    This rule corrects the fasta headers of the virsorter2 final output.
    """
    input:
        fasta = "{sample}/{assembly_type}/virsorter2/final-viral-combined.fa"
    output:
        fasta = "{sample}/{assembly_type}/virsorter2/final-viral-combined_fixed.fa"
    conda: "../../envs/seqkit_env.yml"
    benchmark: "{sample}/{assembly_type}/get_virsorter2_viral_seqs/benchmarks/{sample}_{assembly_type}.txt"
    log: "{sample}/{assembly_type}/get_virsorter2_viral_seqs/logs/{sample}_{assembly_type}.txt"
    shell:
       """
       sed -E 's/[|][|].*//' {input.fasta} | seqkit fx2tab | seqkit tab2fx > {output.fasta}
       """
