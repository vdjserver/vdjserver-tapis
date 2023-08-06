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
# This assumes you are in the vdjserver-tapis docker, as paths to scripts are hard-coded
export tapis_script_dir=/vdjserver-tapis/scripts
export tapis_default_host=vdjserver.tapis.io
export tapis_default_storage=data-storage.vdjserver.org

# ----------------------------------------------------------------------------
# tokens and credentials
#
function tapis_check_token() {
    if [[ -z "${JWT}" ]]; then
        echo JWT environment variable is not defined, need to run tapis_get_token?
        return 1
    else
        return 0
    fi
}
typeset -fx tapis_check_token

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

# ----------------------------------------------------------------------------
# systems
#
function tapis_systems_list() {
    tapis_check_token
    if [ $? -ne 0 ]; then
        return 1
    fi

    curl -H "X-Tapis-Token: $JWT" https://vdjserver.tapis.io/v3/systems?select=allAttributes | jq
}
typeset -fx tapis_systems_list

function tapis_systems_create() {
    if [ $# -ne 1 ];
    then
        echo "usage: tapis_systems_create json_file"
        return 1
    fi

    tapis_check_token
    if [ $? -ne 0 ]; then
        return 1
    fi

    curl -X POST -H "content-type: application/json" -H "X-Tapis-Token: $JWT" https://vdjserver.tapis.io/v3/systems -d @$1
}
typeset -fx tapis_systems_create

function tapis_systems_update() {
    if [ $# -ne 2 ];
    then
        echo "usage: tapis_systems_update system_id json_file"
        return 1
    fi

    tapis_check_token
    if [ $? -ne 0 ]; then
        return 1
    fi

    curl -X PUT -H "content-type: application/json" -H "X-Tapis-Token: $JWT" https://vdjserver.tapis.io/v3/systems/$1 -d @$2
}
typeset -fx tapis_systems_update

function tapis_systems_credentials() {
    if [ $# -ne 3 ];
    then
        echo "usage: tapis_systems_credentials system_id username json_file"
        return 1
    fi

    tapis_check_token
    if [ $? -ne 0 ]; then
        return 1
    fi

    curl -X POST -H "content-type: application/json" -H "X-Tapis-Token: $JWT" https://vdjserver.tapis.io/v3/systems/credential/$1/user/$2 -d @$3
}
typeset -fx tapis_systems_credentials

# ----------------------------------------------------------------------------
# files
#
function tapis_files_list() {
    if [ $# -eq 1 ]; then
        storage_system=$tapis_default_storage
        use_path=$1
    else
        if [ $# -eq 2 ]; then
            storage_system=$1
            use_path=$2
        else
            echo "usage: tapis_files_list [system_id] path"
            return 1
        fi
    fi

    tapis_check_token
    if [ $? -ne 0 ]; then
        return 1
    fi

    curl -H "X-Tapis-Token: $JWT" https://vdjserver.tapis.io/v3/files/ops/${storage_system}${use_path} | jq
}
typeset -fx tapis_files_list

# ----------------------------------------------------------------------------
# apps
#
function tapis_apps_list() {
    if [ $# -eq 1 ]; then
        app=/$1
    else
        if [ $# -eq 2 ]; then
            app=/$1/$2
        else
            app=
        fi
    fi

    tapis_check_token
    if [ $? -ne 0 ]; then
        return 1
    fi

    curl -H "X-Tapis-Token: $JWT" https://vdjserver.tapis.io/v3/apps${app}?select=allAttributes | jq
}
typeset -fx tapis_apps_list

function tapis_apps_create() {
    if [ $# -ne 1 ];
    then
        echo "usage: tapis_apps_create json_file"
        return 1
    fi

    tapis_check_token
    if [ $? -ne 0 ]; then
        return 1
    fi

    curl -X POST -H "content-type: application/json" -H "X-Tapis-Token: $JWT" https://vdjserver.tapis.io/v3/apps -d @$1
}
typeset -fx tapis_apps_create

function tapis_apps_update() {
    if [ $# -ne 3 ];
    then
        echo "usage: tapis_apps_update app_name app_version json_file"
        return 1
    fi

    tapis_check_token
    if [ $? -ne 0 ]; then
        return 1
    fi

    curl -X PUT -H "content-type: application/json" -H "X-Tapis-Token: $JWT" https://vdjserver.tapis.io/v3/apps/$1/$2 -d @$3
}
typeset -fx tapis_apps_update

# ----------------------------------------------------------------------------
# jobs
#
function tapis_jobs_submit() {
    if [ $# -ne 1 ];
    then
        echo "usage: tapis_jobs_submit json_file"
        return 1
    fi

    tapis_check_token
    if [ $? -ne 0 ]; then
        return 1
    fi

    curl -X POST -H "content-type: application/json" -H "X-Tapis-Token: $JWT" https://vdjserver.tapis.io/v3/jobs/submit -d @$1 | jq
}
typeset -fx tapis_jobs_submit

function tapis_jobs_list() {
    if [ $# -eq 1 ]; then
        job=/$1
    else
        job=/list
    fi

    tapis_check_token
    if [ $? -ne 0 ]; then
        return 1
    fi

    curl -H "X-Tapis-Token: $JWT" https://vdjserver.tapis.io/v3/jobs${job}"?select=allAttributes&orderBy=lastUpdated(desc)" | jq
}
typeset -fx tapis_jobs_list
