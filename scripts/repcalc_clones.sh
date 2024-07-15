#
# RepCalc clone assignment for T cells

# VDJServer Analysis Portal
# VDJServer Tapis applications
# https://vdjserver.org
#
# Part of the iReceptor+ platform
#
# Copyright (C) 2021 The University of Texas Southwestern Medical Center
# Author: Scott Christley
# Date: June 23, 2021
#
# This script should be called inside of a singularity container by a parent script
# It is designed to operate on a single file
#

source common_functions.sh

# metadata file
metadata_file=$1
# germline db
germline_db=$2
# input file
file=$3
# repertoire id
rep_id=$4
# processing stage
processing_stage=$5

out_prefix=${rep_id}.${processing_stage}

# generate config
python3 repcalc_create_config.py --init tcr_clone_template.json ${metadata_file} --germline ${germline_db} --rearrangementFile $file --stage ${processing_stage} ${out_prefix}_config.json

# run it
repcalc ${out_prefix}_config.json
