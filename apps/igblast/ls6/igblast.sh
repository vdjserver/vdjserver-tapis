# VDJServer igBlast Agave wrapper script
# Lonestar6

# Configuration settings

# automatic parallelization of large files
READS_PER_FILE=10000

# Agave input
export igblast_image="${igblast_image}"
export repcalc_image="${repcalc_image}"
ProjectDirectory="${ProjectDirectory}"
JobFiles="${JobFiles}"
query="${query}"
# Agave parameters
SecondaryInputsFlag=${SecondaryInputsFlag}
QueryFilesMetadata="${QueryFilesMetadata}"
species="${species}"
strain="${strain}"
ig_seqtype="${ig_seqtype}"
domain_system="${domain_system}"

if [ "$ig_seqtype" == "TCR" ]; then ClonalTool="repcalc"; fi  
if [ "$ig_seqtype" == "Ig" ]; then ClonalTool="changeo"; fi  

# Agave info
AGAVE_JOB_ID=${AGAVE_JOB_ID}
AGAVE_JOB_NAME=${AGAVE_JOB_NAME}
AGAVE_LOG_NAME=${AGAVE_JOB_NAME}-${AGAVE_JOB_ID}

# ----------------------------------------------------------------------------
#tar zxf binaries.tgz  # Unpack local executables
chmod +x fastq2fasta.py splitfasta.pl

# load modules
#module load python3/3.9.7
#module load launcher/3.10
#module load tacc-singularity
# same version it was compiled with
#module load gcc/11.2.0

IGBLASTN_EXE="singularity exec ${igblast_image} igblastn -num_threads 1"
PYTHON="singularity exec -e ${repcalc_image} python3"
AIRR_TOOLS="singularity exec -e ${repcalc_image} airr-tools"

#export PATH="$PWD/bin:${PATH}"
#export PYTHONPATH=$PWD/lib/python3.9/site-packages:$PYTHONPATH

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

# bring in common functions
source igblast_common.sh

# Start
printf "START at $(date)\n\n"

start_provenance
gather_secondary_inputs
print_parameters
print_versions
run_igblast_workflow
run_assign_clones
compress_and_archive

# End
printf "DONE at $(date)\n\n"

# remove executables and libraries before archiving
#rm -rf bin lib include launcher
