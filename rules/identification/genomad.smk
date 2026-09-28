rule genomad:
    input:
#        fasta=lambda wildcards: samples.loc[
#            (wildcards.sample, wildcards.assembly_type), "fasta"
#        ] if (wildcards.sample, wildcards.assembly_type) in samples.index else None
        #fasta = lambda wildcards: samples.at.get((wildcards.sample, wildcards.assembly_type), None)
        fasta=lambda wildcards: samples.at[(wildcards.sample, wildcards.assembly_type), "fasta"]
#        fasta=lambda wildcards: (
#            print(f"Trying to access: sample={wildcards.sample} assembly_type={wildcards.assembly_type}"),
#            samples.at[(wildcards.sample, wildcards.assembly_type), "fasta"]
#        )[-1]
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
#        """
#        echo "Processing: sample={wildcards.sample}, assembly_type={wildcards.assembly_type}"
#        assembly_type="{wildcards.assembly_type}"
#        
#        if [[ $assembly_type == "coassembly" ]]; then
#        ln -s {input.fasta} {wildcards.sample}/{wildcards.assembly_type}/final.contigs.fa
#        
#        genomad end-to-end -t {params.threads} --cleanup --restart \
#        {wildcards.sample}/{wildcards.assembly_type}/final.contigs.fa \
#        {params.outdir} {params.db}
#        
#        rm -r {wildcards.sample}/{wildcards.assembly_type}/final.contigs.fa \
#        
#        else
#        
#        genomad end-to-end -t {params.threads} --cleanup --restart \
#        {input.fasta} {params.outdir} {params.db}
#        
#        fi
#
#        echo "Resolved input: {input.fasta}"
#        """
