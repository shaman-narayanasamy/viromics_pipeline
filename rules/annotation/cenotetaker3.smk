rule cenotetaker3:
    input:
        fasta=lambda wildcards: samples.at[(wildcards.sample, wildcards.assembly_type), "fasta"]
    output:
        outdir = directory("{sample}/{assembly_type}/cenotetaker3"),
        output = "{sample}/{assembly_type}/cenotetaker3/output/output_virus_AA.faa"
    params:
        db = config["cenotetaker3"]["db_path"],
        threads = config["cenotetaker3"]["threads"],
        workdir = os.getcwd()
    benchmark: "{sample}/{assembly_type}/cenotetaker3/benchmarks/cenotetaker3.txt"
    log: "{sample}/{assembly_type}/cenotetaker3/logs/cenotetaker3.log"
    shell:
       """
       conda run -p /scratch/users/snarayanasamy/phage_uv_treatment/conda/viromics_db_envs/cenotetaker3 cenotetaker3 -c {input.fasta} -r output \
       --working_directory {wildcards.sample}/{wildcards.assembly_type}/cenotetaker3 \
       -p True -t {params.threads} --virus_domain_db virion rdrp dnarep \
       --caller adaptive \
       --cenote-dbs {params.db} \
       --taxdb hallmark
       """
