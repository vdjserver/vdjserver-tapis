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

    # Rearrangement counts
    if [[ "$file_type" == "rearrangement" ]] ; then
	apptainer exec -e ${compairr_image} compairr -f -e -u -s $analysis_type --matrix ${file} --out $fileBasename.matrix.tsv
        #apptainer exec -e ${compairr_image} python3 count_statistics.py $file
    fi

    return
    # Clonal abundance
    if [[ "$file_type" == "clone" ]] ; then
        apptainer exec -e -B $PWD:/data ${compairr_image} /data/clonal_abundance.R -d $file -o $fileBasename
    fi

    # Gene Usage
    if [[ "$file_type" == "clone" ]] ; then
        apptainer exec -e -B $PWD:/data ${compairr_image} /data/gene_usage.R -d $file -o $fileBasename
    fi
    if [[ "$file_type" == "rearrangement" ]] ; then
        $PYTHON repcalc_create_config.py --init gene_usage_template.json ${metadata_file} --rearrangementFile $file --repertoireID ${repertoire_id} --germline ${germline_db} gene_usage_config.json
        apptainer exec -e ${compairr_image} repcalc gene_usage_config.json
    fi

    # Amino Acid properties
    #singularity exec -e -B $PWD:/data ${compairr_image} /data/aa_properties.R -d $file

    # Junction length distribution
    $PYTHON repcalc_create_config.py --init junction_length_template.json ${metadata_file} --rearrangementFile $file --repertoireID ${repertoire_id} --germline ${germline_db} junction_length_config.json
    apptainer exec -e ${compairr_image} repcalc junction_length_config.json

    # Diversity curve
    if [[ "$file_type" == "clone" ]] ; then
        apptainer exec -e -B $PWD:/data ${compairr_image} /data/diversity_curve.R -d $file -o $fileBasename
    fi
    
    # final report
    $PYTHON rearrangement_report.py ${repertoire_id} null null $file
}
