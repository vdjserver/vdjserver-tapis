#
# Process presto annotations
#

fileOutname=$1

python3 presto_annotations.py ${fileOutname}.igblast.airr.new.tsv ${fileOutname}.igblast.airr.tsv

# if no output file, assume no presto annotations, so just copy
if [[ ! -f "${fileOutname}.igblast.airr.tsv" ]]; then
    cp ${fileOutname}.igblast.airr.new.tsv ${fileOutname}.igblast.airr.tsv
fi
