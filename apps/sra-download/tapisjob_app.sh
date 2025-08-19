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

docker run -v $PWD:/work ncbi/sra-tools:3.2.1 fasterq-dump "${SRA_run_id}" $split_option --outdir /work
# Compress and remove .fastq files
if [ "${split_flag}" -eq 1 ]; then
    echo "Compressing and cleaning up paired-end FASTQ files..."
    gzip -f "${SRA_run_id}_1.fastq" && rm -f "${SRA_run_id}_1.fastq"
    gzip -f "${SRA_run_id}_2.fastq" && rm -f "${SRA_run_id}_2.fastq"
else
    echo "Compressing and cleaning up single-end FASTQ file..."
    gzip -f "${SRA_run_id}.fastq" && rm -f "${SRA_run_id}.fastq"
fi

printf "DONE at $(date)\n\n"

# $PYTHON ./get_sra_info.py ${SRA_run_id} >sra.out 2>sra.err

# SCRIPT=v2_upload_file_to_project.py

# link=$(cat sra.out)
# if [ -n "$link" ]; then
#     # for some reason, downloads are really slow on the compute node
#     # so do the wget manually for now
#     wget $link
#     file=${link##*/}
#     #mv $file $SCRATCH/ncbi/public/sra

#     ARGS="--gzip"
#     if [[ $split_flag -eq 1 ]]; then
#         ARGS="$ARGS --split-files"
#     fi
#     fastq-dump $ARGS ${SRA_run_id}

#     if [ -n "${project_id}" ]; then
#         data_dir=$PWD
#         cd $WORK/../common/vdjserver-repair
#         if [[ $split_flag -eq 1 ]]; then
#             python3 $SCRIPT -p ${project_id} --file $data_dir/${SRA_run_id}_1.fastq.gz
#             python3 $SCRIPT -p ${project_id} --file $data_dir/${SRA_run_id}_2.fastq.gz
#             if [ -f $data_dir/${SRA_run_id}_3.fastq.gz ]; then
#                 python3 $SCRIPT -p ${project_id} --file $data_dir/${SRA_run_id}_3.fastq.gz
#             fi
#         else
#             python3 $SCRIPT -p ${project_id} --file $data_dir/${SRA_run_id}.fastq.gz
#         fi
#     fi
# fi

# # End
# printf "DONE at $(date)\n\n"

