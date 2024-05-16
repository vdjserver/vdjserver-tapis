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
