#
# VDJServer TILDE common functions
#
# VDJServer Analysis Portal
# VDJServer Tapis applications
# https://vdjserver.org
#
# Copyright (C) 2016-2026 The University of Texas Southwestern Medical Center
# Author: Scott Christley
# Date: Mar 25, 2026
# 

APP_NAME=tilde
# TODO: this is not generic enough
export ACTIVITY_NAME="vdjserver:activity:tilde"

# bring in common functions
source ./common_functions.sh

# bring in provenance functions
source ./provenance_functions.sh

# ----------------------------------------------------------------------------
# IgBlast workflow

function print_versions() {
    echo "VERSIONS:"
    echo "  $($PYTHON --version 2>&1)"
#    echo "  $($AIRR_TOOLS --version 2>&1)"
    echo -e "\nSTART at $(date)"
}

function print_parameters() {
    echo "Input files:"
    echo "ak_graph_image=${ak_graph_image}"
    echo "analysis_provenance=${analysis_provenance}"
    echo "AIRRMetadata=${AIRRMetadata}"
    echo "JobFiles=${JobFiles}"
    echo "AIRRFiles=${AIRRFiles}"
    echo ""
    echo "Application parameters:"
    echo "ReceptorMatchFlag=${ReceptorMatchFlag}"
    echo "EpitopeMatchFlag=${EpitopeMatchFlag}"
}

function run_tilde_workflow() {
    addCalculation "${ACTIVITY_NAME}" receptor_matching
    addCalculation "${ACTIVITY_NAME}" epitope_matching

    # unarchive job files
    for file in $JobFiles; do
        if [ -f $file ]; then
            expandfile $file

            # copy files that will be processed
            fileBasename="${file%.*}" # test/file.fasta -> test/file
            for file2 in $AIRRFiles; do
                if [ -f $fileBasename/$file2 ]; then
                    cp $fileBasename/$file2 .
                fi
            done
        fi
    done

    # launcher job file
    if [ -f joblist ]; then
        echo "Warning: removing file 'joblist'.  That filename is reserved." 1>&2
        rm joblist
    fi
    touch joblist

    filelist=()
    count=0
    repertoires=""
    for file in $AIRRFiles; do
        query_file=$file
        rep_id=$(getRepertoireForFile $file)
        # TODO: check error
        repertoires="${repertoires} ${rep_id}"

        fileOutname="${file##*/}" # test/file -> file
        #addOutputFile $group $APP_NAME assignment_sequence "$file" "Input Sequences ($fileOutname)" "read" null

        expandfile $file
        fileExtension="${file##*.}" # file.fastq -> fastq
        fileBasename="${file%.*}" # file.fastq -> file

        # save expanded filenames for later merging
        filelist[${#filelist[@]}]=$file

        # TODO: get these from repertoire metadata
        species=human

        # command to run TILDE
        echo "export $PYTHON --version" >> joblist

        count=$(( $count + 1 ))
    done

    # check number of jobs to be run
    export LAUNCHER_PPN=$LAUNCHER_MAX_PPN
    numJobs=$(cat joblist | wc -l)
    if [ $numJobs -lt $LAUNCHER_PPN ]; then
        export LAUNCHER_PPN=$numJobs
    fi

    echo "Starting igblast on $(date)"
    $LAUNCHER_DIR/paramrun

    # ----------------------------------------------------------------------------

    #add provenance here.
    count=0
    for file in ${filelist[@]}; do
        fileBasename="${file%.*}" # file.fastq -> file

        wasDerivedFrom "${fileBasename}.tilde.detail.tsv.gz" "${file}" "match_detail" "TILDE match detail" tsv
        wasDerivedFrom "${fileBasename}.tilde.summary.tsv.gz" "${file}" "match_summary" "TILDE match summary" tsv
        wasDerivedFrom "${fileBasename}.tilde.assay.json" "${file}" "assay_match" "TILDE assay dictionary for matches" json

        count=$(( $count + 1 ))
    done

}

function compress_and_archive() {
    # Provenance file
    wasGeneratedBy "provenance_output.json" "${ACTIVITY_NAME}" prov "Analysis Provenance" json
    wasGeneratedBy ${_tapisJobUUID}.zip "${ACTIVITY_NAME}" archive "Archive of Output Files" zip
    wasGeneratedBy "tapisjob.out" "${ACTIVITY_NAME}" output_log "Output logs" txt
    wasGeneratedBy "tapisjob.err" "${ACTIVITY_NAME}" output_error_log "Output logs (Error)" txt

    # gzip any files
    for file in $GZIP_FILE_LIST; do
        if [ -f $file ]; then
            gzip $file
        fi
    done

    # zip archive of all output files
    for file in $ARCHIVE_FILE_LIST; do
        if [ -f $file ]; then
            cp -f $file ${_tapisJobUUID}
            cp -f $file output
        fi
    done
    zip ${_tapisJobUUID}.zip ${_tapisJobUUID}/*
    cp ${_tapisJobUUID}.zip output

}
