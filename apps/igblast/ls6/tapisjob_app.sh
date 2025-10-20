#
# Tapis app entry script
#
# VDJServer Analysis Portal
# VDJServer Tapis applications
# https://vdjserver.org
#
# Copyright (C) 2022-2024 The University of Texas Southwestern Medical Center
# Author: Scott Christley
# Date: Feb 28, 2022
#

# ----------------------------------------------------------------------------
# modules
module load python3/3.9.7
module load launcher/3.10
module load tacc-apptainer

# IGBLASTN_EXE="apptainer exec ${igblast_image} igblastn -num_threads 1"
IGBLASTN_EXE="apptainer exec ${repcalc_image} igblastn -num_threads 1"
PYTHON="apptainer exec -e ${repcalc_image} python3"
AIRR_TOOLS="apptainer exec -e ${repcalc_image} airr-tools"

# bring in common functions
source ./igblast_common.sh

# ----------------------------------------------------------------------------
# Launcher to use multicores on node
export LAUNCHER_WORKDIR=$PWD
export LAUNCHER_LOW_PPN=1
export LAUNCHER_MID_PPN=12
export LAUNCHER_MAX_PPN=20
export LAUNCHER_PPN=1
export LAUNCHER_JOB_FILE=joblist
export LAUNCHER_SCHED=interleaved
export LAUNCHER_BIND=0

# Start
printf "START at $(date)\n\n"

# TODO: how to tell Tapis that the job failed?
export JOB_ERROR=0

setup_germline "db.2019.01.23"
initProvenance
#gather_secondary_inputs
print_parameters
print_versions
run_igblast_workflow
run_assign_clones
compress_and_archive

# End
printf "DONE at $(date)\n\n"

