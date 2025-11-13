#
# Tapis app entry script
#
# VDJServer Analysis Portal
# VDJServer Tapis applications
# https://vdjserver.org
#
# Author: Scott Christley
# Copyright (C) 2022-2024 The University of Texas Southwestern Medical Center
# Date: Feb 28, 2022
#

# ----------------------------------------------------------------------------
# modules
module load python3/3.9.7
module load launcher/3.10
module load tacc-apptainer

VDJ_PIPE="apptainer exec -e ${vdj_pipe_image} vdj_pipe"
PYTHON="apptainer exec -e ${repcalc_image} python3"
BIO_PYTHON="apptainer exec -e ${repcalc_image} python3"

# bring in common functions
source ./vdjpipe_common.sh

# ----------------------------------------------------------------------------
# Launcher to use multicores on node
export LAUNCHER_WORKDIR=$PWD
export LAUNCHER_LOW_PPN=4
export LAUNCHER_MID_PPN=12
export LAUNCHER_MAX_PPN=32
export LAUNCHER_PPN=1
export LAUNCHER_JOB_FILE=joblist
export LAUNCHER_SCHED=interleaved
export LAUNCHER_BIND=0

# Start
printf "START at $(date)\n\n"

# TODO: how to tell Tapis that the job failed?
export JOB_ERROR=0

print_parameters
print_versions
run_vdjpipe_workflow

# End
printf "DONE at $(date)\n\n"

