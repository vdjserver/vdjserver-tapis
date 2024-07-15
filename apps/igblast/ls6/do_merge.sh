#
# Merge AIRR TSV files
#

fileBasename=$1
fileOutname=$2

# IgBlast AIRR TSV
airr-tools merge -a ${fileBasename}_p*.igblast.airr.tsv -o ${fileOutname}.igblast.airr.new.tsv

# MakeDb AIRR TSV
airr-tools merge -a ${fileBasename}_p*.igblast.makedb.airr.tsv -o ${fileOutname}.igblast.makedb.airr.tsv

# MakeDb Failed AIRR TSV
airr-tools merge -a ${fileBasename}_p*.igblast.fail-makedb.airr.tsv -o ${fileOutname}.igblast.fail-makedb.airr.tsv
