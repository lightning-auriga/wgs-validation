#!/usr/bin/env bash
snakemake -j50 --profile ../slurm-profile -p --rerun-incomplete --rerun-triggers mtime --use-conda --use-singularity
