#
# Tapis app entry script
#
# VDJServer Analysis Portal
# VDJServer Tapis applications
# https://vdjserver.org
#
# Author: Scott Christley
# Copyright (C) 2022 The University of Texas Southwestern Medical Center
# Date: Feb 28, 2022
#

# ----------------------------------------------------------------------------
# modules
module load python3/3.9.7
module load launcher/3.10
module load tacc-apptainer

PYTHON=python3

# bring in common functions
source ./tcrmatch_common.sh

# ----------------------------------------------------------------------------
# Launcher to use multicores on node
export LAUNCHER_WORKDIR=$PWD
export LAUNCHER_LOW_PPN=1
export LAUNCHER_MID_PPN=8
export LAUNCHER_MAX_PPN=25
export LAUNCHER_PPN=1
export LAUNCHER_JOB_FILE=joblist
export LAUNCHER_SCHED=interleaved

# Start
printf "START at $(date)\n\n"

# TODO: how to tell Tapis that the job failed?
export JOB_ERROR=0

print_parameters
print_versions
run_tcrmatch_workflow

# End
printf "DONE at $(date)\n\n"

