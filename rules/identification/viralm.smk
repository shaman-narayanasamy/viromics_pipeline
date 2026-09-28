rule viralm:
    input:
        fasta=lambda wildcards: samples.at[(wildcards.sample, wildcards.assembly_type), "fasta"]
    output:
        result = "{sample}/{assembly_type}/viralm/result_{sample}.csv",
        fasta = "{sample}/{assembly_type}/viralm/virus_{sample}.fasta",
    conda: "../../envs/viralm_env.yml"
    params:
        script = config["viralm"]["script"],
        db = config["viralm"]["db"],
        length = config["viralm"]["length"],
        threshold = config["viralm"]["threshold"],
        threads = config["viralm"]["threads"]
    shell:
       """
       ulimit -n 65535
       export VIRALM_CACHE_PARENT="${{SLURM_TMPDIR:-/tmp}}"
       python {params.script} \
       --input {input.fasta} --out {wildcards.sample}/{wildcards.assembly_type}/viralm \
       --threads {params.threads} \
       -d {params.db} --len {params.length} \
       --threshold {params.threshold} \
       -f -n {wildcards.sample}
       """
