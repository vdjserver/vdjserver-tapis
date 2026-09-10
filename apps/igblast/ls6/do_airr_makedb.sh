#
# Run Change-O's MakeDB on IgBlast output and generate AIRR TSV
# Uses singularity image
#

seqType="$3"
organism="$4"

fileBasename="${2%.*}" # file.fastq -> file

MakeDb.py igblast -s "$1" -i "$2" -r "$VDJ_DB_ROOT/${organism}/ReferenceDirectorySet/${seqType}_VDJ.fna" --extended --failed

if [ -f "${fileBasename}_db-pass.tsv" ]; then
    mv "${fileBasename}_db-pass.tsv" "${fileBasename}.makedb.airr.tsv"
else
    echo "ERROR: MakeDb did not produce ${fileBasename}_db-pass.tsv"
    exit 1
fi

if [ -f "${fileBasename}_db-fail.tsv" ]; then
    mv "${fileBasename}_db-fail.tsv" "${fileBasename}.fail-makedb.airr.tsv"
fi