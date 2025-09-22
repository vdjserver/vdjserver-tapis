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

# use our production binaries
ALIGN_SETS_PY="apptainer exec ${singularity_image} AlignSets.py"
ASSEMBLE_PAIRS_PY="apptainer exec ${singularity_image} AssemblePairs.py"
BUILD_CONSENSUS_PY="apptainer exec ${singularity_image} BuildConsensus.py"
CLUSTER_SETS_PY="apptainer exec ${singularity_image} ClusterSets.py"
COLLAPSE_SEQ_PY="apptainer exec ${singularity_image} CollapseSeq.py"
CONVERT_HEADERS_PY="apptainer exec ${singularity_image} ConvertHeaders.py"
FILTER_SEQ_PY="apptainer exec ${singularity_image} FilterSeq.py"
MASK_PRIMERS_PY="apptainer exec ${singularity_image} MaskPrimers.py"
PAIR_SEQ_PY="apptainer exec ${singularity_image} PairSeq.py"
PARSE_HEADERS_PY="apptainer exec ${singularity_image} ParseHeaders.py"
PARSE_LOG_PY="apptainer exec ${singularity_image} ParseLog.py"
SPLIT_SEQ_PY="apptainer exec ${singularity_image} SplitSeq.py"
VDJ_PIPE="apptainer exec -e ${vdj_pipe_image} vdj_pipe"
PYTHON="apptainer exec -e ${singularity_image} python3"
PYTHON3="apptainer exec -e ${singularity_image} python3"

# bring in common functions
source ./presto_common.sh

# ----------------------------------------------------------------------------
# Launcher to use multicores on node
export LAUNCHER_WORKDIR=$PWD
export LAUNCHER_LOW_PPN=4
export LAUNCHER_MID_PPN=8
export LAUNCHER_MAX_PPN=12
export LAUNCHER_PPN=1
export LAUNCHER_JOB_FILE=joblist
export LAUNCHER_SCHED=interleaved
export LAUNCHER_BIND=0

# Start
printf "START at $(date)\n\n"

print_parameters
print_versions
run_presto_workflow

# End
printf "DONE at $(date)\n\n"

