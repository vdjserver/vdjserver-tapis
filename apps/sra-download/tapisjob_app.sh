#
# Tapis app entry script
#
# VDJServer Analysis Portal
# VDJServer Tapis applications
# https://vdjserver.org
#
# Author: Scott Christley
# Copyright (C) 2025 The University of Texas Southwestern Medical Center
#

# ----------------------------------------------------------------------------
# modules

# Start
printf "START at $(date)\n\n"

echo "Application parameters:"
echo SRA_run_id="${SRA_run_id}"
echo project_id="${project_id}"
echo split_flag=${split_flag}

if [ "${split_flag}" -eq 1 ]; then
    split_option="--split-files"
else
    split_option=""
fi

source ${HOME}/sra-download/bin/activate
source ${HOME}/.ssh/sra-download.env

dest_folder="/projects/${project_id}/files/"
docker run -v /vdjZ:/work --user vdj:G-803419 vdjserver/sra-tools:3.2.1 fasterq-dump "${SRA_run_id}" $split_option -t /work${dest_folder} --outdir /work${dest_folder}

# Compress and remove .fastq files
if [ "${split_flag}" -eq 1 ]; then
    echo "Compressing and cleaning up paired-end FASTQ files..."
    gzip -f "/vdjZ/${dest_folder}${SRA_run_id}_1.fastq" 
    gzip -f "/vdjZ/${dest_folder}${SRA_run_id}_2.fastq"
    for i in 1 2; do
        file="${SRA_run_id}_${i}.fastq.gz"
        vdjserver-tools project file-attach ${project_id} ${file} --file-type 2
    done
else
    echo "Compressing and cleaning up single-end FASTQ file..."
    gzip -f "/vdjZ/${dest_folder}${SRA_run_id}.fastq" 
    file="/vdjZ/${dest_folder}${SRA_run_id}.fastq.gz"
    vdjserver-tools project file-attach ${project_id} ${file} --file-type 2
fi

printf "DONE at $(date)\n\n"

# fileTypeCodes: {
#         FILE_TYPE_UNSPECIFIED: 0,
#         FILE_TYPE_PRIMER: 1,
#         FILE_TYPE_FASTQ_READ: 2,
#         FILE_TYPE_FASTA_READ: 3,
#         FILE_TYPE_BARCODE: 4,
#         FILE_TYPE_QUALITY: 5,
#         FILE_TYPE_TSV: 6,
#         FILE_TYPE_CSV: 7,
#         FILE_TYPE_VDJML: 8,
#         FILE_TYPE_AIRR_TSV: 9,
#         FILE_TYPE_AIRR_JSON: 10,
#     },