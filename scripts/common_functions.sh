#
# common shell functions

# VDJServer Analysis Portal
# VDJServer Tapis applications
# https://vdjserver.org
#
# Copyright (C) 2021-2024 The University of Texas Southwestern Medical Center
# Author: Scott Christley
# Date: Apr 20, 2021
#
# source common_functions.sh
#

# uncompress file, resultant filename put in file variable
# ----------------------------------------------------------------------------
function expandfile () {
    fileBasename="${1%.*}" # file.txt.gz -> file.txt
    fileExtension="${1##*.}" # file.txt.gz -> gz
    filePath="${fileBasename%/*}" # path/file.txt -> path OR file.txt -> file.txt

    if [ ! -f $1 ]; then
        echo "Could not find input file $1" 1>&2
        exit 1
    fi

    if [ "$fileExtension" == "gz" ]; then
        gunzip $1
        export file=$fileBasename
        # move file to current dir if in subdir
        if [ "$filePath" != "$fileBasename" ]; then
            mv $fileBasename .
            file="${fileBasename##*/}" # foo/bar/file -> file
        fi
    elif [ "$fileExtension" == "bz2" ]; then
        bunzip2 $1
        export file=$fileBasename
    elif [ "$fileExtension" == "zip" ]; then
        unzip -o $1
        export file=$fileBasename
    else
        export file=$1
    fi
}

# setup local germline db
# ----------------------------------------------------------------------------
function setup_germline () {
    export VDJ_DB_VERSION=$1
    echo "Setting up germline database: ${VDJ_DB_VERSION}"
    tar zxf ${VDJ_DB_VERSION}.tgz

    # IgBlast germline database and extra files
    export IGDATA="./$VDJ_DB_VERSION"
    export VDJ_DB_ROOT="$IGDATA/germline/"

    local germline_species=$2
    local germline_locus=$3

    if [[ "$VDJ_DB_VERSION" == "db.2019.01.23" ]]; then
        # old germline
        if [[ "$species" == "NCBITAXON:9606" ]]; then
            germline_species="human"
        else
            germline_species="mouse"
        fi
    else
        # new germlines
        germline_species="${germline_species//:/_}"
        germline_species="${germline_species^^}"
    fi

    # TODO: handle mouse strains
    export germline_db_file="$VDJ_DB_ROOT/$germline_species/vdjserver_germline.airr.json"
    export germline_fasta="$VDJ_DB_ROOT/$germline_species/ReferenceDirectorySet/${germline_locus}_VDJ.fna"
}

