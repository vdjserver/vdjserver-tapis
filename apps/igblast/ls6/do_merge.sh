#
# Merge AIRR TSV files
#

fileBasename=$1
fileOutname=$2

# AIRR tools is too slow, so we use faster method that assumes the headers are the same for all files

# IgBlast AIRR TSV
#airr-tools merge -a ${fileBasename}_p*.igblast.airr.tsv -o ${fileOutname}.igblast.airr.new.tsv
awk 'NR==1 || FNR>1' ${fileBasename}_p*.igblast.airr.tsv > ${fileOutname}.igblast.airr.new.tsv

# MakeDb AIRR TSV
#airr-tools merge -a ${fileBasename}_p*.igblast.makedb.airr.tsv -o ${fileOutname}.igblast.makedb.airr.tsv
awk 'NR==1 || FNR>1' ${fileBasename}_p*.igblast.makedb.airr.tsv > ${fileOutname}.igblast.makedb.airr.tsv

# MakeDb Failed AIRR TSV
#airr-tools merge -a ${fileBasename}_p*.igblast.fail-makedb.airr.tsv -o ${fileOutname}.igblast.fail-makedb.airr.tsv
awk 'NR==1 || FNR>1' ${fileBasename}_p*.igblast.fail-makedb.airr.tsv > ${fileOutname}.igblast.fail-makedb.airr.tsv
