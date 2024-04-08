checkpoint get_stratification_linker:
    input:
        trackers=lambda wildcards: ctf.get_ftp_tracking_files(config, "results"),
    output:
        tsv="results/stratification-sets/{genome_build}.stratification_regions.tsv",
    params:
        outdir="results/stratification-sets/{genome_build}",
        ftpsite=lambda wildcards: config["genomes"][wildcards.genome_build][
            "stratification-regions"
        ]["ftp"],
        ftpdir=lambda wildcards: config["genomes"][wildcards.genome_build][
            "stratification-regions"
        ]["dir"],
        linker_fn=lambda wildcards: config["genomes"][wildcards.genome_build][
            "stratification-regions"
        ]["all-stratifications"],
    benchmark:
        "results/performance_benchmarks/get_stratification_linker/{genome_build}/results.tsv"
    priority: 1
    threads: config_resources["default"]["threads"]
    resources:
        slurm_partition=rc.select_partition(
            config_resources["default"]["partition"], config_resources["partitions"]
        ),
        mem_mb=config_resources["default"]["memory"],
    shell:
        "mkdir -p {params.outdir} && "
        "wget -O {output.tsv} {params.ftpsite}/{params.ftpdir}/{params.linker_fn}"


rule get_stratification_file:
    input:
        lambda wildcards: HTTP.remote(
            "{}/{}/{{subdir}}/{{prefix}}.bed{{suffix}}".format(
                config["genomes"][wildcards.genome_build]["stratification-regions"]["ftp"],
                config["genomes"][wildcards.genome_build]["stratification-regions"]["dir"],
            )
        ),
    output:
        "results/stratification-sets/{genome_build}/{subdir}/{prefix}.bed{suffix}",
    shell:
        "cp {input} {output}"


rule acquire_confident_regions:
    """
    Get a confident region bedfile from somewhere
    """
    output:
        final="results/confident-regions/{region}.bed",
        tmp=temp("results/confident-regions/.{region}.bed.tmp"),
    params:
        source=lambda wildcards: config["genomes"][reference_build]["confident-regions"][
            wildcards.region
        ]["bed"],
    threads: config_resources["default"]["threads"]
    resources:
        slurm_partition=rc.select_partition(
            config_resources["default"]["partition"], config_resources["partitions"]
        ),
        mem_mb=config_resources["default"]["memory"],
    shell:
        "if [[ {params.source} = s3://* ]] ; then "
        "aws s3 cp {params.source} {output.tmp} ; "
        "elif [[ {params.source} = ftp://* ]] || [[ {params.source} = https://* ]] || [[ {params.source} = http://* ]] ; then "
        "wget -O {output.tmp} {params.source} ; "
        "else cp {params.source} {output.tmp} ; fi && "
        'if [[ "{params.source}" = *".gz" ]] ; then gunzip -c {output.tmp} > {output.final} ; else cp {output.tmp} {output.final} ; fi'


use rule acquire_confident_regions as acquire_fasta with:
    output:
        final="results/{genome}/ref.fasta",
        tmp=temp("results/{genome}/.ref.fasta.tmp"),
    params:
        source=lambda wildcards: config["genomes"][wildcards.genome]["fasta"],


rule create_fai:
    """
    From a fasta file, create an fai index
    """
    input:
        "{prefix}.fasta",
    output:
        "{prefix}.fasta.fai",
    benchmark:
        "results/performance_benchmarks/create_fai/{prefix}.fasta.fai.tsv"
    conda:
        "../envs/samtools.yaml"
    threads: config_resources["default"]["threads"]
    resources:
        slurm_partition=rc.select_partition(
            config_resources["default"]["partition"], config_resources["partitions"]
        ),
        mem_mb=config_resources["default"]["memory"],
    shell:
        "samtools faidx {input}"


rule create_sdf:
    """
    Convert a fasta to an sdf format *folder* for rtg tools' particularities
    """
    input:
        "results/{genome}/ref.fasta",
    output:
        directory("results/{genome}/ref.fasta.sdf"),
    benchmark:
        "results/performance_benchmarks/create_sdf/{genome}.tsv"
    conda:
        "../envs/vcfeval.yaml"
    threads: config_resources["rtg-vcfeval"]["threads"]
    resources:
        slurm_partition=rc.select_partition(
            config_resources["rtg-vcfeval"]["partition"], config_resources["partitions"]
        ),
    shell:
        "rtg RTG_MEM=12G format -f fasta -o {output} {input}"
