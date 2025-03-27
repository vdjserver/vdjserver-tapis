#
# Olga common functions
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
export APP_NAME=olga

# bring in common functions
source ./common_functions.sh

# bring in provenance functions
source ./provenance_functions.sh

# ----------------------------------------------------------------------------
# Workflow

function print_versions() {
    echo -e "\nSTART at $(date)"
}

function print_parameters() {
    echo "Input files:"
    echo "olga_image=${olga_image}"
    echo "airr_tsv_file=${airr_tsv_file}"
    echo ""
    echo "Application parameters:"
    echo "file_type=${file_type}"
}

function run_olga_workflow() {
    initProvenance

    # expand rearrangement file if its compressed
    expandfile $airr_tsv_file
    #noArchive $file

    # Assuming airr.tsv extension
    fileBasename="${file%.*}" # file.airr.tsv -> file.airr
    fileBasename="${fileBasename%.*}" # file.airr -> file

    # Get the columns required by olga
    junction_column=$(head -n 1 ${file} | awk -F"\t" -v label=junction '{for(i=1;i<=NF;i++){if ($i == label){print i}}}')
    junction_aa_column=$(head -n 1 ${file} | awk -F"\t" -v label=junction_aa '{for(i=1;i<=NF;i++){if ($i == label){print i}}}')
    v_call_column=$(head -n 1 ${file} | awk -F"\t" -v label=v_call '{for(i=1;i<=NF;i++){if ($i == label){print i}}}')
    j_call_column=$(head -n 1 ${file} | awk -F"\t" -v label=j_call '{for(i=1;i<=NF;i++){if ($i == label){print i}}}')
    # Check to make sure we found them, and if not, print an error message and skip this file.
    if [[ -z "$junction_column" ]]; then
        echo "ERROR: Could not find required column junction in ${file}"
        return
    fi
    if [[ -z "$junction_aa_column" ]]; then
        echo "ERROR: Could not find required column junction_aa in ${file}"
        return
    fi
    if [[ -z "$v_call_column" ]]; then
        echo "ERROR: Could not find required column v_call in ${file}"
        return
    fi
    if [[ -z "$j_call_column" ]]; then
        echo "ERROR: Could not find required column j_call in ${file}"
        return
    fi

    # Check the rearrangement file and extract the list
    # of loci in the data 
    repertoire_locus=( `cat $file | cut -f ${v_call_column} | tail --lines=+2 | awk '{printf("%s\n", substr($1,0,3))}' | sort -u | awk '{printf("%s  ",$0)}'` )
    if [ $? -ne 0 ]
    then
        echo "ERROR: Could not get a locus from ${file}, processing not completed"
	return
    fi

    # Check to see if there is only one locus type in the data.
    if [ ${#repertoire_locus[@]} != 1 ]
    then
        echo "ERROR: Olga analysis requires a single locus (loci = ${repertoire_locus[@]})."
        return
    fi

    # If there is only one, check to see if it is a valid locus, if so then we are good,
    # if not it is an error.
    repertoire_locus=${repertoire_locus[0]}

    if [ "${repertoire_locus}" == "TRB" ]
    then
        germline_set="humanTRB"
    elif [ "${repertoire_locus}" == "TRA" ]
    then
        germline_set="humanTRA"
    elif [ "${repertoire_locus}" == "IGH" ]
    then
        germline_set="humanIGH"
    elif [ "${repertoire_locus}" == "IGK" ]
    then
        germline_set="humanIGK"
    elif [ "${repertoire_locus}" == "IGL" ]
    then
        germline_set="humanIGL"
    else
        echo "ERROR: Olga analysis can only run on TRA, TRB, IGH, IGH, or IGL repertoires (locus type = ${repertoire_locus})."
        return
    fi

    TMP_TSVFILE=${fileBasename}-tmp.tsv
    tail -n +2 ${file} | awk -F"\t" -v junction_column=${junction_column} -v junction_aa_column=${junction_aa_column} -v v_call_column=${v_call_column} -v j_call_column=${j_call_column} '{printf("%s\t%s\t%s\t%s\n",$junction_column,$junction_aa_column,"",$v_call_column,$j_call_column)}' > ${TMP_TSVFILE}

    # Run olga 
    if [[ "$file_type" == "rearrangement" ]] ; then
        PGEN_OUTPUT_FILE=${fileBasename}-pgen.tsv
        echo -e "Junction NT sequence\tJunction NT PGEN\tJunction AA sequence\tJunction AA PGEN" > ${PGEN_OUTPUT_FILE}

	PGEN_TMP_OUTFILE=${fileBasename}-tmp-pgen.tsv
	echo "apptainer exec -e ${olga_image} olga-compute_pgen --display_off --time_updates_off --${germline_set} -i ${TMP_TSVFILE} -o ${PGEN_TMP_OUTFILE} >&2"
	apptainer exec -e ${olga_image} olga-compute_pgen --display_off --time_updates_off --${germline_set} -i ${TMP_TSVFILE} -o ${PGEN_TMP_OUTFILE} >&2
	cat ${PGEN_TMP_OUTFILE} >> ${PGEN_OUTPUT_FILE}
	#rm $PGEN_TMP_OUTFILE

    fi

}
