#
# Tapis app entry script
#
# VDJServer Analysis Portal
# VDJServer Tapis applications
# https://vdjserver.org
#
# Copyright (C) 2022-2026 The University of Texas Southwestern Medical Center
# Author: Scott Christley
# Date: Jun 4, 2026
#

# ----------------------------------------------------------------------------
# modules
module load python3/3.9.7
module load launcher/3.10
module load tacc-apptainer

## Change these reference data and directory names accordingly
export CELLRANGER_VERSION=10.0.0
export HUMAN_REFDATA=cellranger/refdata-gex-GRCh38-2024-A
export HUMAN_VDJ_REFDATA=cellranger/refdata-cellranger-vdj-GRCh38-alts-ensembl-7.1.0
export MOUSE_REFDATA=cellranger/refdata-gex-GRCm39-2024-A
export MOUSE_VDJ_REFDATA=cellranger/refdata-cellranger-vdj-GRCm38-alts-ensembl-7.0.0


export PYTHON=python3
PYTHON="apptainer exec -e ${cellranger_image} python3"

CELLRANGER_EXE="apptainer exec -e ${cellranger_image} cellranger"
PYTHON3_EXE=="apptainer exec -e ${repcalc_image} python3"
IGBLASTN_EXE="apptainer exec ${repcalc_image} igblastn -num_threads 1"
AIRR_TOOLS_EXE="apptainer exec -e ${repcalc_image} airr-tools"

# Max memory in GB for cellranger
export CELLRANGER_MEM=50

# bring in common functions
source ./cellranger_common.sh

#What bug?
export WORK=/work/01114/vdj/common/cellranger

mkdir cellranger
cd cellranger
#tar zxf $WORK/cellranger/cellranger-${CELLRANGER_VERSION}.tar.gz
if [[ "$species" == "human" ]]; then
    tar zxf $WORK/../common/${HUMAN_VDJ_REFDATA}.tar.gz
fi
if [[ "$species" == "mouse" ]]; then
    tar zxf $WORK/../common/${MOUSE_VDJ_REFDATA}.tar.gz
fi

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

# Start
printf "START at $(date)\n\n"

initProvenance
print_parameters
print_versions
run_cellranger_workflow
compress_and_archive

# End
printf "DONE at $(date)\n\n"

