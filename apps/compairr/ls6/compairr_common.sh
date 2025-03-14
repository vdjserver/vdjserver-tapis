#
# CompAIRR common functions
#
# VDJServer Analysis Portal
# VDJServer Tapis applications
# https://vdjserver.org
#
# Part of the iReceptor+ platform
#
# Copyright (C) 2021 The University of Texas Southwestern Medical Center
# Author: Brian Corrie
# Date: Mar 13, 2025
# 

# the app
export APP_NAME=compairr

# bring in common functions
source ./common_functions.sh

# bring in provenance functions
source ./provenance_functions.sh

# ----------------------------------------------------------------------------
# Workflow

function print_versions() {
    echo "VERSIONS:"
    #apptainer exec ${compairr_image} versions report
    apptainer exec ${compairr_image} compairr --version
    echo -e "\nSTART at $(date)"
}

function print_parameters() {
    echo "Input files:"
    echo "compairr_image=${compairr_image}"
    echo "airr_tsv_file=${airr_tsv_file}"
    echo ""
    echo "Application parameters:"
    echo "analysis_type=${analysis_type}"
    echo "file_type=${file_type}"
}

function run_compairr_workflow() {
    initProvenance

    # expand rearrangement file if its compressed
    expandfile $airr_tsv_file
    #noArchive $file

    # Assuming airr.tsv extension
    fileBasename="${file%.*}" # file.airr.tsv -> file.airr
    fileBasename="${fileBasename%.*}" # file.airr -> file

    # Run compairr in matrix mode, using the "analysis_type" to determine
    # which method to use.
    if [[ "$file_type" == "rearrangement" ]] ; then
	apptainer exec -e ${compairr_image} compairr -f -e -u -s $analysis_type --matrix ${file} --out $fileBasename.matrix.tsv
    fi

}
