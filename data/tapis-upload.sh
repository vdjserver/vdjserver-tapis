#
# Upload test data for tapis apps
#
# VDJServer Analysis Portal
# VDJServer Tapis applications
# https://vdjserver.org
#
# Author: Scott Christley
# Copyright (C) 2024 The University of Texas Southwestern Medical Center
# Date: May 22, 2024
#

fileList=($(ls test/*))
count=0
while [ "x${fileList[count]}" != "x" ]
do
    file=${fileList[count]}
    fileBasename="${file##*/}" # foo/bar/file -> file
    tapis_files_upload /apps/data/test/$fileBasename $file
    count=$(( $count + 1 ))
done