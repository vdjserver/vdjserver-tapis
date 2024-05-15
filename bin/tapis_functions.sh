#
# Tapis V3 functions

# VDJServer Analysis Portal
# VDJServer Tapis applications
# https://vdjserver.org
#
# Copyright (C) 2023 The University of Texas Southwestern Medical Center
# Author: Scott Christley
# Date: Aug 6, 2023
#
# source tapis_functions.sh
#

# bring in common settings
if [[ "x${VDJSERVER_TAPIS_BIN}" == "x" ]]; then
    VDJSERVER_TAPIS_BIN=/vdjserver-tapis/bin
fi
source ${VDJSERVER_TAPIS_BIN}/tapis_common.sh

# ----------------------------------------------------------------------------
# tokens and credentials
#
function tapis_get_token() {
    if [ $# -ne 1 ];
    then
        echo "usage: tapis_get_token username"
        return 1
    fi

    read -p "password: " -s password
    JWT=$(python3 ${tapis_script_dir}/get_token.py $1 ${password})
    if [ $? -ne 0 ]; then
        unset JWT
        return 1
    else
        export JWT
        return 0
    fi
}
typeset -fx tapis_get_token
