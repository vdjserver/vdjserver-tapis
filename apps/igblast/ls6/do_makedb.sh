#
# Environment setup and run Change-O's MakeDB tool
#
# Because Change-O uses python3 while VDJML requires python2,
# the two don't play together well, so this script sets up
# the python3 environment in a separate script and calls
# Change-O's MakeDB tool.
#

module purge
module load TACC
module unload python2
export PYTHONPATH=
module load python3
export PYTHONPATH=$CHANGEO_PYTHON:$PYTHONPATH

seqType=$3
organism=$4

fileBasename="${2%.*}" # file.fastq -> file

# AIRR formats standard
#MakeDb.py igblast -s $1 -i $2 -r $VDJ_DB_ROOT/${organism}/ReferenceDirectorySet/${seqType}_VDJ.fna --regions --scores --partial --format airr
#mv ${fileBasename}_db-pass.tsv ${fileBasename}.airr.tsv
# delete metadata file for now
#rm ${fileBasename}_db-pass.tsv.meta.json

# standard Change-O
MakeDb.py igblast -s $1 -i $2 -r $VDJ_DB_ROOT/${organism}/ReferenceDirectorySet/${seqType}_VDJ.fna --regions --scores --partial
mv ${fileBasename}_db-pass.tab ${fileBasename}_db-pass.tsv
