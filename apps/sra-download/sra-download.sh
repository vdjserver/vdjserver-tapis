# VDJServer Tapis wrapper script
# Stampede2

# Configuration settings

# Agave input

# Agave parameters
SRA_run_id="${SRA_run_id}"
project_id="${project_id}"
api_version="${api_version}"
split_flag=${split_flag}

# Agave info
AGAVE_JOB_ID=${AGAVE_JOB_ID}
AGAVE_JOB_NAME=${AGAVE_JOB_NAME}
AGAVE_LOG_NAME=${AGAVE_JOB_NAME}-${AGAVE_JOB_ID}

# ----------------------------------------------------------------------------
#tar zxf binaries.tgz  # Unpack local executables
#chmod +x fastq2fasta.py splitfasta.pl

# load modules
module load python3/3.7.0
module load launcher/3.4
#module load sratoolkit/2.8.2
export PATH=$WORK/sratoolkit/sratoolkit.2.11.1-centos_linux64/bin:$PATH

PYTHON=python3

#export PATH="$PWD/bin:${PATH}"
#export PYTHONPATH=$PWD/lib/python3.7/site-packages:$PYTHONPATH

# ----------------------------------------------------------------------------
# Launcher to use multicores on node
export LAUNCHER_WORKDIR=$PWD
export LAUNCHER_LOW_PPN=4
export LAUNCHER_MID_PPN=12
export LAUNCHER_MAX_PPN=20
export LAUNCHER_PPN=1
export LAUNCHER_JOB_FILE=joblist
export LAUNCHER_SCHED=interleaved
export LAUNCHER_BIND=0

# bring in common functions

# Start
printf "START at $(date)\n\n"

$PYTHON ./get_sra_info.py ${SRA_RUN_ID} >sra.out 2>sra.err

SCRIPT=upload_file_to_project.py
if [[ "${api_version}" == "v2" ]]; then
    SCRIPT=v2_upload_file_to_project.py
fi

link=$(cat sra.out)
if [ -n "$link" ]; then
    # for some reason, downloads are really slow on the compute node
    # so do the wget manually for now
    wget $link
    file=${link##*/}
    mv $file $SCRATCH/ncbi/public/sra

    ARGS="--gzip"
    if [[ $split_flag -eq 1 ]]; then
        ARGS="$ARGS --split-files"
    fi
    fastq-dump $ARGS ${SRA_RUN_ID}

    if [ -n "${project_id}" ]; then
        data_dir=$PWD
        cd $WORK/../common/vdjserver-repair
        if [[ $split_flag -eq 1 ]]; then
            python3 $SCRIPT -p ${project_id} --file $data_dir/${SRA_RUN_ID}_1.fastq.gz
            python3 $SCRIPT -p ${project_id} --file $data_dir/${SRA_RUN_ID}_2.fastq.gz
            if [ -f $data_dir/${SRA_RUN_ID}_3.fastq.gz ]; then
                python3 $SCRIPT -p ${project_id} --file $data_dir/${SRA_RUN_ID}_3.fastq.gz
            fi
        else
            python3 $SCRIPT -p ${project_id} --file $data_dir/${SRA_RUN_ID}.fastq.gz
        fi
    fi
fi

# End
printf "DONE at $(date)\n\n"
