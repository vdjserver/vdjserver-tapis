#
TOOL=igblast
SYSTEM=ls6
VER=1.20

# Copy all of the object files to the bundle directory
# and create a binaries.tgz
#
# For example:
# cd bundle

# tar zcvf binaries.tgz bin lib

# delete old working area in tapis
tapis files delete agave://data.vdjserver.org/apps/$TOOL/$VER/$SYSTEM

# create directory structure
tapis files mkdir agave://data.vdjserver.org/apps $TOOL
tapis files mkdir agave://data.vdjserver.org/apps/$TOOL $VER
tapis files mkdir agave://data.vdjserver.org/apps/$TOOL/$VER $SYSTEM
tapis files mkdir agave://data.vdjserver.org/apps/$TOOL/$VER/$SYSTEM test

# upload app assets
tapis files upload agave://data.vdjserver.org/apps/$TOOL/$VER/$SYSTEM igblast.sh
tapis files upload agave://data.vdjserver.org/apps/$TOOL/$VER/$SYSTEM igblast.json
tapis files upload agave://data.vdjserver.org/apps/$TOOL/$VER/$SYSTEM ../common/do_airr_makedb.sh
tapis files upload agave://data.vdjserver.org/apps/$TOOL/$VER/$SYSTEM ../common/do_annotations.sh
tapis files upload agave://data.vdjserver.org/apps/$TOOL/$VER/$SYSTEM ../common/do_makedb.sh
tapis files upload agave://data.vdjserver.org/apps/$TOOL/$VER/$SYSTEM ../common/do_merge.sh
tapis files upload agave://data.vdjserver.org/apps/$TOOL/$VER/$SYSTEM ../common/igblast_common.sh
tapis files upload agave://data.vdjserver.org/apps/$TOOL/$VER/$SYSTEM ../common/fastq2fasta.py
tapis files upload agave://data.vdjserver.org/apps/$TOOL/$VER/$SYSTEM ../common/splitfasta.pl
tapis files upload agave://data.vdjserver.org/apps/$TOOL/$VER/$SYSTEM ../../../../common/common_functions.sh
tapis files upload agave://data.vdjserver.org/apps/$TOOL/$VER/$SYSTEM ../../../../common/provenance_functions.sh
tapis files upload agave://data.vdjserver.org/apps/$TOOL/$VER/$SYSTEM ../../../../common/airr_metadata.py
tapis files upload agave://data.vdjserver.org/apps/$TOOL/$VER/$SYSTEM ../../../../common/process_metadata.py
tapis files upload agave://data.vdjserver.org/apps/$TOOL/$VER/$SYSTEM ../../../../common/presto_annotations.py
tapis files upload agave://data.vdjserver.org/apps/$TOOL/$VER/$SYSTEM ../../../../common/count_statistics.py
tapis files upload agave://data.vdjserver.org/apps/$TOOL/$VER/$SYSTEM ../../../../common/changeo_clones.sh
tapis files upload agave://data.vdjserver.org/apps/$TOOL/$VER/$SYSTEM ../../../../common/find_threshold.R
tapis files upload agave://data.vdjserver.org/apps/$TOOL/$VER/$SYSTEM ../../../../common/parse_changeo.py
tapis files upload agave://data.vdjserver.org/apps/$TOOL/$VER/$SYSTEM ../../../../common/repcalc_create_config.py
tapis files upload agave://data.vdjserver.org/apps/$TOOL/$VER/$SYSTEM ../../../../common/create_airr_metadata.py
tapis files upload agave://data.vdjserver.org/apps/$TOOL/$VER/$SYSTEM ../../../../common/assign_repertoire_id.py
tapis files upload agave://data.vdjserver.org/apps/$TOOL/$VER/$SYSTEM ../../../../common/repcalc_clones.sh
tapis files upload agave://data.vdjserver.org/apps/$TOOL/$VER/$SYSTEM ../../../../common/tcr_clone_template.json
tapis files upload agave://data.vdjserver.org/apps/$TOOL/$VER/$SYSTEM ../../../../common/clone_report.py
tapis files list agave://data.vdjserver.org/apps/$TOOL/$VER/$SYSTEM

# upload test assets
tapis files upload agave://data.vdjserver.org/apps/$TOOL/$VER/$SYSTEM/test test/test.sh
tapis files upload agave://data.vdjserver.org/apps/$TOOL/$VER/$SYSTEM/test test/test-cli.json
tapis files list agave://data.vdjserver.org/apps/$TOOL/$VER/$SYSTEM/test

