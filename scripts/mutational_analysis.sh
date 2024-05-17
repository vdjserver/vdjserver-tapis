#
# Mutational analysis using Alakazam/Shazam

# VDJServer Analysis Portal
# VDJServer Tapis applications
# https://vdjserver.org
#
# Part of the iReceptor+ platform
#
# Copyright (C) 2021 The University of Texas Southwestern Medical Center
# Author: Scott Christley
# Date: Jun 4, 2021
#
# This script should be called inside of a singularity container by a parent script
# It is designed to operate on a single file
#

# metadata file
metadata_file=$1
# repertoire_id
repertoire_id=$2
# germline sequences
germline_fasta=$3
# input file
file=$4
# output prefix
processing_stage=$5

out_prefix=${repertoire_id}.${processing_stage}

# create germlines
bash ./create_germlines.sh ${file} ${out_prefix} ${germline_fasta}
germFilename="${out_prefix}.germ.airr.tsv"

# mutations
Rscript ./mutational_analysis.R -d $germFilename -o ${out_prefix}

# rename output
mut_file=${out_prefix}.mutations.orig.airr.tsv
mv ${out_prefix}.mutations.airr.tsv $mut_file 

# generate config
python3 repcalc_create_config.py --init mutational_template.json ${metadata_file} mutational_config.${out_prefix}.json
python3 repcalc_create_config.py --rearrangementFile $mut_file --repertoireID $repertoire_id --stage ${processing_stage} mutational_config.${out_prefix}.json

# run it
repcalc mutational_config.${out_prefix}.json
#mv ${out_prefix}.mutations.airr.tsv ${mut_file}
