rule checkv:
    input:
        fasta=lambda wildcards: samples.at[(wildcards.sample, wildcards.assembly_type), "fasta"]
    output:
        outdir = directory("{sample}/{assembly_type}/checkv")
    params:
        threads = config["checkv"]["threads"],
        db_path = config["checkv"]["db_path"]
    benchmark: "{sample}/{assembly_type}/checkv/benchmarks/checkv.txt"
    log: "{sample}/{assembly_type}/checkv/logs/checkv.log"
    shell:
        """
        conda run -p /scratch/users/snarayanasamy/phage_uv_treatment/conda/viromics_db_envs/checkv checkv end_to_end {input.fasta} {output.outdir} -d {params.db_path} \
        -t {params.threads} --remove_tmp --restart
        """
