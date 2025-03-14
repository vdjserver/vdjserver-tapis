#
# TCRMatch common functions
#
# VDJServer Analysis Portal
# VDJServer Tapis applications
# https://vdjserver.org
#
# Part of the iReceptor+ platform
#
# Copyright (C) 2021 The University of Texas Southwestern Medical Center
# Author: Brian Corrie
# Date: Mar 14, 2025
# 

# the app
export APP_NAME=tcrmatch

# bring in common functions
source ./common_functions.sh

# bring in provenance functions
source ./provenance_functions.sh

# ----------------------------------------------------------------------------
# Workflow

function print_versions() {
    echo "VERSIONS:"
    apptainer exec ${tcrmatch_image} /TCRMatch/tcrmatch -v
    echo -e "\nSTART at $(date)"
}

function print_parameters() {
    echo "Input files:"
    echo "tcrmatch_image=${tcrmatch_image}"
    echo "airr_tsv_file=${airr_tsv_file}"
    echo ""
    echo "Application parameters:"
    echo "threshold=${threshold}"
    echo "file_type=${file_type}"
}

function run_tcrmatch_workflow() {
    initProvenance

    # expand rearrangement file if its compressed
    expandfile $airr_tsv_file
    #noArchive $file

    # Assuming airr.tsv extension
    fileBasename="${file%.*}" # file.airr.tsv -> file.airr
    fileBasename="${fileBasename%.*}" # file.airr -> file

    # Generate a CDR3 file.
    # Extract junction_aa column if it exists using awk
    #
    # TCRMatch needs CDR3s so if we are processing Junctions we need to strip
    # off the first and last AA.
    # For junctions if the first character is a C and the last is either W or F
    # (/^C.*[WF]$/) we assume it is a full junction and strip of those 
    # characters with the sed regular expression substuution s/^.\(.*\).$/\1/'
    #
    # sort -u - We only want to search once per CDR3
    #
    # egrep -v "\*" - Remove any CDR3s with special characters
    # Use awk to extract the column
    awk -v colname="junction_aa" 'BEGIN {FS="\t"} 
        NR==1 {
            for (i=1; i<=NF; i++) {
                if ($i == colname) {
                    colnum = i;
                    break;
                }
            }
            if (!colnum) {
                print "Error: Column '" colname "' not found.";
                exit 1;
            }
        }
        NR>1 { print $colnum }' ${file} \
        | sed '/^C.*[WF]$/ s/^.\(.*\).$/\1/' \
        | sort -u \
        | egrep "^[ABCDEFGHIKLMNPQRSTVWYZ]*$" \
	| head -1000 \
	> ${fileBasename}_cdr3.tsv


    # Run compairr in matrix mode, using the "analysis_type" to determine
    # which method to use.
    if [[ "$file_type" == "rearrangement" ]] ; then
	echo "apptainer exec -e ${tcrmatch_image} /TCRMatch/tcrmatch -i ${fileBasename}_cdr3.tsv -d /TCRMatch/data/IEDB_data.tsv -t 1 -s ${threshold} > ${fileBasename}_epitope.tsv"
	apptainer exec -e ${tcrmatch_image} /TCRMatch/tcrmatch -i ${fileBasename}_cdr3.tsv -d /TCRMatch/data/IEDB_data.tsv -t 1 -s ${threshold} > ${fileBasename}_epitope.tsv
    fi

}
