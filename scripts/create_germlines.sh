#
# Create Germlines

# VDJServer Analysis Portal
# VDJServer Tapis applications
# https://vdjserver.org
#
# Part of the iReceptor+ platform
#
# Author: Scott Christley
# Copyright (C) 2021 The University of Texas Southwestern Medical Center
# Date: Jun 4, 2021
#
# This script should be called inside of a singularity container by a parent script
# It is designed to operate on a single file
#

# input file
file=$1
# output file prefix
out_prefix=$2
# germline sequences
vdj_db=$3
#if [[ "x$vdj_db" == "x" ]] ; then
#    vdj_db=${WORK}'/../common/igblast-db/db.2019.01.23/germline/'${organism}'/ReferenceDirectorySet/'${seq_type}'_VDJ.fna'
#fi

fileName=${out_prefix}.airr_germ-pass.tsv
failName=${out_prefix}.airr_germ-fail.tsv

# germline db
#organism=human
#seq_type=IG

# create germlines
CreateGermlines.py -d ${file} -r $vdj_db -g dmask --failed | tee ${out_prefix}.germ.log
newPass="${out_prefix}.germ.airr.tsv"
newFail="${out_prefix}.germ-fail.airr.tsv"
mv $fileName $newPass
if [ -e "${failName}" ]; then
    mv $failName $newFail
fi
summaryName="${out_prefix}.germ.json"
python3 ./parse_changeo.py ${out_prefix}.germ.log $summaryName

#noArchive ${out_prefix}.germ.log
