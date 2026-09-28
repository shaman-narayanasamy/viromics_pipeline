ruleorder: get_non_redundant > concatenate_non_redundant

wildcard_constraints:
    sample = "[^/]+",
    assembly_type = "[^/]+"

rule get_non_redundant:
    input:
        fasta=lambda wildcards: samples.at[(wildcards.sample, wildcards.assembly_type), "fasta"],
        valid_inputs = lambda wildcards: [
            path for path in get_input_files(wildcards.sample, wildcards.assembly_type).values() if os.path.exists(path)
        ]
    output:
        temp("{sample}/{assembly_type}/all_pred.viral_seqs.fasta")
    conda: "../../envs/pullseq_env.yml"
    shell:
        """
        if [[ -z "{input.valid_inputs}" ]]; then
            echo "Error: no viral prediction FASTAs found for {wildcards.sample}/{wildcards.assembly_type}" >&2
            echo "Run the identification workflow first, or check output_dir in the config." >&2
            exit 2
        fi

        {{
            for file in {input.valid_inputs}; do
                grep "^>" $file | sed -e 's/>//' -e 's/|.*$//' -e 's/[[:space:]].*$//g'
            done
        }} | sort | uniq | \
        pullseq -i {input.fasta} -N | \
        sed -e 's/>/>{wildcards.sample}_{wildcards.assembly_type}_/g' > {output}
        """

sample_final_inputs = {
    sample: [
        output_mapping[(sample, assembly)]
        for assembly in samples.loc[sample].index.get_level_values("assembly_type")
        if (sample, assembly) in output_mapping  # Ensure key exists
    ]
    for sample in samples.index.get_level_values("sample_alias").unique()
}

rule concatenate_non_redundant:
    input:
        lambda wildcards: [
            output_mapping[(wildcards.sample.split("/")[0], assembly)]
            for assembly in samples.loc[wildcards.sample.split("/")[0]].index.get_level_values("assembly_type")
        ] if wildcards.sample.split("/")[0] in samples.index.get_level_values("sample_alias") else []

    output:
        "{sample}/all_pred.viral_seqs.fasta"
    shell:
        """
        cat {input} > {output}
        """
