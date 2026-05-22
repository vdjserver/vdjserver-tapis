#
# Tapis app entry script
#
# VDJServer Analysis Portal
# VDJServer Tapis applications
# https://vdjserver.org
#
# Copyright (C) 2022-2026 The University of Texas Southwestern Medical Center
# Author: Scott Christley
# Date: Mar 25, 2026
#

# ----------------------------------------------------------------------------
# modules
module load python3/3.9.7
module load launcher/3.10
module load tacc-apptainer

PYTHON="apptainer exec -e ${ak_graph_image} python3"
#AIRR_TOOLS="apptainer exec -e ${ak_graph_image} airr-tools"

# bring in common functions
source ./tilde_common.sh

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

# TODO: what to do about germline
#setup_germline "${germline_db}"

initProvenance
print_parameters
print_versions
run_tilde_workflow
compress_and_archive

# End
printf "DONE at $(date)\n\n"

