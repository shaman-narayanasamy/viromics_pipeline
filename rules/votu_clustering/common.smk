rule concatenate_votu_inputs:
    input:
        lambda wildcards: list(sample_fastas.values())
    output:
        "concatenated.fasta"
    shell:
        """
        cat {input} > {output}
        """


rule extract_votus:
    input:
        fasta = "concatenated.fasta",
        clusters = "clusters.tsv"
    output:
        "vOTUs.fasta"
    conda:
        "../../envs/anicalc_env.yml"
    shell:
        """
        python {workflow.basedir}/../scripts/extract_votu_representatives.py \
          --fasta {input.fasta} \
          --clusters {input.clusters} \
          --output {output}
        """

