import os
import pathlib

import pytest
from snakemake.io import AnnotatedString, Namedlist, expand
from snakemake.remote.FTP import RemoteProvider as FTPRemoteProvider
from snakemake.remote.HTTP import RemoteProvider as HTTPRemoteProvider
from snakemake.remote.S3 import RemoteProvider as S3RemoteProvider

from lib import target_construction as tc

S3 = S3RemoteProvider()
HTTP = HTTPRemoteProvider()
FTP = FTPRemoteProvider()


def test_map_reference_file_localfile():
    """
    Test that map_reference_file can successfully detect things that look
    like local files.
    """
    fn = "my.UD"
    expected = fn
    observed = tc.wrap_remote_file(fn)
    assert observed == expected


def test_map_reference_file_s3():
    """
    Test that map_reference_file can successfully detect things that look
    like they come from an s3 bucket
    """
    fn = "s3://path/to/file"
    expected = S3.remote(fn)
    observed = tc.wrap_remote_file(fn)
    assert observed == expected


def test_map_reference_file_http():
    """
    Test that map_reference_file can successfully detect things that look
    like they come from a URL over http
    """
    fn = "http://website.thing/otherthing"
    expected = HTTP.remote(fn)
    observed = tc.wrap_remote_file(fn)
    assert observed == expected


def test_map_reference_file_https():
    """
    Test that map_reference_file can successfully detect things that look
    like they come from a URL over https
    """
    fn = "https://website.thing/otherthing"
    expected = HTTP.remote(fn)
    observed = tc.wrap_remote_file(fn)
    assert observed == expected


def test_map_reference_file_ftp():
    """
    Test that map_reference_file can successfully detect things that look
    like they come from a URL over ftp
    """
    fn = "ftp://website.thing/otherthing"
    expected = FTP.remote(fn)
    observed = tc.wrap_remote_file(fn)
    assert observed == expected


def test_get_happy_output_files(wildcards_for_report, manifest_comparisons):
    """
    Test that get_happy_output_files successfully populates all post-hap.py
    merged csv files
    """
    expected = [
        "results/happy/exp1/ref1/back1/results.extended.csv",
        "results/happy/exp1/ref2/back1/results.extended.csv",
    ]
    observed = tc.get_happy_output_files(wildcards_for_report, manifest_comparisons)
    assert observed == expected


def test_construct_targets(config, manifest_comparisons):
    """
    Test that construct_targets successfully populates all final reports
    """
    expected = [
        "results/reports/control_validation_comparison-{}_vs_region-{}.html".format(x[0], x[1])
        for x in zip(
            ["comp1", "comp2", "comp3", "comp1", "comp2", "comp3"],
            ["reg3", "reg3", "reg3", "reg4", "reg4", "reg4"],
        )
    ]
    expected.sort()
    observed = tc.construct_targets(config, manifest_comparisons)
    assert observed == expected


def test_map_reference_file(wildcards_comparison, manifest_reference):
    """
    Test that map reference file can pull out a vcf by unique identifier from
    the reference dataset manifest
    """
    expected = "path/to/ref_filename.vcf.gz"
    observed = tc.map_reference_file(wildcards_comparison, manifest_reference)
    assert observed == expected


def test_map_experimental_file(wildcards_comparison, manifest_experiment):
    """
    Test that map experimental file can pull out a vcf by unique identifier from
    the experiment dataset manifest
    """
    expected = "path/to/exp_filename.vcf.gz"
    observed = tc.map_experimental_file(wildcards_comparison, manifest_experiment)
    assert observed == expected