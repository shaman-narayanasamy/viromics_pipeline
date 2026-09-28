rule genomad:
    input:
        fasta=lambda wildcards: samples.at[(wildcards.sample, wildcards.assembly_type), "fasta"]
    output:
        fasta = "{sample}/{assembly_type}/genomad/final.contigs_summary/final.contigs_virus.fna"
    params:
        db = config["genomad"]["db"],
        threads = config["genomad"]["threads"],
        outdir = directory("{sample}/{assembly_type}/genomad")
    conda: "../../envs/genomad_env.yml"
    benchmark: "{sample}/{assembly_type}/genomad/benchmarks/{sample}_{assembly_type}.txt"
    log: "{sample}/{assembly_type}/genomad/logs/{sample}_{assembly_type}.txt"
    shell:
        """
        echo "Processing: sample={wildcards.sample}, assembly_type={wildcards.assembly_type}"

        assembly_type="{wildcards.assembly_type}"
        
        echo "Processing: Standardising input filename (for genomad)"
        ln -sf {input.fasta} {wildcards.sample}/{wildcards.assembly_type}/final.contigs.fa
        
        genomad end-to-end -t {params.threads} --cleanup --restart \
        {wildcards.sample}/{wildcards.assembly_type}/final.contigs.fa \
        {params.outdir} {params.db}
        

        echo "Cleaning up: Removing temporary files"
        rm -rf {wildcards.sample}/{wildcards.assembly_type}/final.contigs.fa \

        echo "Resolved input: {input.fasta}"
        """
