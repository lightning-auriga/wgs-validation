def get_bedfile_from_name(wildcards, checkpoints, prefix):
    """
    pull data from checkpoint output
    """
    res = []
    with open(
        checkpoints.happy_create_stratification_subset.get(
            genome_build=reference_build, stratification_set=wildcards.stratification_set
        ).output[0],
        "r",
    ) as f:
        for line in f.readlines():
            line_data = line.split("\t")
            if line_data[0] == wildcards.subset_name:
                return "{}/{}".format(prefix, line_data[1].rstrip())
    raise ValueError(
        'cannot find stratification region with name "{}"'.format(wildcards.subset_name)
    )


rule sv_svdb_within_dataset:
    """
    Run svdb merging markers in a single dataset
    """
    input:
        vcf="results/{dataset_type}/{dataset_name}.vcf.gz",
        stratification_bed=lambda wildcards: get_bedfile_from_name(
            wildcards,
            checkpoints,
            "results/stratification-sets/{}/subsets_for_happy/{{subset_name}}".format(
                reference_build
            ),
        ),
        region_bed="results/confident-regions/{region}.bed",
    output:
        temp(
            "results/{dataset_type,[^/]+}/{region,[^/]+}/{subset_name}/{dataset_name,[^/]+}.vcf.gz"
        ),
    conda:
        "../envs/svdb.yaml"
    shell:
        "bedtools intersect -a {input.stratification_bed} -b {input.region_bed} | "
        "bedtools intersect -a {input.vcf} -b stdin -wa -f 1 | "
        "svdb --merge --vcf {input.vcf} | bgzip -c > {output}"


rule sv_svdb_across_datasets:
    """
    Run svdb combining experimental and reference data
    """
    input:
        experimental="results/experimentals/{region}/{setname}/{experimental}.vcf.gz",
        reference="results/references/{region}/{setname}/{reference}.vcf.gz",
    output:
        "results/sv/{experimental,[^/]+}/{reference,[^/]+}/{region,[^/]+}/{setname}.post-svdb.vcf.gz",
    conda:
        "../envs/svdb.yaml"
    threads: 1
    resources:
        mem_mb="4000",
        qname="small",
    shell:
        "svdb --merge --vcf {input} | bgzip -c > {output}"


rule sv_summarize_variant_sources:
    """
    Given a vcf that's been passed through svdb, use bcftools to extract
    summary data
    """
    input:
        "{prefix}.vcf.gz",
    output:
        temp("{prefix}.vcf.gz.pwv_comparison"),
    conda:
        "../envs/bcftools.yaml"
    threads: 1
    resources:
        mem_mb="2000",
        qname="small",
    shell:
        "bcftools query -f '%CHROM\\t%POS\\t%ID\\t%REF\\t%ALT\\t%QUAL\\t%FILTER\\t%INFO/SVTYPE\\t%INFO/svdb_origin\\n' {input} > {output}"


def find_datasets_in_subset(wildcards, checkpoints, prefix):
    """
    pull data from checkpoint output
    """
    res = []
    with open(
        checkpoints.happy_create_stratification_subset.get(
            genome_build=reference_build, stratification_set=wildcards.stratification_set
        ).output[0],
        "r",
    ) as f:
        for line in f.readlines():
            res.append(
                "results/sv/{}/{}/{}/{}/{}.pwv_comparison".format(
                    wildcards.experimental,
                    wildcards.reference,
                    wildcards.region,
                    wildcards.stratification_set,
                    line.split("\t")[0],
                )
            ),
    return res


rule sv_combine_subsets:
    """
    Determine which sv comparisons need to be aggregated in an emulation of hap.py's output structure
    """
    input:
        comparisons=lambda wildcards: find_datasets_in_subset(
            wildcards,
            checkpoints,
            "results/stratification-sets/{}/subsets_for_happy/{{stratification_set}}".format(
                reference_build
            ),
        ),
    output:
        csv="results/sv/{experimental}/{reference}/{region,[^/]+}/{stratification_set,[^/]+}/results.extended.csv",
    conda:
        "../envs/r.yaml"
    threads: 1
    resources:
        mem_mb="1000",
        qname="small",
    script:
        "../scripts/combine_svdb_merge_results.R"
