rule hmmsearch_neordrp:
    input:
        fasta = "{sample}/{assembly_type}/cenotetaker3/output/output_virus_AA.faa"
    output: 
        table = "{sample}/{assembly_type}/neordrp/output.tsv"
    params:
        db_path = config["hmmsearch_neordrp"]["db_path"],
        threads = config["hmmsearch_neordrp"]["threads"]
    benchmark: "{sample}/{assembly_type}/neordrp/benchmarks/neordrp.txt"
    shell:
        """
        conda run -p /scratch/users/snarayanasamy/phage_uv_treatment/conda/1ded1bacb8bb81e76b4ff0dd62561999_ hmmsearch {params.db_path} {input.fasta} > {output.table}
        """
