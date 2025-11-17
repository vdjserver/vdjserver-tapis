#
# provenance functions

# VDJServer Analysis Portal
# VDJServer Tapis applications
# https://vdjserver.org
#
# Copyright (C) 2023 The University of Texas Southwestern Medical Center
# Author: Scott Christley
# Date: Jul 8, 2023
#
# source provenance_functions.sh
#

# ----------------------------------------------------------------------------
# File archiving functions

function addArchiveFile() {
    ARCHIVE_FILE_LIST="${ARCHIVE_FILE_LIST} $1"
}

function gzipFile() {
    GZIP_FILE_LIST="${GZIP_FILE_LIST} $1"
}


# ----------------------------------------------------------------------------
# PROVENANCE relationships

function wasGeneratedBy(){
    $PYTHON ./prov_metadata.py --wasGeneratedBy "$1" "$2" "$3" "$4" "$5" provenance_output.json
    addArchiveFile "$1"
}
function wasDerivedFrom(){
    #Check if the file exists first
    $PYTHON ./prov_metadata.py --wasDerivedFrom "$1" "$2" "$3" "$4" "$5" provenance_output.json
    addArchiveFile "$1"
}

function addCalculation(){
    $PYTHON ./prov_metadata.py --addCalculation "$1" "$2" provenance_output.json
}

function used(){
    $PYTHON ./prov_metadata.py --used "$1" "$2" provenance_output.json
}

function wasAssociatedWith(){
    $PYTHON ./prov_metadata.py --wasAssociatedWith "$1" "$2" provenance_output.json
}

function wasAttributedTo(){
    $PYTHON ./prov_metadata.py --wasAttributedTo "$1" "$2" provenance_output.json
}

# ----------------------------------------------------------------------------
# AIRR metadata
function addProcessingStage() {
    $PYTHON ./airr_metadata.py --processing_stage $1 study_metadata.airr.json
}

# ----------------------------------------------------------------------------
# OLD OBSOLETE
# ----------------------------------------------------------------------------
function initProvenance() {
    cp ${analysis_provenance} provenance_output.json

    # collect all output files
    mkdir ${_tapisJobUUID}
    ARCHIVE_FILE_LIST=""
    GZIP_FILE_LIST=""
}

# ----------------------------------------------------------------------------
# Process workflow metadata - OLD OBSOLETE
function initProcessMetadata() {
    $PYTHON ./process_metadata.py --init $APP_NAME ${_tapisJobUUID} process_metadata.json

    # collect all output files
    mkdir ${_tapisJobUUID}
    ARCHIVE_FILE_LIST=""
    GZIP_FILE_LIST=""
}

function addLogFile() {
    $PYTHON ./process_metadata.py --entry log "$1" "$2" "$3" "$4" "$5" "$6" "$7" process_metadata.json
    ARCHIVE_FILE_LIST="${ARCHIVE_FILE_LIST} $4"
}

function addConfigFile() {
    $PYTHON ./process_metadata.py --entry config "$1" "$2" "$3" "$4" "$5" "$6" "$7" process_metadata.json
}

function addStatisticsFile() {
    $PYTHON ./process_metadata.py --entry statistics "$1" "$2" "$3" "$4" "$5" "$6" "$7" process_metadata.json
    ARCHIVE_FILE_LIST="${ARCHIVE_FILE_LIST} $4"
}

function addOutputFile() {
    $PYTHON ./process_metadata.py --entry output "$1" "$2" "$3" "$4" "$5" "$6" "$7" process_metadata.json
    # add file to list to be archived
    ARCHIVE_FILE_LIST="${ARCHIVE_FILE_LIST} $4"
}

function initEntryFile() {
    echo "entryType,group,name,key,value,description,fileType,derivedFrom" > $1
}

function addEntryToFile() {
    echo "$2,$3,$4,$5,$6,$7,$8,$9" >> $1
    if [ "$2" == "output" ]; then
        ARCHIVE_FILE_LIST="${ARCHIVE_FILE_LIST} $6"
    fi
}

function addFileEntries() {
    $PYTHON ./process_metadata.py --fileEntries "$1" process_metadata.json
}

function includeFile() {
    $PYTHON ./process_metadata.py process_metadata.json --include $1
}

function addGroup() {
    $PYTHON ./process_metadata.py --group "$1" "$2" process_metadata.json
}

# function addCalculation() {
#     $PYTHON ./process_metadata.py --calc $1 process_metadata.json
# }

