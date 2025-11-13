#
# provenance functions

# VDJServer Analysis Portal
# VDJServer Tapis applications
# https://vdjserver.org
#
# Copyright (C) 2025 The University of Texas Southwestern Medical Center
# Author: Tanzira Najnin
# Date: Nov 12, 2025
#
# source provenance_functions.sh
#

# ----------------------------------------------------------------------------
function initProvenance() {
    # init the old process metadata
    initProcessMetadata
}

# ----------------------------------------------------------------------------
# Process workflow metadata
function initProcessMetadata() {
    $PYTHON ./process_metadata_v2.py --init $APP_NAME ${_tapisJobUUID} process_metadata.json
}

# ----------------------------------------------------------------------------
# PROVENANCE relationships

function wasGeneratedBy(){
    $PYTHON ./process_metadata_v2.py --wasGeneratedBy "$1" "$2" process_metadata.json
}
function wasDerivedFrom(){
    #Check if the file exists first
    $PYTHON ./process_metadata_v2.py --wasDerivedFrom "$1" "$2" process_metadata.json
}

function used(){
    $PYTHON ./process_metadata_v2.py --used "$1" "$2" process_metadata.json
}

function wasAssociatedWith(){
    $PYTHON ./process_metadata_v2.py --wasAssociatedWith "$1" "$2" process_metadata.json
}

function wasAttributedTo(){
    $PYTHON ./process_metadata_v2.py --wasAttributedTo "$1" "$2" process_metadata.json
}
