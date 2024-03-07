rule sv_svdb_within_dataset:
    """
    Run svdb merging markers in a single dataset
    """
    input:
        vcf="results/{dataset_type}/{dataset_name}.vcf.gz",
        stratification_bed=lambda wildcards: tc.get_bedfile_from_name(
            wildcards,
            checkpoints,
            "results/stratification-sets/{}/subsets_for_happy/{{subset_group}}".format(
                reference_build
            ),
            reference_build,
        ),
        region_bed="results/confident-regions/{region}.bed",
    output:
        temp(
            "results/{dataset_type}/{region}/{subset_group}/{subset_name}/{dataset_name}.within-svdb.vcf.gz"
        ),
    params:
        bnd_distance=config["sv-settings"]["svdb"]["bnd-distance"],
        overlap=config["sv-settings"]["svdb"]["overlap"],
    conda:
        "../envs/svdb.yaml"
    threads: 1
    resources:
        mem_mb=8000,
        qname="small",
    shell:
        "bedtools intersect -a {input.stratification_bed} -b {input.region_bed} | "
        "bedtools intersect -a {input.vcf} -b stdin -wa -f 1 -header > {output}.tmp.vcf && "
        "svdb --merge --vcf {output}.tmp.vcf --bnd_distance {params.bnd_distance} --overlap {params.overlap} | "
        "sed 's/.tmp.vcf//g' | bgzip -c > {output} && "
        "rm {output}.tmp.vcf"


rule sv_svdb_across_datasets:
    """
    Run svdb combining experimental and reference data
    """
    input:
        experimental="results/experimentals/{region}/{setgroup}/{setname}/{experimental}.within-svdb.vcf.gz",
        reference="results/references/{region}/{setgroup}/{setname}/{reference}.within-svdb.vcf.gz",
    output:
        "results/svdb/{experimental}/{reference}/{region}/{setgroup}/{setname}.between-svdb.vcf.gz",
    params:
        bnd_distance=config["sv-settings"]["svdb"]["bnd-distance"],
        overlap=config["sv-settings"]["svdb"]["overlap"],
    conda:
        "../envs/svdb.yaml"
    threads: 1
    resources:
        mem_mb=8000,
        qname="small",
    shell:
        "svdb --merge --vcf {input} --bnd_distance {params.bnd_distance} --overlap {params.overlap} | bgzip -c > {output}"


rule sv_summarize_variant_sources:
    """
    Given a vcf that's been passed through svdb, use bcftools to extract
    summary data. It turns out that the way svdb emits tracking data creates
    problematic information that bcftools doesn't love. As such, this no longer
    selects `svdb_origin`, instead just opting to pattern match across all of INFO downstream.
    """
    input:
        "results/svdb/{experimental}/{reference}/{region}/{setgroup}/{setname}.between-svdb.vcf.gz",
    output:
        temp(
            "results/svdb/{experimental}/{reference}/{region}/{setgroup}/{setname}.between-svdb.vcf.gz.pwv_comparison"
        ),
    conda:
        "../envs/bcftools.yaml"
    threads: 1
    resources:
        mem_mb=2000,
        qname="small",
    shell:
        "bcftools query -f '%CHROM\\t%POS\\t%ID\\t%REF\\t%ALT\\t%QUAL\\t%FILTER\\t%INFO/SVTYPE\\t%INFO\\n' {input} > {output}"


rule sv_combine_subsets:
    """
    Determine which sv comparisons need to be aggregated in an emulation of hap.py's output structure
    """
    input:
        comparisons=lambda wildcards: tc.find_datasets_in_subset(
            wildcards,
            checkpoints,
            "results/stratification-sets/{}/subsets_for_happy/{{stratification_set}}".format(
                reference_build
            ),
            reference_build,
        ),
    output:
        csv="results/{toolname,svdb|truvari|svanalyzer}/{experimental}/{reference}/{region}/{stratification_set}/results.extended.csv",
    params:
        experimental="{experimental}",
        reference="{reference}",
        toolname="{toolname}",
    conda:
        "../envs/r.yaml"
    threads: 1
    resources:
        mem_mb=1000,
        qname="small",
    script:
        "../scripts/combine_sv_merge_results.R"
