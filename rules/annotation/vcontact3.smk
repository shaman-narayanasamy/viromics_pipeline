rule vcontact3:
    input:
        fasta=lambda wildcards: samples.at[(wildcards.sample, wildcards.assembly_type), "fasta"]
    output:
        outdir = directory("{sample}/{assembly_type}/vcontact3")
    params:
        threads = config["vcontact3"]["threads"],
        db_path = config["vcontact3"]["db_path"],
        db_version = config["vcontact3"]["db_version"]
    benchmark: "{sample}/{assembly_type}/vcontact3/benchmark/vcontact3.txt"
    log: "{sample}/{assembly_type}/vcontact3/benchmark/vcontact3.log"
    shell:  
       """
       export PATH=/mnt/aiongpfs/users/snarayanasamy/miniforge3/envs/vcontact3/bin:$PATH
       /mnt/aiongpfs/users/snarayanasamy/miniforge3/envs/vcontact3/bin/vcontact3 run --nucleotide {input.fasta} --output {output.outdir} \
       --threads {params.threads} --db-path {params.db_path} \
       --pyrodigal-gv --virus-only --db-version {params.db_version} \
       --force-overwrite
       """
