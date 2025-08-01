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
    vdjserver-tools files upload $file /apps/data/test/$fileBasename
    count=$(( $count + 1 ))
done
