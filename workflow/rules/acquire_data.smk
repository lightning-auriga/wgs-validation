rule download_reference_data:
    """
    Using wildcards and configuration data, get reference vcf.

    This is refactored to old garbage bash style, as the snakemake FTP remote
    has serious timeout problems.
    """
    output:
        "results/references/{reference,[^/]+}.vcf.gz",
    params:
        lambda wildcards: tc.map_reference_file(wildcards, manifest_reference),
    conda:
        "../envs/awscli.yaml"
    threads: config_resources["default"]["threads"]
    resources:
        slurm_partition=rc.select_partition(
            config_resources["default"]["partition"], config_resources["partitions"]
        ),
        mem_mb=config_resources["default"]["memory"],
    shell:
        "if [[ {params} = s3://* ]] ; then "
        "aws s3 cp {params} {output} ; "
        "elif [[ {params} = ftp://* ]] || [[ {params} = https://* ]] || [[ {params} = http://* ]] ; then "
        "wget -O {output} {params} ; "
        "else cp {params} {output} ; fi"


rule merge_experimental_data:
    """
    Update support for experimental vcf input
    to support multiple input vcfs from the same
    sample.
    """
    input:
        vcf=lambda wildcards: expand(
            "results/experimentals/{{experimental}}/{index}.vcf.gz",
            index=[
                x for x in range(len(tc.map_experimental_file(wildcards, manifest_experiment)))
            ],
        ),
        tbi=lambda wildcards: expand(
            "results/experimentals/{{experimental}}/{index}.vcf.gz.tbi",
            index=[
                x for x in range(len(tc.map_experimental_file(wildcards, manifest_experiment)))
            ],
        ),
    output:
        "results/experimentals/{experimental,[^/]+}.vcf.gz",
    conda:
        "../envs/bcftools.yaml"
    threads: config_resources["bcftools"]["threads"]
    resources:
        slurm_partition=rc.select_partition(
            config_resources["bcftools"]["partition"], config_resources["partitions"]
        ),
        mem_mb=config_resources["bcftools"]["memory"],
    shell:
        "bcftools concat --allow-overlaps -D -O u --threads {threads} {input.vcf} | "
        "bcftools sort -O z -o {output}"


rule download_experimental_data:
    """
    Get a copy of an experimental input file.
    """
    input:
        lambda wildcards: tc.map_experimental_file(wildcards, manifest_experiment)[
            int(wildcards.index)
        ],
    output:
        temp("results/experimentals/{experimental}/{index}.vcf.gz"),
    shell:
        "cp {input} {output}"
