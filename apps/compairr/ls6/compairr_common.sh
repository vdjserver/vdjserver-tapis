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
    echo "airr_tsv_files=${airr_tsv_files}"
    echo ""
    echo "Application parameters:"
    echo "analysis_type=${analysis_type}"
    echo "distance=${distance}"
}

function run_compairr_workflow() {
    initProvenance
    #concatenate files
    concatenated_file="concat.tsv"
    ${PYTHON} concatenate_airr_tsv.py -i $airr_tsv_files -o $concatenated_file
    #deduplicate files
    deduplicated_file="dedup_${concatenated_file}"
    echo "Command: apptainer exec -e ${compairr_image} compairr --deduplicate --out ${deduplicated_file}"
    apptainer exec -e "${compairr_image}" compairr --deduplicate --out "${deduplicated_file}" "${concatenated_file}"

    # Assuming .tsv extension
    file_basename="${deduplicated_file%.*}" # file.tsv -> file

    cluster_file="${file_basename}_d_${distance}_clust.tsv"

    default_matrix_file="${file_basename}_d_${distance}_prodmat.txt"
    pairs_file="${file_basename}_d_${distance}_pairs.tsv"

    mh_matrix_file="${file_basename}_MHmat.txt"
    jaccard_matrix_file="${file_basename}_Jacmat.txt"
    
    if [[ "$analysis_type" == "cluster" ]] ; then
        echo "Running Cluster Analysis for distance $distance"

        echo "Command: apptainer exec -e ${compairr_image} compairr --cluster ${deduplicated_file} -d ${distance} --out $cluster_file"
        apptainer exec -e "${compairr_image}" compairr --cluster -d "${distance}" --out "$cluster_file" "${deduplicated_file}"
    
    elif [[ "$analysis_type" == "overlap" ]]; then
        echo "Calculating overlap analysis for distance $distance."

        echo "Command: apptainer exec -e ${compairr_image} compairr --matrix -d ${distance} --pairs ${pairs_file} ${deduplicated_file}"
        apptainer exec -e "${compairr_image}" compairr --matrix -d "${distance}" --pairs "${pairs_file}" "${deduplicated_file}"
    
    elif [[ "$analysis_type" == "matrix" ]]; then
        echo "Running matrix analysis for MH and Jaccard Score."

        echo "Command: apptainer -e ${compairr_image} compairr --matrix --out ${mh_matrix_file} --score MH ${deduplicated_file}"
        apptainer exec -e "${compairr_image}" compairr --matrix --out "${mh_matrix_file}" --score MH "${deduplicated_file}"

        echo "Command: apptainer exec -e ${compairr_image} compairr --matrix --out ${jaccard_matrix_file} --score Jaccard ${deduplicated_file} "
        apptainer exec -e "${compairr_image}" compairr --matrix --out "${jaccard_matrix_file}" --score Jaccard "${deduplicated_file}"

    else
        echo "ERROR: Invalid $analysis_type or $distance provided"
        return 1
    fi
}
