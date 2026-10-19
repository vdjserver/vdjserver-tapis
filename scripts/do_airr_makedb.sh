#
# Run Change-O's MakeDB on IgBlast output and generate AIRR TSV
# Uses singularity image
#


locus="$3"
species="$4"
germline_db="$5"


if [[ "$germline_db" == "db.2019.01.23" ]]; then

    if [[ "$species" == "NCBITAXON:9606" ]]; then
        species="human"
    else
        species="mouse"
    fi
else
    species="${species//:/_}"
    species="${species^^}"

fi

fileBasename="${2%.*}" # file.fastq -> file

MakeDb.py igblast -s "$1" -i "$2" -r "$VDJ_DB_ROOT/${species}/ReferenceDirectorySet/${locus}_VDJ.fna" --extended --failed

if [ -f "${fileBasename}_db-pass.tsv" ]; then
    mv "${fileBasename}_db-pass.tsv" "${fileBasename}.makedb.airr.tsv"
else
    echo "ERROR: MakeDb did not produce ${fileBasename}_db-pass.tsv"
    exit 1
fi

if [ -f "${fileBasename}_db-fail.tsv" ]; then
    mv "${fileBasename}_db-fail.tsv" "${fileBasename}.fail-makedb.airr.tsv"
fi