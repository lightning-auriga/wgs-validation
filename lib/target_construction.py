import os

import pandas as pd
from snakemake.io import AnnotatedString, Namedlist
from snakemake.remote.FTP import RemoteProvider as FTPRemoteProvider
from snakemake.remote.HTTP import RemoteProvider as HTTPRemoteProvider
from snakemake.remote.S3 import RemoteProvider as S3RemoteProvider

FTP = FTPRemoteProvider()
S3 = S3RemoteProvider()
HTTP = HTTPRemoteProvider()


def wrap_remote_file(fn: str) -> str | AnnotatedString:
    """
    Given a filename, potentially wrap it in a remote handler
    """
    mapped_name = fn
    if mapped_name.startswith("s3://"):
        return S3.remote(mapped_name)
    elif mapped_name.startswith("https://") or mapped_name.startswith("http://"):
        return HTTP.remote(mapped_name)
    elif mapped_name.startswith("ftp://"):
        return FTP.remote(mapped_name)
    return mapped_name


def get_happy_output_files(
    config: dict,
    manifest_comparisons: pd.DataFrame,
) -> list:
    """
    Use configuration and manifest data to generate the set of comparisons
    required for a full complement of hap.py runs.

    Comparisons are specified as rows in manifest_comparisons. The entries in those
    two columns *should* exist as indices in the corresponding other manifests.
    """
    res = []
    for reference, experimental in zip(
        manifest_comparisons["reference_dataset"], manifest_comparisons["experimental_dataset"]
    ):
        res.append("results/happy/{}/{}/results.vcf.gz".format(experimental, reference))
    return res


def construct_targets(config: dict, manifest: pd.DataFrame) -> list:
    """
    Use configuration and manifest data to generate the set of comparisons
    required for a full pipeline run.
    """
    res = []
    targets = zip(manifest["experimental_dataset"], manifest["reference_datasets"])
    for target in targets:
        reference_datasets = target[1].split(",")
        for reference_dataset in reference_datasets:
            res.append("results/vcfeval/{}/{}/results.vcf.gz".format(target[0], reference_dataset))
    return res


def map_reference_file(wildcards: Namedlist, manifest: pd.DataFrame) -> str | AnnotatedString:
    """
    Probe the prefix of a filename to determine which sort of
    remote provider (if any) should be used to acquire a local copy.

    Reference vcfs are pulled from the relevant column in the manifest.
    """
    ## The intention for this function was to distinguish between S3 file paths and others,
    ## and return wrapped objects related to the remote provider service when appropriate.
    ## There have been periodic issues with the remote provider interface, but it seems
    ## to be working, somewhat inefficiently but very conveniently, for the time being.
    mapped_name = manifest.loc[wildcards.reference, "vcf"]
    return wrap_remote_file(mapped_name)


def map_experimental_file(wildcards: Namedlist, manifest: pd.DataFrame) -> str | AnnotatedString:
    """
    Probe the prefix of a filename to determine which sort of
    remote provider (if any) should be used to acquire a local copy.

    Experimental vcfs are pulled from the relevant column in the manifest.
    """
    ## The intention for this function was to distinguish between S3 file paths and others,
    ## and return wrapped objects related to the remote provider service when appropriate.
    ## There have been periodic issues with the remote provider interface, but it seems
    ## to be working, somewhat inefficiently but very conveniently, for the time being.
    mapped_name = manifest.loc[wildcards.experimental, "vcf"]
    return wrap_remote_file(mapped_name)


def get_happy_region_by_index(wildcards, config, checkpoints):
    """
    Given the index of a stratification region in its original annotation file,
    return the relative path to the bedfile.
    """
    regions = []
    with open(
        checkpoints.get_stratification_bedfiles.get(genome_build=config["genome-build"]).output[0],
        "r",
    ) as f:
        regions = f.readlines()
    return "results/regions/{}/{}".format(
        config["genome-build"], regions[int(wildcards.region_set)].split("\t")[1].rstrip("\n\r")
    )


def get_happy_region_set_indices(wildcards, config, checkpoints):
    """
    Given the checkpoint output of stratification region download, get a list of indices that can
    be used as intermediate names for the region files during DAG construction.
    """
    regions = []
    with open(
        checkpoints.get_stratification_bedfiles.get(genome_build=config["genome-build"]).output[0],
        "r",
    ) as f:
        regions = f.readlines()
    return [x for x in range(len(regions))]
