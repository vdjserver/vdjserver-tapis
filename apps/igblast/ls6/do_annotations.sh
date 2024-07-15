#
# Process presto annotations
#

fileOutname=$1

python3 presto_annotations.py ${fileOutname}.igblast.airr.new.tsv ${fileOutname}.igblast.airr.tsv
