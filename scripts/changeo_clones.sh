#
# ChangeO clone assignment for B cells

# VDJServer Analysis Portal
# VDJServer Tapis applications
# https://vdjserver.org
#
# Part of the iReceptor+ platform
#
# Copyright (C) 2021 The University of Texas Southwestern Medical Center
# Author: Scott Christley
# Date: Apr 20, 2021
#
# This script should be called inside of a singularity container by a parent script
# It is designed to operate on a single file
#
# TODO: this script should be runnable in parallel using launcher, there are filename conflicts
# preventing this currently.
#

source common_functions.sh

# input file
file=$1
# output file prefix
out_prefix=$2
# nproc
nproc=$3
if [[ "x$nproc" == "x" ]] ; then
    nproc=1
fi

# Assuming airr.tsv extension
fileBasename="${file%.*}" # file.airr.tsv -> file.airr
fileBasename="${fileBasename%.*}" # file.airr -> file

# filter output
parseName="${fileBasename}.airr_parse-select.tsv"
filteredFile="${out_prefix}.productive.airr.tsv"

# clonal assignment on only the productive rearrangements
ParseDb.py select -d ${file} -f productive -u T | tee ${out_prefix}.productive.log
mv $parseName $filteredFile
summaryName="${out_prefix}.productive.airr.json"
python3 parse_changeo.py ${out_prefix}.productive.log $summaryName

# find the threshold that DefineClones needs
rm -f ${out_prefix}.threshold.dat
(time -p Rscript find_threshold.R -d $filteredFile -o ${out_prefix}.threshold.dat) 2> ${out_prefix}.timing.dat
threshold="0.16"
if [ -f ${out_prefix}.threshold.dat ]; then
    threshold=$(cat ${out_prefix}.threshold.dat)
    rm -f ${out_prefix}.threshold.dat
fi
if [[ "$threshold" == "NA" ]]; then
    threshold="0.16"
fi

# allele clone output
fileName="${out_prefix}.productive.airr_clone-pass.tsv"
failName="${out_prefix}.productive.airr_clone-fail.tsv"
acloneName="${out_prefix}.allele.clone.airr.tsv"
acloneFail="${out_prefix}.allele.clone-fail.airr.tsv"

# allele mode
echo DefineClones.py -d $filteredFile --mode allele --act set --model ham --norm len --dist $threshold --failed --nproc ${nproc}
DefineClones.py -d $filteredFile --mode allele --act set --model ham --norm len --dist $threshold --failed --nproc ${nproc} | tee ${out_prefix}.allele.clone.log
mv $fileName $acloneName
if [ -f $failName ]; then
    mv $failName $acloneFail
fi
summaryName="${out_prefix}.summary.allele.clone.airr.json"
python3 parse_changeo.py ${out_prefix}.allele.clone.log $summaryName

# gene clone output
fileName="${out_prefix}.productive.airr_clone-pass.tsv"
failName="${out_prefix}.productive.airr_clone-fail.tsv"
gcloneName="${out_prefix}.gene.clone.airr.tsv"
gcloneFail="${out_prefix}.gene.clone-fail.airr.tsv"

# gene mode
echo DefineClones.py -d $filteredFile --mode gene --act set --model ham --norm len --dist $threshold --failed --nproc ${nproc}
DefineClones.py -d $filteredFile --mode gene --act set --model ham --norm len --dist $threshold --failed --nproc ${nproc} | tee ${out_prefix}.gene.clone.log
mv $fileName $gcloneName
if [ -f $failName ]; then
    mv $failName $gcloneFail
fi
summaryName="${out_prefix}.summary.gene.clone.airr.json"
python3 parse_changeo.py ${out_prefix}.gene.clone.log $summaryName
