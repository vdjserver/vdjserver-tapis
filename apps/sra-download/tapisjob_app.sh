#
# Tapis app entry script
#
# VDJServer Analysis Portal
# VDJServer Tapis applications
# https://vdjserver.org
#
# Author: Scott Christley & Tanzira Najnin
# Copyright (C) 2026 The University of Texas Southwestern Medical Center
#

# ----------------------------------------------------------------------------
# modules

# Start
printf "START at $(date)\n\n"

echo "Application parameters:"
echo SRA_run_ids="${SRA_run_ids}"
echo project_id="${project_id}"
echo split_flag="${split_flag}"
echo spots="${spots}"
echo vdj_default_host="${vdj_default_host}"

if [ "${split_flag}" -eq 1 ]; then
    split_option="--split-files --include-technical"
else
    split_option=""
fi

source ${HOME}/sra-download/bin/activate
source ${HOME}/.ssh/sra-download.env


dest_folder="/projects/${project_id}/files/"
for SRA_run_id in $SRA_run_ids; do
    echo "Processing ${SRA_run_id}..."

    docker run -v /vdjZ:/work --user vdj:G-803419 vdjserver/sra-tools:3.2.1 fasterq-dump "${SRA_run_id}" $split_option -t /work${dest_folder} --outdir /work${dest_folder}
    # Checking for fasterq-dump error
    if [ $? -ne 0 ]; then
        echo "ERROR: fasterq-dump failed for ${SRA_run_id}. Skipping."
        continue
    fi

    # Compress and attach FASTQ files
    if [ "${split_flag}" -eq 1 ]; then
        echo "Checking paired-end FASTQ files..."

        # Check that all expected files exist before compressing
        for i in ${spots}; do
            f="/vdjZ/${dest_folder}${SRA_run_id}_${i}.fastq"
            if [ ! -f "$f" ]; then
                echo "ERROR: Expected file not found: $f. Skipping."
                continue 2
            fi
        done

        echo "Compressing and cleaning up paired-end FASTQ files..."
        for i in ${spots}; do
            f="/vdjZ/${dest_folder}${SRA_run_id}_${i}.fastq"
            gzip -f "$f"

            file="${SRA_run_id}_${i}.fastq.gz"
            vdjserver-tools project file-attach "${project_id}" "${file}" --file-type 2
        done
        
    else
        echo "Compressing and cleaning up single-end FASTQ file..."
        f="/vdjZ/${dest_folder}${SRA_run_id}.fastq"

        if [ ! -f "$f" ]; then
            echo "ERROR: Expected single-end file not found for ${SRA_run_id}. Skipping."
            continue
        fi

        gzip -f "$f"
        file="${SRA_run_id}.fastq.gz"
        vdjserver-tools project file-attach "${project_id}" "${file}" --file-type 2
    fi

    echo "Done for ${SRA_run_id}"
done
printf "All DONE at $(date)\n\n"

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
#     }