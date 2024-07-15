#
# Run Change-O's MakeDB on IgBlast output and generate AIRR TSV
# Uses singularity image
#

seqType=$3
organism=$4

fileBasename="${2%.*}" # file.fastq -> file

# AIRR formats standard
MakeDb.py igblast -s $1 -i $2 -r $VDJ_DB_ROOT/${organism}/ReferenceDirectorySet/${seqType}_VDJ.fna --extended --failed
mv ${fileBasename}_db-pass.tsv ${fileBasename}.makedb.airr.tsv
if [ -f ${fileBasename}_db-fail.tsv ]; then
    mv ${fileBasename}_db-fail.tsv ${fileBasename}.fail-makedb.airr.tsv
fi
