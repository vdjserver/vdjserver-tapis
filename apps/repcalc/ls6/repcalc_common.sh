#
# VDJServer RepCalc common functions
#
# VDJServer Analysis Portal
# VDJServer Tapis applications
# https://vdjserver.org
#
# This script relies upon global variables
# source repcalc_common.sh
#
# Author: Scott Christley
# Copyright (C) 2016-2024 The University of Texas Southwestern Medical Center
# Date: Sep 1, 2016
# 

# required global variables:
# REPCALC_EXE
# PYTHON
# and...
# The app input and parameters

# the app
export APP_NAME=RepCalc
export ACTIVITY_NAME="vdjserver:activity:repcalc"

# bring in common functions
source ./common_functions.sh

# bring in provenance functions
source ./provenance_functions.sh

# ----------------------------------------------------------------------------
# RepCalc workflow

function print_versions() {
    echo "VERSIONS:"
    echo "  $($PYTHON --version 2>&1)"
    apptainer exec -e ${repcalc_image} versions report
    echo "  $($REPCALC_EXE --version 2>&1)"
    echo -e "\nSTART at $(date)"
}

function print_parameters() {
    echo "Input files:"
    echo "repcalc_image=${repcalc_image}"
    echo "germline_archive=${germline_archive}"
    echo "AIRRMetadata=${AIRRMetadata}"
    echo "RepertoireGroupMetadata=${RepertoireGroupMetadata}"
    echo "JobFiles=$JobFiles"
    echo "AIRRFiles=${AIRRFiles}"
    echo ""
    echo "Application parameters:"
    echo "species=${species}"
    echo "locus=${locus}"
    echo "split_locus=${split_locus}"
    echo "germline_db_file=${germline_db_file}"
    echo "germline_fasta=${germline_fasta}"
    echo "GeneSegmentFlag=${GeneSegmentFlag}"
    echo "CDR3Flag=${CDR3Flag}"
    echo "DiversityFlag=${DiversityFlag}"
    echo "ClonalFlag=${ClonalFlag}"
    echo "MutationalFlag=${MutationalFlag}"
    echo "LineageFlag=${LineageFlag}"
}

function run_repcalc_workflow() {

    # Extract input files
    for file in $JobFiles; do
        if [ -f $file ]; then
            unzip -o $file
            fileBasename="${file%.*}" # test/file.fasta -> test/file
            gunzip $fileBasename/*.gz
            mv $fileBasename/*.airr.tsv .
        fi
    done

    fileList=($(ls *.airr.tsv))
    count=0
    while [ "x${fileList[count]}" != "x" ]
    do
        file=${fileList[count]}
        count=$(( $count + 1 ))
    done

    # get list of repertoires
    repertoires=($($PYTHON ./airr_metadata.py --list Repertoire repertoire_id ${AIRRMetadata}))

    # get list of repertoire groups
    if [ "x${RepertoireGroupMetadata}" != "x" ]; then
        repertoire_groups=($($PYTHON ./airr_metadata.py --list RepertoireGroup repertoire_group_id ${RepertoireGroupMetadata}))
    fi

    # simple technique to check for files using wildcard
    has_igblast=0
    if ls *.igblast.airr.tsv 1> /dev/null 2>&1; then
        has_igblast=1
    fi
    echo has_igblast=$has_igblast
    has_makedb=0
    if ls *.igblast.makedb.airr.tsv 1> /dev/null 2>&1; then
        has_makedb=1
    fi
    echo has_makedb=$has_makedb
    has_igblast_clone=0
    if ls *.igblast.allele.clone.airr.tsv 1> /dev/null 2>&1; then
        has_igblast_clone=1
    fi
    echo has_igblast_clone=$has_igblast_clone
    has_makedb_clone=0
    if ls *.igblast.makedb.allele.clone.airr.tsv 1> /dev/null 2>&1; then
        has_makedb_clone=1
    fi
    echo has_makedb_clone=$has_makedb_clone
    has_gene_clone=0
    if ls *.igblast.makedb.gene.clone.airr.tsv 1> /dev/null 2>&1; then
        has_gene_clone=1
    fi
    echo has_gene_clone=$has_gene_clone

    # Split AIRR TSV into separate files by locus
    igblast_locus=""
    makedb_locus=""
    igblast_clone_locus=""
    makedb_clone_locus=""
    gene_clone_locus=""
    if [[ $split_locus -eq 1 ]]; then
        echo "Split AIRR TSV into separate files by locus"
        if [[ $has_igblast -eq 1 ]]; then
            processing_stage=igblast
            $PYTHON split_locus.py ${AIRRMetadata} ${processing_stage}

            # check which loci
            for locus_name in TRA TRB TRG TRD IGH IGK IGL; do
                if ls *.${locus_name}.${processing_stage}.airr.tsv 1> /dev/null 2>&1; then
                    igblast_locus="${igblast_locus} ${locus_name}"
                fi
            done
            echo igblast_locus=$igblast_locus

            # make sure each repertoire has a file otherwise repcalc will complain
            # create empty file with AIRR TSV header
            count=0
            while [ "x${repertoires[count]}" != "x" ]
            do
                rep_id=${repertoires[count]}
                for locus_name in $igblast_locus; do
                    if [[ ! -f "${rep_id}.${locus_name}.${processing_stage}.airr.tsv" ]]; then
                        echo Creating empty AIRR TSV: ${rep_id}.${locus_name}.${processing_stage}.airr.tsv
                        head -n 1 ${rep_id}.${processing_stage}.airr.tsv > ${rep_id}.${locus_name}.${processing_stage}.airr.tsv
                    fi
                done
                count=$(( $count + 1 ))
            done
        fi
        if [[ $has_makedb -eq 1 ]]; then
            processing_stage=igblast.makedb
            $PYTHON split_locus.py ${AIRRMetadata} ${processing_stage} 

            for locus_name in TRA TRB TRG TRD IGH IGK IGL; do
                if ls *.${locus_name}.${processing_stage}.airr.tsv 1> /dev/null 2>&1; then
                    makedb_locus="${makedb_locus} ${locus_name}"
                fi
            done
            echo makedb_locus=$makedb_locus

            # make sure each repertoire has a file otherwise repcalc will complain
            # create empty file with AIRR TSV header
            count=0
            while [ "x${repertoires[count]}" != "x" ]
            do
                rep_id=${repertoires[count]}
                for locus_name in $makedb_locus; do
                    if [[ ! -f "${rep_id}.${locus_name}.${processing_stage}.airr.tsv" ]]; then
                        echo Creating empty AIRR TSV: ${rep_id}.${locus_name}.${processing_stage}.airr.tsv
                        head -n 1 ${rep_id}.${processing_stage}.airr.tsv > ${rep_id}.${locus_name}.${processing_stage}.airr.tsv
                    fi
                done
                count=$(( $count + 1 ))
            done
        fi
        if [[ $has_igblast_clone -eq 1 ]]; then
            processing_stage=igblast.allele.clone
            $PYTHON split_locus.py ${AIRRMetadata} ${processing_stage} 

            for locus_name in TRA TRB TRG TRD IGH IGK IGL; do
                if ls *.${locus_name}.${processing_stage}.airr.tsv 1> /dev/null 2>&1; then
                    igblast_clone_locus="${igblast_clone_locus} ${locus_name}"
                fi
            done
            echo igblast_clone_locus=$igblast_clone_locus

            # make sure each repertoire has a file otherwise repcalc will complain
            # create empty file with AIRR TSV header
            count=0
            while [ "x${repertoires[count]}" != "x" ]
            do
                rep_id=${repertoires[count]}
                for locus_name in $igblast_clone_locus; do
                    if [[ ! -f "${rep_id}.${locus_name}.${processing_stage}.airr.tsv" ]]; then
                        echo Creating empty AIRR TSV: ${rep_id}.${locus_name}.${processing_stage}.airr.tsv
                        head -n 1 ${rep_id}.${processing_stage}.airr.tsv > ${rep_id}.${locus_name}.${processing_stage}.airr.tsv
                    fi
                done
                count=$(( $count + 1 ))
            done
        fi
        if [[ $has_makedb_clone -eq 1 ]]; then
            processing_stage=igblast.makedb.allele.clone
            $PYTHON split_locus.py ${AIRRMetadata} ${processing_stage} 

            for locus_name in TRA TRB TRG TRD IGH IGK IGL; do
                if ls *.${locus_name}.${processing_stage}.airr.tsv 1> /dev/null 2>&1; then
                    makedb_clone_locus="${makedb_clone_locus} ${locus_name}"
                fi
            done
            echo makedb_clone_locus=$makedb_clone_locus

            # make sure each repertoire has a file otherwise repcalc will complain
            # create empty file with AIRR TSV header
            count=0
            while [ "x${repertoires[count]}" != "x" ]
            do
                rep_id=${repertoires[count]}
                for locus_name in $makedb_clone_locus; do
                    if [[ ! -f "${rep_id}.${locus_name}.${processing_stage}.airr.tsv" ]]; then
                        echo Creating empty AIRR TSV: ${rep_id}.${locus_name}.${processing_stage}.airr.tsv
                        head -n 1 ${rep_id}.${processing_stage}.airr.tsv > ${rep_id}.${locus_name}.${processing_stage}.airr.tsv
                    fi
                done
                count=$(( $count + 1 ))
            done
        fi
        if [[ $has_gene_clone -eq 1 ]]; then
            processing_stage=igblast.makedb.gene.clone
            $PYTHON split_locus.py ${AIRRMetadata} ${processing_stage} 

            for locus_name in TRA TRB TRG TRD IGH IGK IGL; do
                if ls *.${locus_name}.${processing_stage}.airr.tsv 1> /dev/null 2>&1; then
                    gene_clone_locus="${gene_clone_locus} ${locus_name}"
                fi
            done
            echo gene_clone_locus=$gene_clone_locus

            # make sure each repertoire has a file otherwise repcalc will complain
            # create empty file with AIRR TSV header
            count=0
            while [ "x${repertoires[count]}" != "x" ]
            do
                rep_id=${repertoires[count]}
                for locus_name in $gene_clone_locus; do
                    if [[ ! -f "${rep_id}.${locus_name}.${processing_stage}.airr.tsv" ]]; then
                        echo Creating empty AIRR TSV: ${rep_id}.${locus_name}.${processing_stage}.airr.tsv
                        head -n 1 ${rep_id}.${processing_stage}.airr.tsv > ${rep_id}.${locus_name}.${processing_stage}.airr.tsv
                    fi
                done
                count=$(( $count + 1 ))
            done
        fi
    fi

    # Gene segment usage
    if [[ $GeneSegmentFlag -eq 1 ]]; then
        echo "Calculate gene segment and combo usage"

        # launcher job file
        if [ -f joblist-gene ]; then
            echo "Warning: removing file 'joblist-gene'.  That filename is reserved." 1>&2
            rm joblist-gene
        fi
        touch joblist-gene

        if [[ $has_igblast -eq 1 ]]; then
            if [[ $split_locus -eq 1 ]]; then
                for locus_name in $igblast_locus; do
                    processing_stage=${locus_name}.igblast
                    if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                        python3 repcalc_create_config.py --init gene_usage_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db_file} --stage ${processing_stage} gene_usage_config.${processing_stage}.json
                    else
                        python3 repcalc_create_config.py --init gene_usage_template.json ${AIRRMetadata} --germline ${germline_db_file} --stage ${processing_stage} gene_usage_config.${processing_stage}.json
                    fi
                    echo "$REPCALC_EXE gene_usage_config.${processing_stage}.json" >> joblist-gene
        
                    if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                        python3 repcalc_create_config.py --init gene_combo_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db_file} --stage ${processing_stage} gene_combo_config.${processing_stage}.json
                    else
                        python3 repcalc_create_config.py --init gene_combo_template.json ${AIRRMetadata} --germline ${germline_db_file} --stage ${processing_stage} gene_combo_config.${processing_stage}.json
                    fi
                    echo "$REPCALC_EXE gene_combo_config.${processing_stage}.json" >> joblist-gene
                done
            else
                processing_stage=igblast
                if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                    python3 repcalc_create_config.py --init gene_usage_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db_file} --stage ${processing_stage} gene_usage_config.${processing_stage}.json
                else
                    python3 repcalc_create_config.py --init gene_usage_template.json ${AIRRMetadata} --germline ${germline_db_file} --stage ${processing_stage} gene_usage_config.${processing_stage}.json
                fi
                echo "$REPCALC_EXE gene_usage_config.${processing_stage}.json" >> joblist-gene
    
                if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                    python3 repcalc_create_config.py --init gene_combo_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db_file} --stage ${processing_stage} gene_combo_config.${processing_stage}.json
                else
                    python3 repcalc_create_config.py --init gene_combo_template.json ${AIRRMetadata} --germline ${germline_db_file} --stage ${processing_stage} gene_combo_config.${processing_stage}.json
                fi
                echo "$REPCALC_EXE gene_combo_config.${processing_stage}.json" >> joblist-gene
            fi
        fi
        if [[ $has_makedb -eq 1 ]]; then
            if [[ $split_locus -eq 1 ]]; then
                for locus_name in $makedb_locus; do
                    processing_stage=${locus_name}.igblast.makedb
                    if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                        python3 repcalc_create_config.py --init gene_usage_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db_file} --stage ${processing_stage} gene_usage_config.${processing_stage}.json
                    else
                        python3 repcalc_create_config.py --init gene_usage_template.json ${AIRRMetadata} --germline ${germline_db_file} --stage ${processing_stage} gene_usage_config.${processing_stage}.json
                    fi
                    echo "$REPCALC_EXE gene_usage_config.${processing_stage}.json" >> joblist-gene
        
                    if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                        python3 repcalc_create_config.py --init gene_combo_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db_file} --stage ${processing_stage} gene_combo_config.${processing_stage}.json
                    else
                        python3 repcalc_create_config.py --init gene_combo_template.json ${AIRRMetadata} --germline ${germline_db_file} --stage ${processing_stage} gene_combo_config.${processing_stage}.json
                    fi
                    echo "$REPCALC_EXE gene_combo_config.${processing_stage}.json" >> joblist-gene
                done
            else
                processing_stage=igblast.makedb
                if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                    python3 repcalc_create_config.py --init gene_usage_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db_file} --stage ${processing_stage} gene_usage_config.${processing_stage}.json
                else
                    python3 repcalc_create_config.py --init gene_usage_template.json ${AIRRMetadata} --germline ${germline_db_file} --stage ${processing_stage} gene_usage_config.${processing_stage}.json
                fi
                echo "$REPCALC_EXE gene_usage_config.${processing_stage}.json" >> joblist-gene
    
                if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                    python3 repcalc_create_config.py --init gene_combo_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db_file} --stage ${processing_stage} gene_combo_config.${processing_stage}.json
                else
                    python3 repcalc_create_config.py --init gene_combo_template.json ${AIRRMetadata} --germline ${germline_db_file} --stage ${processing_stage} gene_combo_config.${processing_stage}.json
                fi
                echo "$REPCALC_EXE gene_combo_config.${processing_stage}.json" >> joblist-gene
            fi
        fi
        if [[ $has_igblast_clone -eq 1 ]]; then
            if [[ $split_locus -eq 1 ]]; then
                for locus_name in $igblast_clone_locus; do
                    processing_stage=${locus_name}.igblast.allele.clone
                    if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                        python3 repcalc_create_config.py --init gene_usage_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db_file} --stage ${processing_stage} gene_usage_config.${processing_stage}.json
                    else
                        python3 repcalc_create_config.py --init gene_usage_template.json ${AIRRMetadata} --germline ${germline_db_file} --stage ${processing_stage} gene_usage_config.${processing_stage}.json
                    fi
                    echo "$REPCALC_EXE gene_usage_config.${processing_stage}.json" >> joblist-gene
        
                    if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                        python3 repcalc_create_config.py --init gene_combo_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db_file} --stage ${processing_stage} gene_combo_config.${processing_stage}.json
                    else
                        python3 repcalc_create_config.py --init gene_combo_template.json ${AIRRMetadata} --germline ${germline_db_file} --stage ${processing_stage} gene_combo_config.${processing_stage}.json
                    fi
                    echo "$REPCALC_EXE gene_combo_config.${processing_stage}.json" >> joblist-gene
                done
            else
                processing_stage=igblast.allele.clone
                if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                    python3 repcalc_create_config.py --init gene_usage_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db_file} --stage ${processing_stage} gene_usage_config.${processing_stage}.json
                else
                    python3 repcalc_create_config.py --init gene_usage_template.json ${AIRRMetadata} --germline ${germline_db_file} --stage ${processing_stage} gene_usage_config.${processing_stage}.json
                fi
                echo "$REPCALC_EXE gene_usage_config.${processing_stage}.json" >> joblist-gene
    
                if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                    python3 repcalc_create_config.py --init gene_combo_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db_file} --stage ${processing_stage} gene_combo_config.${processing_stage}.json
                else
                    python3 repcalc_create_config.py --init gene_combo_template.json ${AIRRMetadata} --germline ${germline_db_file} --stage ${processing_stage} gene_combo_config.${processing_stage}.json
                fi
                echo "$REPCALC_EXE gene_combo_config.${processing_stage}.json" >> joblist-gene
            fi
        fi
        if [[ $has_makedb_clone -eq 1 ]]; then
            if [[ $split_locus -eq 1 ]]; then
                for locus_name in $makedb_clone_locus; do
                    processing_stage=${locus_name}.igblast.makedb.allele.clone
                    if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                        python3 repcalc_create_config.py --init gene_usage_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db_file} --stage ${processing_stage} gene_usage_config.${processing_stage}.json
                    else
                        python3 repcalc_create_config.py --init gene_usage_template.json ${AIRRMetadata} --germline ${germline_db_file} --stage ${processing_stage} gene_usage_config.${processing_stage}.json
                    fi
                    echo "$REPCALC_EXE gene_usage_config.${processing_stage}.json" >> joblist-gene
        
                    if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                        python3 repcalc_create_config.py --init gene_combo_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db_file} --stage ${processing_stage} gene_combo_config.${processing_stage}.json
                    else
                        python3 repcalc_create_config.py --init gene_combo_template.json ${AIRRMetadata} --germline ${germline_db_file} --stage ${processing_stage} gene_combo_config.${processing_stage}.json
                    fi
                    echo "$REPCALC_EXE gene_combo_config.${processing_stage}.json" >> joblist-gene
                done
            else
                processing_stage=igblast.makedb.allele.clone
                if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                    python3 repcalc_create_config.py --init gene_usage_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db_file} --stage ${processing_stage} gene_usage_config.${processing_stage}.json
                else
                    python3 repcalc_create_config.py --init gene_usage_template.json ${AIRRMetadata} --germline ${germline_db_file} --stage ${processing_stage} gene_usage_config.${processing_stage}.json
                fi
                echo "$REPCALC_EXE gene_usage_config.${processing_stage}.json" >> joblist-gene
    
                if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                    python3 repcalc_create_config.py --init gene_combo_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db_file} --stage ${processing_stage} gene_combo_config.${processing_stage}.json
                else
                    python3 repcalc_create_config.py --init gene_combo_template.json ${AIRRMetadata} --germline ${germline_db_file} --stage ${processing_stage} gene_combo_config.${processing_stage}.json
                fi
                echo "$REPCALC_EXE gene_combo_config.${processing_stage}.json" >> joblist-gene
            fi
        fi
        if [[ $has_gene_clone -eq 1 ]]; then
            if [[ $split_locus -eq 1 ]]; then
                for locus_name in $gene_clone_locus; do
                    processing_stage=${locus_name}.igblast.makedb.gene.clone
                    if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                        python3 repcalc_create_config.py --init gene_usage_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db_file} --stage ${processing_stage} gene_usage_config.${processing_stage}.json
                    else
                        python3 repcalc_create_config.py --init gene_usage_template.json ${AIRRMetadata} --germline ${germline_db_file} --stage ${processing_stage} gene_usage_config.${processing_stage}.json
                    fi
                    echo "$REPCALC_EXE gene_usage_config.${processing_stage}.json" >> joblist-gene
        
                    if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                        python3 repcalc_create_config.py --init gene_combo_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db_file} --stage ${processing_stage} gene_combo_config.${processing_stage}.json
                    else
                        python3 repcalc_create_config.py --init gene_combo_template.json ${AIRRMetadata} --germline ${germline_db_file} --stage ${processing_stage} gene_combo_config.${processing_stage}.json
                    fi
                    echo "$REPCALC_EXE gene_combo_config.${processing_stage}.json" >> joblist-gene
                done
            else
                processing_stage=igblast.makedb.gene.clone
                if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                    python3 repcalc_create_config.py --init gene_usage_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db_file} --stage ${processing_stage} gene_usage_config.${processing_stage}.json
                else
                    python3 repcalc_create_config.py --init gene_usage_template.json ${AIRRMetadata} --germline ${germline_db_file} --stage ${processing_stage} gene_usage_config.${processing_stage}.json
                fi
                echo "$REPCALC_EXE gene_usage_config.${processing_stage}.json" >> joblist-gene
    
                if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                    python3 repcalc_create_config.py --init gene_combo_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db_file} --stage ${processing_stage} gene_combo_config.${processing_stage}.json
                else
                    python3 repcalc_create_config.py --init gene_combo_template.json ${AIRRMetadata} --germline ${germline_db_file} --stage ${processing_stage} gene_combo_config.${processing_stage}.json
                fi
                echo "$REPCALC_EXE gene_combo_config.${processing_stage}.json" >> joblist-gene
            fi
        fi

        # check number of jobs to be run
        export LAUNCHER_JOB_FILE=joblist-gene
        numJobs=$(cat joblist-gene | wc -l)
        export LAUNCHER_PPN=$LAUNCHER_MID_PPN
        if [ $numJobs -lt $LAUNCHER_PPN ]; then
            export LAUNCHER_PPN=$numJobs
        fi

        # run launcher
        $LAUNCHER_DIR/paramrun

        # bulk provenance for output files
        initEntryFile gene_segment_entries.csv
        initGroupEntryFile group_gene_segment_entries.csv

        # output files for repertoires
        count=0
        while [ "x${repertoires[count]}" != "x" ]
        do
            rep_id=${repertoires[count]}

            if [[ $has_igblast -eq 1 ]]; then
                orig_processing_stage=igblast
                if [[ $split_locus -eq 1 ]]; then
                    for locus_name in $igblast_locus; do
                        processing_stage=${locus_name}.igblast
                        addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.v_call.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz gene_segment_usage "${rep_id} V Gene Usage (${processing_stage})" "tsv"
                        addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.d_call.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz gene_segment_usage "${rep_id} D Gene Usage (${processing_stage})" "tsv"
                        addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.j_call.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz gene_segment_usage "${rep_id} J Gene Usage (${processing_stage})" "tsv"
                        addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.c_call.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz gene_segment_usage "${rep_id} C Gene Usage (${processing_stage})" "tsv"
                        addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.vj_combo.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz gene_segment_combos "${rep_id} VJ Gene Combo (${processing_stage})" "tsv"
                        addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.vd_combo.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz gene_segment_combos "${rep_id} VD Gene Combo (${processing_stage})" "tsv"
                        addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.vdj_combo.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz gene_segment_combos "${rep_id} VDJ Gene Combo (${processing_stage})" "tsv"
                        addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.dj_combo.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz gene_segment_combos "${rep_id} DJ Gene Combo (${processing_stage})" "tsv"
                    done
                else
                    processing_stage=igblast
                    addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.v_call.tsv ${rep_id}.${processing_stage}.airr.tsv.gz gene_segment_usage "${rep_id} V Gene Usage (${processing_stage})" "tsv"
                    addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.d_call.tsv ${rep_id}.${processing_stage}.airr.tsv.gz gene_segment_usage "${rep_id} D Gene Usage (${processing_stage})" "tsv"
                    addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.j_call.tsv ${rep_id}.${processing_stage}.airr.tsv.gz gene_segment_usage "${rep_id} J Gene Usage (${processing_stage})" "tsv"
                    addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.c_call.tsv ${rep_id}.${processing_stage}.airr.tsv.gz gene_segment_usage "${rep_id} C Gene Usage (${processing_stage})" "tsv"
                    addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.vj_combo.tsv ${rep_id}.${processing_stage}.airr.tsv.gz gene_segment_combos "${rep_id} VJ Gene Combo (${processing_stage})" "tsv"
                    addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.vd_combo.tsv ${rep_id}.${processing_stage}.airr.tsv.gz gene_segment_combos "${rep_id} VD Gene Combo (${processing_stage})" "tsv"
                    addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.vdj_combo.tsv ${rep_id}.${processing_stage}.airr.tsv.gz gene_segment_combos "${rep_id} VDJ Gene Combo (${processing_stage})" "tsv"
                    addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.dj_combo.tsv ${rep_id}.${processing_stage}.airr.tsv.gz gene_segment_combos "${rep_id} DJ Gene Combo (${processing_stage})" "tsv"
                fi
            fi

            if [[ $has_makedb -eq 1 ]]; then
                orig_processing_stage=igblast.makedb
                if [[ $split_locus -eq 1 ]]; then
                    for locus_name in $makedb_locus; do
                        processing_stage=${locus_name}.igblast.makedb
                        addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.v_call.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz gene_segment_usage "${rep_id} V Gene Usage (${processing_stage})" "tsv"
                        addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.d_call.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz gene_segment_usage "${rep_id} D Gene Usage (${processing_stage})" "tsv"
                        addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.j_call.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz gene_segment_usage "${rep_id} J Gene Usage (${processing_stage})" "tsv"
                        addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.c_call.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz gene_segment_usage "${rep_id} C Gene Usage (${processing_stage})" "tsv"
                        addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.vj_combo.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz gene_segment_combos "${rep_id} VJ Gene Combo (${processing_stage})" "tsv"
                        addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.vd_combo.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz gene_segment_combos "${rep_id} VD Gene Combo (${processing_stage})" "tsv"
                        addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.vdj_combo.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz gene_segment_combos "${rep_id} VDJ Gene Combo (${processing_stage})" "tsv"
                        addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.dj_combo.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz gene_segment_combos "${rep_id} DJ Gene Combo (${processing_stage})" "tsv"
                    done
                else
                    processing_stage=igblast.makedb
                    addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.v_call.tsv ${rep_id}.${processing_stage}.airr.tsv.gz gene_segment_usage "${rep_id} V Gene Usage (${processing_stage})" "tsv"
                    addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.d_call.tsv ${rep_id}.${processing_stage}.airr.tsv.gz gene_segment_usage "${rep_id} D Gene Usage (${processing_stage})" "tsv"
                    addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.j_call.tsv ${rep_id}.${processing_stage}.airr.tsv.gz gene_segment_usage "${rep_id} J Gene Usage (${processing_stage})" "tsv"
                    addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.c_call.tsv ${rep_id}.${processing_stage}.airr.tsv.gz gene_segment_usage "${rep_id} C Gene Usage (${processing_stage})" "tsv"
                    addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.vj_combo.tsv ${rep_id}.${processing_stage}.airr.tsv.gz gene_segment_combos "${rep_id} VJ Gene Combo (${processing_stage})" "tsv"
                    addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.vd_combo.tsv ${rep_id}.${processing_stage}.airr.tsv.gz gene_segment_combos "${rep_id} VD Gene Combo (${processing_stage})" "tsv"
                    addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.vdj_combo.tsv ${rep_id}.${processing_stage}.airr.tsv.gz gene_segment_combos "${rep_id} VDJ Gene Combo (${processing_stage})" "tsv"
                    addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.dj_combo.tsv ${rep_id}.${processing_stage}.airr.tsv.gz gene_segment_combos "${rep_id} DJ Gene Combo (${processing_stage})" "tsv"
                fi
            fi

            if [[ $has_igblast_clone -eq 1 ]]; then
                orig_processing_stage=igblast.allele.clone
                if [[ $split_locus -eq 1 ]]; then
                    for locus_name in $igblast_clone_locus; do
                        processing_stage=${locus_name}.igblast.allele.clone
                        addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.v_call.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz gene_segment_usage "${rep_id} V Gene Usage (${processing_stage})" "tsv"
                        addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.d_call.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz gene_segment_usage "${rep_id} D Gene Usage (${processing_stage})" "tsv"
                        addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.j_call.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz gene_segment_usage "${rep_id} J Gene Usage (${processing_stage})" "tsv"
                        addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.c_call.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz gene_segment_usage "${rep_id} C Gene Usage (${processing_stage})" "tsv"
                        addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.vj_combo.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz gene_segment_combos "${rep_id} VJ Gene Combo (${processing_stage})" "tsv"
                        addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.vd_combo.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz gene_segment_combos "${rep_id} VD Gene Combo (${processing_stage})" "tsv"
                        addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.vdj_combo.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz gene_segment_combos "${rep_id} VDJ Gene Combo (${processing_stage})" "tsv"
                        addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.dj_combo.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz gene_segment_combos "${rep_id} DJ Gene Combo (${processing_stage})" "tsv"
                    done
                else
                    processing_stage=igblast.allele.clone
                    addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.v_call.tsv ${rep_id}.${processing_stage}.airr.tsv.gz gene_segment_usage "${rep_id} V Gene Usage (${processing_stage})" "tsv"
                    addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.d_call.tsv ${rep_id}.${processing_stage}.airr.tsv.gz gene_segment_usage "${rep_id} D Gene Usage (${processing_stage})" "tsv"
                    addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.j_call.tsv ${rep_id}.${processing_stage}.airr.tsv.gz gene_segment_usage "${rep_id} J Gene Usage (${processing_stage})" "tsv"
                    addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.c_call.tsv ${rep_id}.${processing_stage}.airr.tsv.gz gene_segment_usage "${rep_id} C Gene Usage (${processing_stage})" "tsv"
                    addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.vj_combo.tsv ${rep_id}.${processing_stage}.airr.tsv.gz gene_segment_combos "${rep_id} VJ Gene Combo (${processing_stage})" "tsv"
                    addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.vd_combo.tsv ${rep_id}.${processing_stage}.airr.tsv.gz gene_segment_combos "${rep_id} VD Gene Combo (${processing_stage})" "tsv"
                    addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.vdj_combo.tsv ${rep_id}.${processing_stage}.airr.tsv.gz gene_segment_combos "${rep_id} VDJ Gene Combo (${processing_stage})" "tsv"
                    addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.dj_combo.tsv ${rep_id}.${processing_stage}.airr.tsv.gz gene_segment_combos "${rep_id} DJ Gene Combo (${processing_stage})" "tsv"
                fi
            fi

            if [[ $has_makedb_clone -eq 1 ]]; then
                orig_processing_stage=igblast.makedb.allele.clone
                if [[ $split_locus -eq 1 ]]; then
                    for locus_name in $makedb_clone_locus; do
                        processing_stage=${locus_name}.igblast.makedb.allele.clone
                        addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.v_call.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz gene_segment_usage "${rep_id} V Gene Usage (${processing_stage})" "tsv"
                        addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.d_call.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz gene_segment_usage "${rep_id} D Gene Usage (${processing_stage})" "tsv"
                        addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.j_call.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz gene_segment_usage "${rep_id} J Gene Usage (${processing_stage})" "tsv"
                        addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.c_call.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz gene_segment_usage "${rep_id} C Gene Usage (${processing_stage})" "tsv"
                        addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.vj_combo.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz gene_segment_combos "${rep_id} VJ Gene Combo (${processing_stage})" "tsv"
                        addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.vd_combo.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz gene_segment_combos "${rep_id} VD Gene Combo (${processing_stage})" "tsv"
                        addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.vdj_combo.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz gene_segment_combos "${rep_id} VDJ Gene Combo (${processing_stage})" "tsv"
                        addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.dj_combo.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz gene_segment_combos "${rep_id} DJ Gene Combo (${processing_stage})" "tsv"
                    done
                else
                    processing_stage=igblast.makedb.allele.clone
                    addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.v_call.tsv ${rep_id}.${processing_stage}.airr.tsv.gz gene_segment_usage "${rep_id} V Gene Usage (${processing_stage})" "tsv"
                    addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.d_call.tsv ${rep_id}.${processing_stage}.airr.tsv.gz gene_segment_usage "${rep_id} D Gene Usage (${processing_stage})" "tsv"
                    addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.j_call.tsv ${rep_id}.${processing_stage}.airr.tsv.gz gene_segment_usage "${rep_id} J Gene Usage (${processing_stage})" "tsv"
                    addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.c_call.tsv ${rep_id}.${processing_stage}.airr.tsv.gz gene_segment_usage "${rep_id} C Gene Usage (${processing_stage})" "tsv"
                    addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.vj_combo.tsv ${rep_id}.${processing_stage}.airr.tsv.gz gene_segment_combos "${rep_id} VJ Gene Combo (${processing_stage})" "tsv"
                    addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.vd_combo.tsv ${rep_id}.${processing_stage}.airr.tsv.gz gene_segment_combos "${rep_id} VD Gene Combo (${processing_stage})" "tsv"
                    addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.vdj_combo.tsv ${rep_id}.${processing_stage}.airr.tsv.gz gene_segment_combos "${rep_id} VDJ Gene Combo (${processing_stage})" "tsv"
                    addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.dj_combo.tsv ${rep_id}.${processing_stage}.airr.tsv.gz gene_segment_combos "${rep_id} DJ Gene Combo (${processing_stage})" "tsv"
                fi
            fi

            if [[ $has_gene_clone -eq 1 ]]; then
                orig_processing_stage=igblast.makedb.gene.clone
                if [[ $split_locus -eq 1 ]]; then
                    for locus_name in $gene_clone_locus; do
                        processing_stage=${locus_name}.igblast.makedb.gene.clone
                        addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.v_call.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz gene_segment_usage "${rep_id} V Gene Usage (${processing_stage})" "tsv"
                        addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.d_call.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz gene_segment_usage "${rep_id} D Gene Usage (${processing_stage})" "tsv"
                        addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.j_call.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz gene_segment_usage "${rep_id} J Gene Usage (${processing_stage})" "tsv"
                        addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.c_call.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz gene_segment_usage "${rep_id} C Gene Usage (${processing_stage})" "tsv"
                        addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.vj_combo.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz gene_segment_combos "${rep_id} VJ Gene Combo (${processing_stage})" "tsv"
                        addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.vd_combo.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz gene_segment_combos "${rep_id} VD Gene Combo (${processing_stage})" "tsv"
                        addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.vdj_combo.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz gene_segment_combos "${rep_id} VDJ Gene Combo (${processing_stage})" "tsv"
                        addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.dj_combo.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz gene_segment_combos "${rep_id} DJ Gene Combo (${processing_stage})" "tsv"
                    done
                else
                    processing_stage=igblast.makedb.gene.clone
                    addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.v_call.tsv ${rep_id}.${processing_stage}.airr.tsv.gz gene_segment_usage "${rep_id} V Gene Usage (${processing_stage})" "tsv"
                    addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.d_call.tsv ${rep_id}.${processing_stage}.airr.tsv.gz gene_segment_usage "${rep_id} D Gene Usage (${processing_stage})" "tsv"
                    addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.j_call.tsv ${rep_id}.${processing_stage}.airr.tsv.gz gene_segment_usage "${rep_id} J Gene Usage (${processing_stage})" "tsv"
                    addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.c_call.tsv ${rep_id}.${processing_stage}.airr.tsv.gz gene_segment_usage "${rep_id} C Gene Usage (${processing_stage})" "tsv"
                    addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.vj_combo.tsv ${rep_id}.${processing_stage}.airr.tsv.gz gene_segment_combos "${rep_id} VJ Gene Combo (${processing_stage})" "tsv"
                    addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.vd_combo.tsv ${rep_id}.${processing_stage}.airr.tsv.gz gene_segment_combos "${rep_id} VD Gene Combo (${processing_stage})" "tsv"
                    addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.vdj_combo.tsv ${rep_id}.${processing_stage}.airr.tsv.gz gene_segment_combos "${rep_id} VDJ Gene Combo (${processing_stage})" "tsv"
                    addEntryToFile gene_segment_entries.csv output ${rep_id}.${processing_stage}.dj_combo.tsv ${rep_id}.${processing_stage}.airr.tsv.gz gene_segment_combos "${rep_id} DJ Gene Combo (${processing_stage})" "tsv"
                fi
            fi

            count=$(( $count + 1 ))
        done

        # output files for repertoire groups
        if [ "x${RepertoireGroupMetadata}" != "x" ]; then
            grpcnt=0
            while [ "x${repertoire_groups[grpcnt]}" != "x" ]
            do
                rep_group_id=${repertoire_groups[grpcnt]}

                if [[ $has_igblast -eq 1 ]]; then
                    if [[ $split_locus -eq 1 ]]; then
                        for locus_name in $igblast_locus; do
                            processing_stage=${locus_name}.igblast
                            addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.v_call.tsv $ACTIVITY_NAME gene_segment_usage "${rep_group_id} V Gene Usage (${processing_stage})" "tsv"
                            addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.d_call.tsv $ACTIVITY_NAME gene_segment_usage "${rep_group_id} D Gene Usage (${processing_stage})" "tsv"
                            addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.j_call.tsv $ACTIVITY_NAME gene_segment_usage "${rep_group_id} J Gene Usage (${processing_stage})" "tsv"
                            addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.c_call.tsv $ACTIVITY_NAME gene_segment_usage "${rep_group_id} C Gene Usage (${processing_stage})" "tsv"
                            addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.vj_combo.tsv $ACTIVITY_NAME gene_segment_combos "${rep_group_id} VJ Gene Combo (${processing_stage})" "tsv"
                            addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.vd_combo.tsv $ACTIVITY_NAME gene_segment_combos "${rep_group_id} VD Gene Combo (${processing_stage})" "tsv"
                            addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.vdj_combo.tsv $ACTIVITY_NAME gene_segment_combos "${rep_group_id} VDJ Gene Combo (${processing_stage})" "tsv"
                            addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.dj_combo.tsv $ACTIVITY_NAME gene_segment_combos "${rep_group_id} DJ Gene Combo (${processing_stage})" "tsv"
                        done
                    else
                        processing_stage=igblast
                        addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.v_call.tsv $ACTIVITY_NAME gene_segment_usage "${rep_group_id} V Gene Usage (${processing_stage})" "tsv"
                        addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.d_call.tsv $ACTIVITY_NAME gene_segment_usage "${rep_group_id} D Gene Usage (${processing_stage})" "tsv"
                        addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.j_call.tsv $ACTIVITY_NAME gene_segment_usage "${rep_group_id} J Gene Usage (${processing_stage})" "tsv"
                        addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.c_call.tsv $ACTIVITY_NAME gene_segment_usage "${rep_group_id} C Gene Usage (${processing_stage})" "tsv"
                        addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.vj_combo.tsv $ACTIVITY_NAME gene_segment_combos "${rep_group_id} VJ Gene Combo (${processing_stage})" "tsv"
                        addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.vd_combo.tsv $ACTIVITY_NAME gene_segment_combos "${rep_group_id} VD Gene Combo (${processing_stage})" "tsv"
                        addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.vdj_combo.tsv $ACTIVITY_NAME gene_segment_combos "${rep_group_id} VDJ Gene Combo (${processing_stage})" "tsv"
                        addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.dj_combo.tsv $ACTIVITY_NAME gene_segment_combos "${rep_group_id} DJ Gene Combo (${processing_stage})" "tsv"
                    fi
                fi

                if [[ $has_makedb -eq 1 ]]; then
                    if [[ $split_locus -eq 1 ]]; then
                        for locus_name in $makedb_locus; do
                            processing_stage=${locus_name}.igblast.makedb
                            addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.v_call.tsv $ACTIVITY_NAME gene_segment_usage "${rep_group_id} V Gene Usage (${processing_stage})" "tsv"
                            addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.d_call.tsv $ACTIVITY_NAME gene_segment_usage "${rep_group_id} D Gene Usage (${processing_stage})" "tsv"
                            addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.j_call.tsv $ACTIVITY_NAME gene_segment_usage "${rep_group_id} J Gene Usage (${processing_stage})" "tsv"
                            addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.c_call.tsv $ACTIVITY_NAME gene_segment_usage "${rep_group_id} C Gene Usage (${processing_stage})" "tsv"
                            addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.vj_combo.tsv $ACTIVITY_NAME gene_segment_combos "${rep_group_id} VJ Gene Combo (${processing_stage})" "tsv"
                            addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.vd_combo.tsv $ACTIVITY_NAME gene_segment_combos "${rep_group_id} VD Gene Combo (${processing_stage})" "tsv"
                            addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.vdj_combo.tsv $ACTIVITY_NAME gene_segment_combos "${rep_group_id} VDJ Gene Combo (${processing_stage})" "tsv"
                            addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.dj_combo.tsv $ACTIVITY_NAME gene_segment_combos "${rep_group_id} DJ Gene Combo (${processing_stage})" "tsv"
                        done
                    else
                        processing_stage=igblast.makedb
                        addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.v_call.tsv $ACTIVITY_NAME gene_segment_usage "${rep_group_id} V Gene Usage (${processing_stage})" "tsv"
                        addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.d_call.tsv $ACTIVITY_NAME gene_segment_usage "${rep_group_id} D Gene Usage (${processing_stage})" "tsv"
                        addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.j_call.tsv $ACTIVITY_NAME gene_segment_usage "${rep_group_id} J Gene Usage (${processing_stage})" "tsv"
                        addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.c_call.tsv $ACTIVITY_NAME gene_segment_usage "${rep_group_id} C Gene Usage (${processing_stage})" "tsv"
                        addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.vj_combo.tsv $ACTIVITY_NAME gene_segment_combos "${rep_group_id} VJ Gene Combo (${processing_stage})" "tsv"
                        addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.vd_combo.tsv $ACTIVITY_NAME gene_segment_combos "${rep_group_id} VD Gene Combo (${processing_stage})" "tsv"
                        addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.vdj_combo.tsv $ACTIVITY_NAME gene_segment_combos "${rep_group_id} VDJ Gene Combo (${processing_stage})" "tsv"
                        addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.dj_combo.tsv $ACTIVITY_NAME gene_segment_combos "${rep_group_id} DJ Gene Combo (${processing_stage})" "tsv"
                    fi
                fi

                if [[ $has_igblast_clone -eq 1 ]]; then
                    if [[ $split_locus -eq 1 ]]; then
                        for locus_name in $igblast_clone_locus; do
                            processing_stage=${locus_name}.igblast.allele.clone
                            addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.v_call.tsv $ACTIVITY_NAME gene_segment_usage "${rep_group_id} V Gene Usage (${processing_stage})" "tsv"
                            addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.d_call.tsv $ACTIVITY_NAME gene_segment_usage "${rep_group_id} D Gene Usage (${processing_stage})" "tsv"
                            addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.j_call.tsv $ACTIVITY_NAME gene_segment_usage "${rep_group_id} J Gene Usage (${processing_stage})" "tsv"
                            addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.c_call.tsv $ACTIVITY_NAME gene_segment_usage "${rep_group_id} C Gene Usage (${processing_stage})" "tsv"
                            addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.vj_combo.tsv $ACTIVITY_NAME gene_segment_combos "${rep_group_id} VJ Gene Combo (${processing_stage})" "tsv"
                            addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.vd_combo.tsv $ACTIVITY_NAME gene_segment_combos "${rep_group_id} VD Gene Combo (${processing_stage})" "tsv"
                            addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.vdj_combo.tsv $ACTIVITY_NAME gene_segment_combos "${rep_group_id} VDJ Gene Combo (${processing_stage})" "tsv"
                            addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.dj_combo.tsv $ACTIVITY_NAME gene_segment_combos "${rep_group_id} DJ Gene Combo (${processing_stage})" "tsv"
                        done
                    else
                        processing_stage=igblast.allele.clone
                        addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.v_call.tsv $ACTIVITY_NAME gene_segment_usage "${rep_group_id} V Gene Usage (${processing_stage})" "tsv"
                        addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.d_call.tsv $ACTIVITY_NAME gene_segment_usage "${rep_group_id} D Gene Usage (${processing_stage})" "tsv"
                        addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.j_call.tsv $ACTIVITY_NAME gene_segment_usage "${rep_group_id} J Gene Usage (${processing_stage})" "tsv"
                        addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.c_call.tsv $ACTIVITY_NAME gene_segment_usage "${rep_group_id} C Gene Usage (${processing_stage})" "tsv"
                        addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.vj_combo.tsv $ACTIVITY_NAME gene_segment_combos "${rep_group_id} VJ Gene Combo (${processing_stage})" "tsv"
                        addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.vd_combo.tsv $ACTIVITY_NAME gene_segment_combos "${rep_group_id} VD Gene Combo (${processing_stage})" "tsv"
                        addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.vdj_combo.tsv $ACTIVITY_NAME gene_segment_combos "${rep_group_id} VDJ Gene Combo (${processing_stage})" "tsv"
                        addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.dj_combo.tsv $ACTIVITY_NAME gene_segment_combos "${rep_group_id} DJ Gene Combo (${processing_stage})" "tsv"
                    fi
                fi

                if [[ $has_makedb_clone -eq 1 ]]; then
                    if [[ $split_locus -eq 1 ]]; then
                        for locus_name in $makedb_clone_locus; do
                            processing_stage=${locus_name}.igblast.makedb.allele.clone
                            addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.v_call.tsv $ACTIVITY_NAME gene_segment_usage "${rep_group_id} V Gene Usage (${processing_stage})" "tsv"
                            addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.d_call.tsv $ACTIVITY_NAME gene_segment_usage "${rep_group_id} D Gene Usage (${processing_stage})" "tsv"
                            addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.j_call.tsv $ACTIVITY_NAME gene_segment_usage "${rep_group_id} J Gene Usage (${processing_stage})" "tsv"
                            addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.c_call.tsv $ACTIVITY_NAME gene_segment_usage "${rep_group_id} C Gene Usage (${processing_stage})" "tsv"
                            addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.vj_combo.tsv $ACTIVITY_NAME gene_segment_combos "${rep_group_id} VJ Gene Combo (${processing_stage})" "tsv"
                            addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.vd_combo.tsv $ACTIVITY_NAME gene_segment_combos "${rep_group_id} VD Gene Combo (${processing_stage})" "tsv"
                            addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.vdj_combo.tsv $ACTIVITY_NAME gene_segment_combos "${rep_group_id} VDJ Gene Combo (${processing_stage})" "tsv"
                            addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.dj_combo.tsv $ACTIVITY_NAME gene_segment_combos "${rep_group_id} DJ Gene Combo (${processing_stage})" "tsv"
                        done
                    else
                        processing_stage=igblast.makedb.allele.clone
                        addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.v_call.tsv $ACTIVITY_NAME gene_segment_usage "${rep_group_id} V Gene Usage (${processing_stage})" "tsv"
                        addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.d_call.tsv $ACTIVITY_NAME gene_segment_usage "${rep_group_id} D Gene Usage (${processing_stage})" "tsv"
                        addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.j_call.tsv $ACTIVITY_NAME gene_segment_usage "${rep_group_id} J Gene Usage (${processing_stage})" "tsv"
                        addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.c_call.tsv $ACTIVITY_NAME gene_segment_usage "${rep_group_id} C Gene Usage (${processing_stage})" "tsv"
                        addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.vj_combo.tsv $ACTIVITY_NAME gene_segment_combos "${rep_group_id} VJ Gene Combo (${processing_stage})" "tsv"
                        addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.vd_combo.tsv $ACTIVITY_NAME gene_segment_combos "${rep_group_id} VD Gene Combo (${processing_stage})" "tsv"
                        addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.vdj_combo.tsv $ACTIVITY_NAME gene_segment_combos "${rep_group_id} VDJ Gene Combo (${processing_stage})" "tsv"
                        addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.dj_combo.tsv $ACTIVITY_NAME gene_segment_combos "${rep_group_id} DJ Gene Combo (${processing_stage})" "tsv"
                    fi
                fi

                if [[ $has_gene_clone -eq 1 ]]; then
                    if [[ $split_locus -eq 1 ]]; then
                        for locus_name in $gene_clone_locus; do
                            processing_stage=${locus_name}.igblast.makedb.gene.clone
                            addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.v_call.tsv $ACTIVITY_NAME gene_segment_usage "${rep_group_id} V Gene Usage (${processing_stage})" "tsv"
                            addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.d_call.tsv $ACTIVITY_NAME gene_segment_usage "${rep_group_id} D Gene Usage (${processing_stage})" "tsv"
                            addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.j_call.tsv $ACTIVITY_NAME gene_segment_usage "${rep_group_id} J Gene Usage (${processing_stage})" "tsv"
                            addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.c_call.tsv $ACTIVITY_NAME gene_segment_usage "${rep_group_id} C Gene Usage (${processing_stage})" "tsv"
                            addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.vj_combo.tsv $ACTIVITY_NAME gene_segment_combos "${rep_group_id} VJ Gene Combo (${processing_stage})" "tsv"
                            addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.vd_combo.tsv $ACTIVITY_NAME gene_segment_combos "${rep_group_id} VD Gene Combo (${processing_stage})" "tsv"
                            addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.vdj_combo.tsv $ACTIVITY_NAME gene_segment_combos "${rep_group_id} VDJ Gene Combo (${processing_stage})" "tsv"
                            addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.dj_combo.tsv $ACTIVITY_NAME gene_segment_combos "${rep_group_id} DJ Gene Combo (${processing_stage})" "tsv"
                        done
                    else
                        processing_stage=igblast.makedb.gene.clone
                        addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.v_call.tsv $ACTIVITY_NAME gene_segment_usage "${rep_group_id} V Gene Usage (${processing_stage})" "tsv"
                        addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.d_call.tsv $ACTIVITY_NAME gene_segment_usage "${rep_group_id} D Gene Usage (${processing_stage})" "tsv"
                        addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.j_call.tsv $ACTIVITY_NAME gene_segment_usage "${rep_group_id} J Gene Usage (${processing_stage})" "tsv"
                        addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.c_call.tsv $ACTIVITY_NAME gene_segment_usage "${rep_group_id} C Gene Usage (${processing_stage})" "tsv"
                        addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.vj_combo.tsv $ACTIVITY_NAME gene_segment_combos "${rep_group_id} VJ Gene Combo (${processing_stage})" "tsv"
                        addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.vd_combo.tsv $ACTIVITY_NAME gene_segment_combos "${rep_group_id} VD Gene Combo (${processing_stage})" "tsv"
                        addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.vdj_combo.tsv $ACTIVITY_NAME gene_segment_combos "${rep_group_id} VDJ Gene Combo (${processing_stage})" "tsv"
                        addEntryToFile group_gene_segment_entries.csv output ${rep_group_id}.${processing_stage}.group.dj_combo.tsv $ACTIVITY_NAME gene_segment_combos "${rep_group_id} DJ Gene Combo (${processing_stage})" "tsv"
                    fi
                fi

                grpcnt=$(( $grpcnt + 1 ))
            done
        fi
        addFileEntries gene_segment_entries.csv
        addGroupFileEntries group_gene_segment_entries.csv

        # archive of data files
        zip segment_counts_data.zip *.v_call.tsv
        zip segment_counts_data.zip *.d_call.tsv
        zip segment_counts_data.zip *.j_call.tsv
        zip segment_counts_data.zip *.c_call.tsv
        wasGeneratedBy segment_counts_data.zip ${ACTIVITY_NAME} gene_segment_usage_archive "Gene Segment Usage chart data archive" "zip"

        zip segment_combos_data.zip *.vj_combo.tsv
        zip segment_combos_data.zip *.vd_combo.tsv
        zip segment_combos_data.zip *.vdj_combo.tsv
        zip segment_combos_data.zip *.dj_combo.tsv
        wasGeneratedBy segment_combos_data.zip ${ACTIVITY_NAME} gene_segment_combos_archive "Gene Segment Combinations chart data archive" "zip"
    fi

    # CDR3
    if [[ $CDR3Flag -eq 1 ]]; then
        echo "Calculate CDR3 junction length, distribution, and AA properties"

        # launcher job file
        if [ -f joblist-cdr3 ]; then
            echo "Warning: removing file 'joblist-cdr3'.  That filename is reserved." 1>&2
            rm joblist-cdr3
        fi
        touch joblist-cdr3

        if [[ $has_igblast -eq 1 ]]; then
            if [[ $split_locus -eq 1 ]]; then
                for locus_name in $igblast_locus; do
                    processing_stage=${locus_name}.igblast
                    if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                        python3 repcalc_create_config.py --init junction_length_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db_file} --stage ${processing_stage} junction_length_config.${processing_stage}.json
                    else
                        python3 repcalc_create_config.py --init junction_length_template.json ${AIRRMetadata} --germline ${germline_db_file} --stage ${processing_stage} junction_length_config.${processing_stage}.json
                    fi
                    echo "$REPCALC_EXE junction_length_config.${processing_stage}.json" >> joblist-cdr3
                done
            else
                processing_stage=igblast
                if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                    python3 repcalc_create_config.py --init junction_length_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db_file} --stage ${processing_stage} junction_length_config.${processing_stage}.json
                else
                    python3 repcalc_create_config.py --init junction_length_template.json ${AIRRMetadata} --germline ${germline_db_file} --stage ${processing_stage} junction_length_config.${processing_stage}.json
                fi
                echo "$REPCALC_EXE junction_length_config.${processing_stage}.json" >> joblist-cdr3
            fi
        fi
        if [[ $has_makedb -eq 1 ]]; then
            if [[ $split_locus -eq 1 ]]; then
                for locus_name in $makedb_locus; do
                    processing_stage=${locus_name}.igblast.makedb
                    if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                        python3 repcalc_create_config.py --init junction_length_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db_file} --stage ${processing_stage} junction_length_config.${processing_stage}.json
                    else
                        python3 repcalc_create_config.py --init junction_length_template.json ${AIRRMetadata} --germline ${germline_db_file} --stage ${processing_stage} junction_length_config.${processing_stage}.json
                    fi
                    echo "$REPCALC_EXE junction_length_config.${processing_stage}.json" >> joblist-cdr3
                done
            else
                processing_stage=igblast.makedb
                if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                    python3 repcalc_create_config.py --init junction_length_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db_file} --stage ${processing_stage} junction_length_config.${processing_stage}.json
                else
                    python3 repcalc_create_config.py --init junction_length_template.json ${AIRRMetadata} --germline ${germline_db_file} --stage ${processing_stage} junction_length_config.${processing_stage}.json
                fi
                echo "$REPCALC_EXE junction_length_config.${processing_stage}.json" >> joblist-cdr3
            fi
        fi
        if [[ $has_igblast_clone -eq 1 ]]; then
            if [[ $split_locus -eq 1 ]]; then
                for locus_name in $igblast_clone_locus; do
                    processing_stage=${locus_name}.igblast.allele.clone
                    if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                        python3 repcalc_create_config.py --init junction_length_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db_file} --stage ${processing_stage} junction_length_config.${processing_stage}.json
                    else
                        python3 repcalc_create_config.py --init junction_length_template.json ${AIRRMetadata} --germline ${germline_db_file} --stage ${processing_stage} junction_length_config.${processing_stage}.json
                    fi
                    echo "$REPCALC_EXE junction_length_config.${processing_stage}.json" >> joblist-cdr3
        
                    if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                        python3 repcalc_create_config.py --init junction_distribution_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db_file} --stage ${processing_stage} junction_distribution_config.${processing_stage}.json
                    else
                        python3 repcalc_create_config.py --init junction_distribution_template.json ${AIRRMetadata} --germline ${germline_db_file} --stage ${processing_stage} junction_distribution_config.${processing_stage}.json
                    fi
                    echo "$REPCALC_EXE junction_distribution_config.${processing_stage}.json" >> joblist-cdr3
        
                    python3 repcalc_create_config.py --init junction_shared_template.json ${AIRRMetadata} --germline ${germline_db_file} --stage ${processing_stage} junction_shared_config.${processing_stage}.json
                    echo "$REPCALC_EXE junction_shared_config.${processing_stage}.json" >> joblist-cdr3
                done
            else
                processing_stage=igblast.allele.clone
                if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                    python3 repcalc_create_config.py --init junction_length_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db_file} --stage ${processing_stage} junction_length_config.${processing_stage}.json
                else
                    python3 repcalc_create_config.py --init junction_length_template.json ${AIRRMetadata} --germline ${germline_db_file} --stage ${processing_stage} junction_length_config.${processing_stage}.json
                fi
                echo "$REPCALC_EXE junction_length_config.${processing_stage}.json" >> joblist-cdr3
    
                if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                    python3 repcalc_create_config.py --init junction_distribution_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db_file} --stage ${processing_stage} junction_distribution_config.${processing_stage}.json
                else
                    python3 repcalc_create_config.py --init junction_distribution_template.json ${AIRRMetadata} --germline ${germline_db_file} --stage ${processing_stage} junction_distribution_config.${processing_stage}.json
                fi
                echo "$REPCALC_EXE junction_distribution_config.${processing_stage}.json" >> joblist-cdr3
    
                python3 repcalc_create_config.py --init junction_shared_template.json ${AIRRMetadata} --germline ${germline_db_file} --stage ${processing_stage} junction_shared_config.${processing_stage}.json
                echo "$REPCALC_EXE junction_shared_config.${processing_stage}.json" >> joblist-cdr3
            fi
    
            processing_stage=igblast.allele.clone
            count=0
            while [ "x${repertoires[count]}" != "x" ]
            do
                rep_id=${repertoires[count]}
                echo "$RSCRIPT ./aa_properties.R -d ${rep_id}.${processing_stage}.airr.tsv -o ${rep_id}.${processing_stage}.aa_properties.airr.tsv" >> joblist-cdr3
                count=$(( $count + 1 ))
            done
        fi
        if [[ $has_makedb_clone -eq 1 ]]; then
            if [[ $split_locus -eq 1 ]]; then
                for locus_name in $makedb_clone_locus; do
                    processing_stage=${locus_name}.igblast.makedb.allele.clone
                    if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                        python3 repcalc_create_config.py --init junction_length_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db_file} --stage ${processing_stage} junction_length_config.${processing_stage}.json
                    else
                        python3 repcalc_create_config.py --init junction_length_template.json ${AIRRMetadata} --germline ${germline_db_file} --stage ${processing_stage} junction_length_config.${processing_stage}.json
                    fi
                    echo "$REPCALC_EXE junction_length_config.${processing_stage}.json" >> joblist-cdr3
        
                    if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                        python3 repcalc_create_config.py --init junction_distribution_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db_file} --stage ${processing_stage} junction_distribution_config.${processing_stage}.json
                    else
                        python3 repcalc_create_config.py --init junction_distribution_template.json ${AIRRMetadata} --germline ${germline_db_file} --stage ${processing_stage} junction_distribution_config.${processing_stage}.json
                    fi
                    echo "$REPCALC_EXE junction_distribution_config.${processing_stage}.json" >> joblist-cdr3
        
                    if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                        python3 repcalc_create_config.py --init junction_shared_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db_file} --stage ${processing_stage} junction_shared_config.${processing_stage}.json
                    else
                        python3 repcalc_create_config.py --init junction_shared_template.json ${AIRRMetadata} --germline ${germline_db_file} --stage ${processing_stage} junction_shared_config.${processing_stage}.json
                    fi
                    echo "$REPCALC_EXE junction_shared_config.${processing_stage}.json" >> joblist-cdr3
                done
            else
                processing_stage=igblast.makedb.allele.clone
                if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                    python3 repcalc_create_config.py --init junction_length_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db_file} --stage ${processing_stage} junction_length_config.${processing_stage}.json
                else
                    python3 repcalc_create_config.py --init junction_length_template.json ${AIRRMetadata} --germline ${germline_db_file} --stage ${processing_stage} junction_length_config.${processing_stage}.json
                fi
                echo "$REPCALC_EXE junction_length_config.${processing_stage}.json" >> joblist-cdr3
    
                if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                    python3 repcalc_create_config.py --init junction_distribution_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db_file} --stage ${processing_stage} junction_distribution_config.${processing_stage}.json
                else
                    python3 repcalc_create_config.py --init junction_distribution_template.json ${AIRRMetadata} --germline ${germline_db_file} --stage ${processing_stage} junction_distribution_config.${processing_stage}.json
                fi
                echo "$REPCALC_EXE junction_distribution_config.${processing_stage}.json" >> joblist-cdr3
    
                if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                    python3 repcalc_create_config.py --init junction_shared_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db_file} --stage ${processing_stage} junction_shared_config.${processing_stage}.json
                else
                    python3 repcalc_create_config.py --init junction_shared_template.json ${AIRRMetadata} --germline ${germline_db_file} --stage ${processing_stage} junction_shared_config.${processing_stage}.json
                fi
                echo "$REPCALC_EXE junction_shared_config.${processing_stage}.json" >> joblist-cdr3
            fi

            processing_stage=igblast.makedb.allele.clone
            count=0
            while [ "x${repertoires[count]}" != "x" ]
            do
                rep_id=${repertoires[count]}
                echo "$RSCRIPT ./aa_properties.R -d ${rep_id}.${processing_stage}.airr.tsv -o ${rep_id}.${processing_stage}.aa_properties.airr.tsv" >> joblist-cdr3
                count=$(( $count + 1 ))
            done
        fi
        if [[ $has_gene_clone -eq 1 ]]; then
            if [[ $split_locus -eq 1 ]]; then
                for locus_name in $gene_clone_locus; do
                    processing_stage=${locus_name}.igblast.makedb.gene.clone
                    if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                        python3 repcalc_create_config.py --init junction_length_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db_file} --stage ${processing_stage} junction_length_config.${processing_stage}.json
                    else
                        python3 repcalc_create_config.py --init junction_length_template.json ${AIRRMetadata} --germline ${germline_db_file} --stage ${processing_stage} junction_length_config.${processing_stage}.json
                    fi
                    echo "$REPCALC_EXE junction_length_config.${processing_stage}.json" >> joblist-cdr3
        
                    if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                        python3 repcalc_create_config.py --init junction_distribution_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db_file} --stage ${processing_stage} junction_distribution_config.${processing_stage}.json
                    else
                        python3 repcalc_create_config.py --init junction_distribution_template.json ${AIRRMetadata} --germline ${germline_db_file} --stage ${processing_stage} junction_distribution_config.${processing_stage}.json
                    fi
                    echo "$REPCALC_EXE junction_distribution_config.${processing_stage}.json" >> joblist-cdr3
        
                    if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                        python3 repcalc_create_config.py --init junction_shared_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db_file} --stage ${processing_stage} junction_shared_config.${processing_stage}.json
                    else
                        python3 repcalc_create_config.py --init junction_shared_template.json ${AIRRMetadata} --germline ${germline_db_file} --stage ${processing_stage} junction_shared_config.${processing_stage}.json
                    fi
                    echo "$REPCALC_EXE junction_shared_config.${processing_stage}.json" >> joblist-cdr3
                done
            else
                processing_stage=igblast.makedb.gene.clone
                if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                    python3 repcalc_create_config.py --init junction_length_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db_file} --stage ${processing_stage} junction_length_config.${processing_stage}.json
                else
                    python3 repcalc_create_config.py --init junction_length_template.json ${AIRRMetadata} --germline ${germline_db_file} --stage ${processing_stage} junction_length_config.${processing_stage}.json
                fi
                echo "$REPCALC_EXE junction_length_config.${processing_stage}.json" >> joblist-cdr3
    
                if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                    python3 repcalc_create_config.py --init junction_distribution_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db_file} --stage ${processing_stage} junction_distribution_config.${processing_stage}.json
                else
                    python3 repcalc_create_config.py --init junction_distribution_template.json ${AIRRMetadata} --germline ${germline_db_file} --stage ${processing_stage} junction_distribution_config.${processing_stage}.json
                fi
                echo "$REPCALC_EXE junction_distribution_config.${processing_stage}.json" >> joblist-cdr3
    
                if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                    python3 repcalc_create_config.py --init junction_shared_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db_file} --stage ${processing_stage} junction_shared_config.${processing_stage}.json
                else
                    python3 repcalc_create_config.py --init junction_shared_template.json ${AIRRMetadata} --germline ${germline_db_file} --stage ${processing_stage} junction_shared_config.${processing_stage}.json
                fi
                echo "$REPCALC_EXE junction_shared_config.${processing_stage}.json" >> joblist-cdr3
            fi

            processing_stage=igblast.makedb.gene.clone
            count=0
            while [ "x${repertoires[count]}" != "x" ]
            do
                rep_id=${repertoires[count]}
                echo "$RSCRIPT ./aa_properties.R -d ${rep_id}.${processing_stage}.airr.tsv -o ${rep_id}.${processing_stage}.aa_properties.airr.tsv" >> joblist-cdr3
                count=$(( $count + 1 ))
            done
        fi

        # check number of jobs to be run
        export LAUNCHER_JOB_FILE=joblist-cdr3
        numJobs=$(cat joblist-cdr3 | wc -l)
        export LAUNCHER_PPN=$LAUNCHER_MID_PPN
        if [ $numJobs -lt $LAUNCHER_PPN ]; then
            export LAUNCHER_PPN=$numJobs
        fi

        # run launcher
        $LAUNCHER_DIR/paramrun

        # bulk provenance for output files
        initEntryFile cdr3_entries.csv
        initGroupEntryFile group_cdr3_entries.csv

        # repertoires
        count=0
        while [ "x${repertoires[count]}" != "x" ]
        do
            rep_id=${repertoires[count]}

            if [[ $has_igblast -eq 1 ]]; then
                orig_processing_stage=igblast
                if [[ $split_locus -eq 1 ]]; then
                    for locus_name in $igblast_locus; do
                        processing_stage=${locus_name}.igblast
                        addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.junction_aa_length.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction AA Length (${processing_stage})" "tsv"
                        addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.junction_aa_wo_duplicates_length.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction AA Length (${processing_stage})" "tsv"
                        addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.junction_nucleotide_length.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction NT Length (${processing_stage})" "tsv"
                        addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.junction_nucleotide_wo_duplicates_length.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction NT Length (${processing_stage})" "tsv"
                        addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.productive.junction_aa_length.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction AA Length (productive, ${processing_stage})" "tsv"
                        addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.productive.junction_aa_wo_duplicates_length.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction AA Length (productive, ${processing_stage})" "tsv"
                        addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.productive.junction_nucleotide_length.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction NT Length (productive, ${processing_stage})" "tsv"
                        addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.productive.junction_nucleotide_wo_duplicates_length.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction NT Length (productive, ${processing_stage})" "tsv"
                    done
                else
                    processing_stage=igblast
                    addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.junction_aa_length.tsv ${rep_id}.${processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction AA Length (${processing_stage})" "tsv"
                    addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.junction_aa_wo_duplicates_length.tsv ${rep_id}.${processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction AA Length (${processing_stage})" "tsv"
                    addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.junction_nucleotide_length.tsv ${rep_id}.${processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction NT Length (${processing_stage})" "tsv"
                    addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.junction_nucleotide_wo_duplicates_length.tsv ${rep_id}.${processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction NT Length (${processing_stage})" "tsv"
                    addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.productive.junction_aa_length.tsv ${rep_id}.${processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction AA Length (productive, ${processing_stage})" "tsv"
                    addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.productive.junction_aa_wo_duplicates_length.tsv ${rep_id}.${processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction AA Length (productive, ${processing_stage})" "tsv"
                    addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.productive.junction_nucleotide_length.tsv ${rep_id}.${processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction NT Length (productive, ${processing_stage})" "tsv"
                    addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.productive.junction_nucleotide_wo_duplicates_length.tsv ${rep_id}.${processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction NT Length (productive, ${processing_stage})" "tsv"
                fi
            fi

            if [[ $has_makedb -eq 1 ]]; then
                orig_processing_stage=igblast.makedb
                if [[ $split_locus -eq 1 ]]; then
                    for locus_name in $makedb_locus; do
                        processing_stage=${locus_name}.igblast.makedb
                        addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.junction_aa_length.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction AA Length (${processing_stage})" "tsv"
                        addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.junction_aa_wo_duplicates_length.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction AA Length (${processing_stage})" "tsv"
                        addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.junction_nucleotide_length.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction NT Length (${processing_stage})" "tsv"
                        addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.junction_nucleotide_wo_duplicates_length.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction NT Length (${processing_stage})" "tsv"
                        addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.productive.junction_aa_length.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction AA Length (productive, ${processing_stage})" "tsv"
                        addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.productive.junction_aa_wo_duplicates_length.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction AA Length (productive, ${processing_stage})" "tsv"
                        addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.productive.junction_nucleotide_length.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction NT Length (productive, ${processing_stage})" "tsv"
                        addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.productive.junction_nucleotide_wo_duplicates_length.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction NT Length (productive, ${processing_stage})" "tsv"
                    done
                else
                    processing_stage=igblast.makedb
                    addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.junction_aa_length.tsv ${rep_id}.${processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction AA Length (${processing_stage})" "tsv"
                    addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.junction_aa_wo_duplicates_length.tsv ${rep_id}.${processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction AA Length (${processing_stage})" "tsv"
                    addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.junction_nucleotide_length.tsv ${rep_id}.${processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction NT Length (${processing_stage})" "tsv"
                    addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.junction_nucleotide_wo_duplicates_length.tsv ${rep_id}.${processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction NT Length (${processing_stage})" "tsv"
                    addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.productive.junction_aa_length.tsv ${rep_id}.${processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction AA Length (productive, ${processing_stage})" "tsv"
                    addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.productive.junction_aa_wo_duplicates_length.tsv ${rep_id}.${processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction AA Length (productive, ${processing_stage})" "tsv"
                    addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.productive.junction_nucleotide_length.tsv ${rep_id}.${processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction NT Length (productive, ${processing_stage})" "tsv"
                    addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.productive.junction_nucleotide_wo_duplicates_length.tsv ${rep_id}.${processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction NT Length (productive, ${processing_stage})" "tsv"
                fi
            fi

            if [[ $has_igblast_clone -eq 1 ]]; then
                orig_processing_stage=igblast.allele.clone
                if [[ $split_locus -eq 1 ]]; then
                    for locus_name in $igblast_clone_locus; do
                        processing_stage=${locus_name}.igblast.allele.clone
                        addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.junction_aa_length.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction AA Length (${processing_stage})" "tsv"
                        addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.junction_aa_wo_duplicates_length.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction AA Length (${processing_stage})" "tsv"
                        addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.junction_nucleotide_length.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction NT Length (${processing_stage})" "tsv"
                        addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.junction_nucleotide_wo_duplicates_length.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction NT Length (${processing_stage})" "tsv"
                        addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.productive.junction_aa_length.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction AA Length (productive, ${processing_stage})" "tsv"
                        addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.productive.junction_aa_wo_duplicates_length.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction AA Length (productive, ${processing_stage})" "tsv"
                        addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.productive.junction_nucleotide_length.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction NT Length (productive, ${processing_stage})" "tsv"
                        addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.productive.junction_nucleotide_wo_duplicates_length.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction NT Length (productive, ${processing_stage})" "tsv"
                    done
                else
                    processing_stage=igblast.allele.clone
                    addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.junction_aa_length.tsv ${rep_id}.${processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction AA Length (${processing_stage})" "tsv"
                    addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.junction_aa_wo_duplicates_length.tsv ${rep_id}.${processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction AA Length (${processing_stage})" "tsv"
                    addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.junction_nucleotide_length.tsv ${rep_id}.${processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction NT Length (${processing_stage})" "tsv"
                    addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.junction_nucleotide_wo_duplicates_length.tsv ${rep_id}.${processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction NT Length (${processing_stage})" "tsv"
                    addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.productive.junction_aa_length.tsv ${rep_id}.${processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction AA Length (productive, ${processing_stage})" "tsv"
                    addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.productive.junction_aa_wo_duplicates_length.tsv ${rep_id}.${processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction AA Length (productive, ${processing_stage})" "tsv"
                    addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.productive.junction_nucleotide_length.tsv ${rep_id}.${processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction NT Length (productive, ${processing_stage})" "tsv"
                    addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.productive.junction_nucleotide_wo_duplicates_length.tsv ${rep_id}.${processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction NT Length (productive, ${processing_stage})" "tsv"
                fi

                processing_stage=igblast.allele.clone
                gzipFile ${rep_id}.${processing_stage}.aa_properties.airr.tsv
                addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.aa_properties.airr.tsv.gz ${rep_id}.${processing_stage}.airr.tsv.gz aa_properties "${rep_id} CDR3 AA Properties (${processing_stage})" "tsv"
            fi

            if [[ $has_makedb_clone -eq 1 ]]; then
                orig_processing_stage=igblast.makedb.allele.clone
                if [[ $split_locus -eq 1 ]]; then
                    for locus_name in $makedb_clone_locus; do
                        processing_stage=${locus_name}.igblast.makedb.allele.clone
                        addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.junction_aa_length.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction AA Length (${processing_stage})" "tsv"
                        addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.junction_aa_wo_duplicates_length.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction AA Length (${processing_stage})" "tsv"
                        addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.junction_nucleotide_length.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction NT Length (${processing_stage})" "tsv"
                        addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.junction_nucleotide_wo_duplicates_length.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction NT Length (${processing_stage})" "tsv"
                        addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.productive.junction_aa_length.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction AA Length (productive, ${processing_stage})" "tsv"
                        addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.productive.junction_aa_wo_duplicates_length.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction AA Length (productive, ${processing_stage})" "tsv"
                        addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.productive.junction_nucleotide_length.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction NT Length (productive, ${processing_stage})" "tsv"
                        addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.productive.junction_nucleotide_wo_duplicates_length.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction NT Length (productive, ${processing_stage})" "tsv"
                    done
                else
                    processing_stage=igblast.makedb.allele.clone
                    addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.junction_aa_length.tsv ${rep_id}.${processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction AA Length (${processing_stage})" "tsv"
                    addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.junction_aa_wo_duplicates_length.tsv ${rep_id}.${processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction AA Length (${processing_stage})" "tsv"
                    addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.junction_nucleotide_length.tsv ${rep_id}.${processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction NT Length (${processing_stage})" "tsv"
                    addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.junction_nucleotide_wo_duplicates_length.tsv ${rep_id}.${processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction NT Length (${processing_stage})" "tsv"
                    addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.productive.junction_aa_length.tsv ${rep_id}.${processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction AA Length (productive, ${processing_stage})" "tsv"
                    addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.productive.junction_aa_wo_duplicates_length.tsv ${rep_id}.${processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction AA Length (productive, ${processing_stage})" "tsv"
                    addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.productive.junction_nucleotide_length.tsv ${rep_id}.${processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction NT Length (productive, ${processing_stage})" "tsv"
                    addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.productive.junction_nucleotide_wo_duplicates_length.tsv ${rep_id}.${processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction NT Length (productive, ${processing_stage})" "tsv"
                fi

                processing_stage=igblast.makedb.allele.clone
                gzipFile ${rep_id}.${processing_stage}.aa_properties.airr.tsv
                addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.aa_properties.airr.tsv.gz ${rep_id}.${processing_stage}.airr.tsv.gz aa_properties "${rep_id} CDR3 AA Properties (${processing_stage})" "tsv"
            fi

            if [[ $has_gene_clone -eq 1 ]]; then
                orig_processing_stage=igblast.makedb.gene.clone
                if [[ $split_locus -eq 1 ]]; then
                    for locus_name in $gene_clone_locus; do
                        processing_stage=${locus_name}.igblast.makedb.gene.clone
                        addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.junction_aa_length.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction AA Length (${processing_stage})" "tsv"
                        addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.junction_aa_wo_duplicates_length.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction AA Length (${processing_stage})" "tsv"
                        addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.junction_nucleotide_length.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction NT Length (${processing_stage})" "tsv"
                        addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.junction_nucleotide_wo_duplicates_length.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction NT Length (${processing_stage})" "tsv"
                        addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.productive.junction_aa_length.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction AA Length (productive, ${processing_stage})" "tsv"
                        addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.productive.junction_aa_wo_duplicates_length.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction AA Length (productive, ${processing_stage})" "tsv"
                        addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.productive.junction_nucleotide_length.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction NT Length (productive, ${processing_stage})" "tsv"
                        addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.productive.junction_nucleotide_wo_duplicates_length.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction NT Length (productive, ${processing_stage})" "tsv"
                    done
                else
                    processing_stage=igblast.makedb.gene.clone
                    addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.junction_aa_length.tsv ${rep_id}.${processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction AA Length (${processing_stage})" "tsv"
                    addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.junction_aa_wo_duplicates_length.tsv ${rep_id}.${processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction AA Length (${processing_stage})" "tsv"
                    addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.junction_nucleotide_length.tsv ${rep_id}.${processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction NT Length (${processing_stage})" "tsv"
                    addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.junction_nucleotide_wo_duplicates_length.tsv ${rep_id}.${processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction NT Length (${processing_stage})" "tsv"
                    addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.productive.junction_aa_length.tsv ${rep_id}.${processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction AA Length (productive, ${processing_stage})" "tsv"
                    addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.productive.junction_aa_wo_duplicates_length.tsv ${rep_id}.${processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction AA Length (productive, ${processing_stage})" "tsv"
                    addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.productive.junction_nucleotide_length.tsv ${rep_id}.${processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction NT Length (productive, ${processing_stage})" "tsv"
                    addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.productive.junction_nucleotide_wo_duplicates_length.tsv ${rep_id}.${processing_stage}.airr.tsv.gz cdr3_length "${rep_id} Junction NT Length (productive, ${processing_stage})" "tsv"
                fi

                processing_stage=igblast.makedb.gene.clone
                gzipFile ${rep_id}.${processing_stage}.aa_properties.airr.tsv
                addEntryToFile cdr3_entries.csv output ${rep_id}.${processing_stage}.aa_properties.airr.tsv.gz ${rep_id}.${processing_stage}.airr.tsv.gz aa_properties "${rep_id} CDR3 AA Properties (${processing_stage})" "tsv"
            fi

            count=$(( $count + 1 ))
        done

        # repertoire groups
        if [ "x${RepertoireGroupMetadata}" != "x" ]; then
            grpcnt=0
            while [ "x${repertoire_groups[grpcnt]}" != "x" ]
            do
                rep_group_id=${repertoire_groups[grpcnt]}

                if [[ $has_igblast -eq 1 ]]; then
                    if [[ $split_locus -eq 1 ]]; then
                        for locus_name in $igblast_locus; do
                            processing_stage=${locus_name}.igblast
                            addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.junction_aa_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction AA Length (${processing_stage})" "tsv"
                            addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.junction_aa_wo_duplicates_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction AA Length (${processing_stage})" "tsv"
                            addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.junction_nucleotide_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction NT Length (${processing_stage})" "tsv"
                            addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.junction_nucleotide_wo_duplicates_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction NT Length (${processing_stage})" "tsv"
                            addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.productive.junction_aa_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction AA Length (productive, ${processing_stage})" "tsv"
                            addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.productive.junction_aa_wo_duplicates_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction AA Length (productive, ${processing_stage})" "tsv"
                            addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.productive.junction_nucleotide_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction NT Length (productive, ${processing_stage})" "tsv"
                            addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.productive.junction_nucleotide_wo_duplicates_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction NT Length (productive, ${processing_stage})" "tsv"
                        done
                    else
                        processing_stage=igblast
                        addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.junction_aa_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction AA Length (${processing_stage})" "tsv"
                        addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.junction_aa_wo_duplicates_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction AA Length (${processing_stage})" "tsv"
                        addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.junction_nucleotide_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction NT Length (${processing_stage})" "tsv"
                        addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.junction_nucleotide_wo_duplicates_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction NT Length (${processing_stage})" "tsv"
                        addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.productive.junction_aa_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction AA Length (productive, ${processing_stage})" "tsv"
                        addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.productive.junction_aa_wo_duplicates_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction AA Length (productive, ${processing_stage})" "tsv"
                        addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.productive.junction_nucleotide_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction NT Length (productive, ${processing_stage})" "tsv"
                        addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.productive.junction_nucleotide_wo_duplicates_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction NT Length (productive, ${processing_stage})" "tsv"
                    fi
                fi

                if [[ $has_makedb -eq 1 ]]; then
                    if [[ $split_locus -eq 1 ]]; then
                        for locus_name in $makedb_locus; do
                            processing_stage=${locus_name}.igblast.makedb
                            addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.junction_aa_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction AA Length (${processing_stage})" "tsv"
                            addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.junction_aa_wo_duplicates_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction AA Length (${processing_stage})" "tsv"
                            addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.junction_nucleotide_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction NT Length (${processing_stage})" "tsv"
                            addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.junction_nucleotide_wo_duplicates_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction NT Length (${processing_stage})" "tsv"
                            addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.productive.junction_aa_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction AA Length (productive, ${processing_stage})" "tsv"
                            addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.productive.junction_aa_wo_duplicates_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction AA Length (productive, ${processing_stage})" "tsv"
                            addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.productive.junction_nucleotide_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction NT Length (productive, ${processing_stage})" "tsv"
                            addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.productive.junction_nucleotide_wo_duplicates_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction NT Length (productive, ${processing_stage})" "tsv"
                        done
                    else
                        processing_stage=igblast.makedb
                        addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.junction_aa_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction AA Length (${processing_stage})" "tsv"
                        addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.junction_aa_wo_duplicates_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction AA Length (${processing_stage})" "tsv"
                        addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.junction_nucleotide_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction NT Length (${processing_stage})" "tsv"
                        addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.junction_nucleotide_wo_duplicates_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction NT Length (${processing_stage})" "tsv"
                        addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.productive.junction_aa_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction AA Length (productive, ${processing_stage})" "tsv"
                        addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.productive.junction_aa_wo_duplicates_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction AA Length (productive, ${processing_stage})" "tsv"
                        addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.productive.junction_nucleotide_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction NT Length (productive, ${processing_stage})" "tsv"
                        addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.productive.junction_nucleotide_wo_duplicates_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction NT Length (productive, ${processing_stage})" "tsv"
                    fi
                fi

                if [[ $has_igblast_clone -eq 1 ]]; then
                    if [[ $split_locus -eq 1 ]]; then
                        for locus_name in $igblast_clone_locus; do
                            processing_stage=${locus_name}.igblast.allele.clone
                            addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.junction_aa_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction AA Length (${processing_stage})" "tsv"
                            addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.junction_aa_wo_duplicates_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction AA Length (${processing_stage})" "tsv"
                            addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.junction_nucleotide_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction NT Length (${processing_stage})" "tsv"
                            addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.junction_nucleotide_wo_duplicates_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction NT Length (${processing_stage})" "tsv"
                            addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.productive.junction_aa_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction AA Length (productive, ${processing_stage})" "tsv"
                            addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.productive.junction_aa_wo_duplicates_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction AA Length (productive, ${processing_stage})" "tsv"
                            addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.productive.junction_nucleotide_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction NT Length (productive, ${processing_stage})" "tsv"
                            addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.productive.junction_nucleotide_wo_duplicates_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction NT Length (productive, ${processing_stage})" "tsv"
                        done
                    else
                        processing_stage=igblast.allele.clone
                        addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.junction_aa_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction AA Length (${processing_stage})" "tsv"
                        addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.junction_aa_wo_duplicates_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction AA Length (${processing_stage})" "tsv"
                        addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.junction_nucleotide_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction NT Length (${processing_stage})" "tsv"
                        addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.junction_nucleotide_wo_duplicates_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction NT Length (${processing_stage})" "tsv"
                        addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.productive.junction_aa_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction AA Length (productive, ${processing_stage})" "tsv"
                        addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.productive.junction_aa_wo_duplicates_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction AA Length (productive, ${processing_stage})" "tsv"
                        addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.productive.junction_nucleotide_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction NT Length (productive, ${processing_stage})" "tsv"
                        addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.productive.junction_nucleotide_wo_duplicates_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction NT Length (productive, ${processing_stage})" "tsv"
                    fi
                fi

                if [[ $has_makedb_clone -eq 1 ]]; then
                    if [[ $split_locus -eq 1 ]]; then
                        for locus_name in $makedb_clone_locus; do
                            processing_stage=${locus_name}.igblast.makedb.allele.clone
                            addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.junction_aa_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction AA Length (${processing_stage})" "tsv"
                            addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.junction_aa_wo_duplicates_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction AA Length (${processing_stage})" "tsv"
                            addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.junction_nucleotide_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction NT Length (${processing_stage})" "tsv"
                            addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.junction_nucleotide_wo_duplicates_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction NT Length (${processing_stage})" "tsv"
                            addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.productive.junction_aa_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction AA Length (productive, ${processing_stage})" "tsv"
                            addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.productive.junction_aa_wo_duplicates_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction AA Length (productive, ${processing_stage})" "tsv"
                            addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.productive.junction_nucleotide_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction NT Length (productive, ${processing_stage})" "tsv"
                            addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.productive.junction_nucleotide_wo_duplicates_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction NT Length (productive, ${processing_stage})" "tsv"
                        done
                    else
                        processing_stage=igblast.makedb.allele.clone
                        addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.junction_aa_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction AA Length (${processing_stage})" "tsv"
                        addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.junction_aa_wo_duplicates_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction AA Length (${processing_stage})" "tsv"
                        addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.junction_nucleotide_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction NT Length (${processing_stage})" "tsv"
                        addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.junction_nucleotide_wo_duplicates_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction NT Length (${processing_stage})" "tsv"
                        addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.productive.junction_aa_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction AA Length (productive, ${processing_stage})" "tsv"
                        addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.productive.junction_aa_wo_duplicates_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction AA Length (productive, ${processing_stage})" "tsv"
                        addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.productive.junction_nucleotide_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction NT Length (productive, ${processing_stage})" "tsv"
                        addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.productive.junction_nucleotide_wo_duplicates_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction NT Length (productive, ${processing_stage})" "tsv"
                    fi
                fi

                if [[ $has_gene_clone -eq 1 ]]; then
                    if [[ $split_locus -eq 1 ]]; then
                        for locus_name in $gene_clone_locus; do
                            processing_stage=${locus_name}.igblast.makedb.gene.clone
                            addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.junction_aa_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction AA Length (${processing_stage})" "tsv"
                            addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.junction_aa_wo_duplicates_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction AA Length (${processing_stage})" "tsv"
                            addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.junction_nucleotide_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction NT Length (${processing_stage})" "tsv"
                            addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.junction_nucleotide_wo_duplicates_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction NT Length (${processing_stage})" "tsv"
                            addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.productive.junction_aa_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction AA Length (productive, ${processing_stage})" "tsv"
                            addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.productive.junction_aa_wo_duplicates_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction AA Length (productive, ${processing_stage})" "tsv"
                            addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.productive.junction_nucleotide_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction NT Length (productive, ${processing_stage})" "tsv"
                            addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.productive.junction_nucleotide_wo_duplicates_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction NT Length (productive, ${processing_stage})" "tsv"
                        done
                    else
                        processing_stage=igblast.makedb.gene.clone
                        addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.junction_aa_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction AA Length (${processing_stage})" "tsv"
                        addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.junction_aa_wo_duplicates_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction AA Length (${processing_stage})" "tsv"
                        addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.junction_nucleotide_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction NT Length (${processing_stage})" "tsv"
                        addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.junction_nucleotide_wo_duplicates_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction NT Length (${processing_stage})" "tsv"
                        addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.productive.junction_aa_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction AA Length (productive, ${processing_stage})" "tsv"
                        addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.productive.junction_aa_wo_duplicates_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction AA Length (productive, ${processing_stage})" "tsv"
                        addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.productive.junction_nucleotide_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction NT Length (productive, ${processing_stage})" "tsv"
                        addEntryToFile group_cdr3_entries.csv output ${rep_group_id}.${processing_stage}.productive.junction_nucleotide_wo_duplicates_length.tsv $ACTIVITY_NAME cdr3_length "${rep_group_id} Junction NT Length (productive, ${processing_stage})" "tsv"
                    fi
                fi

                grpcnt=$(( $grpcnt + 1 ))
            done
        fi
        addFileEntries cdr3_entries.csv
        addGroupFileEntries group_cdr3_entries.csv

        # junction comparison
        if [[ $has_makedb_clone -eq 1 ]]; then
            if [[ $split_locus -eq 1 ]]; then
                for locus_name in $makedb_clone_locus; do
                    processing_stage=${locus_name}.igblast.makedb.allele.clone
                    if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                        python3 repcalc_create_config.py --init junction_compare_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db_file} --stage ${processing_stage} junction_compare_config.${processing_stage}.json
                        $REPCALC_EXE junction_compare_config.${processing_stage}.json
                    fi
                done
            else
                processing_stage=igblast.makedb.allele.clone
                if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                    python3 repcalc_create_config.py --init junction_compare_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db_file} --stage ${processing_stage} junction_compare_config.${processing_stage}.json
                    $REPCALC_EXE junction_compare_config.${processing_stage}.json
                fi
            fi
        fi

        # archive of data files
        zip cdr3_length_data.zip *.junction_aa_length.tsv
        zip cdr3_length_data.zip *.junction_aa_wo_duplicates_length.tsv
        zip cdr3_length_data.zip *.junction_nucleotide_length.tsv
        zip cdr3_length_data.zip *.junction_nucleotide_wo_duplicates_length.tsv
        wasGeneratedBy cdr3_length_data.zip ${ACTIVITY_NAME} cdr3_length_archive "Archive of CDR3 Length Histogram chart data" "zip"

        zip cdr3_sharing_data.zip *cdr3_*_sharing.tsv
        wasGeneratedBy cdr3_sharing_data.zip ${ACTIVITY_NAME} cdr3_sharing_archive "Archive of Shared/Unique CDR3 chart data" "zip"
        rm -r *cdr3_*_sharing.tsv

        zip cdr3_distribution_data.zip *distribution.tsv
        wasGeneratedBy cdr3_distribution_data.zip ${ACTIVITY_NAME} cdr3_distribution_archive "Archive of CDR3 Distribution chart data" "zip"
        rm -r *distribution.tsv
    fi

    # Clonal analysis
    if [[ $ClonalFlag -eq 1 ]]; then
        echo "Calculate clonal abundance"

        # launcher job file
        if [ -f joblist-clones ]; then
            echo "Warning: removing file 'joblist-clones'.  That filename is reserved." 1>&2
            rm joblist-clones
        fi
        touch joblist-clones

        if [[ $has_igblast_clone -eq 1 ]]; then
            if [[ $split_locus -eq 1 ]]; then
                for locus_name in $igblast_clone_locus; do
                    processing_stage=${locus_name}.igblast.allele.clone
                    fileList=($(ls *.${processing_stage}.airr.tsv))
        
                    count=0
                    while [ "x${fileList[count]}" != "x" ]
                    do
                        file=${fileList[count]}
                        # assume and strip airr.tsv
                        fileOutname="${file##*/}"
                        fileBasename="${fileOutname%.*}"
                        fileBasename="${fileBasename%.*}"
        
                        echo "$RSCRIPT clonal_abundance.R -d $file -o $fileBasename" >> joblist-clones
        
                        count=$(( $count + 1 ))
                    done
                done
            else
                processing_stage=igblast.allele.clone
                fileList=($(ls *.${processing_stage}.airr.tsv))
    
                count=0
                while [ "x${fileList[count]}" != "x" ]
                do
                    file=${fileList[count]}
                    # assume and strip airr.tsv
                    fileOutname="${file##*/}"
                    fileBasename="${fileOutname%.*}"
                    fileBasename="${fileBasename%.*}"
    
                    echo "$RSCRIPT clonal_abundance.R -d $file -o $fileBasename" >> joblist-clones
    
                    count=$(( $count + 1 ))
                done
            fi
        fi

        if [[ $has_makedb_clone -eq 1 ]]; then
            if [[ $split_locus -eq 1 ]]; then
                for locus_name in $makedb_clone_locus; do
                    processing_stage=${locus_name}.igblast.makedb.allele.clone
                    fileList=($(ls *.${processing_stage}.airr.tsv))
        
                    count=0
                    while [ "x${fileList[count]}" != "x" ]
                    do
                        file=${fileList[count]}
                        # assume and strip airr.tsv
                        fileOutname="${file##*/}"
                        fileBasename="${fileOutname%.*}"
                        fileBasename="${fileBasename%.*}"
        
                        echo "$RSCRIPT clonal_abundance.R -d $file -o $fileBasename" >> joblist-clones
        
                        count=$(( $count + 1 ))
                    done
                done
            else
                processing_stage=igblast.makedb.allele.clone
                fileList=($(ls *.${processing_stage}.airr.tsv))
    
                count=0
                while [ "x${fileList[count]}" != "x" ]
                do
                    file=${fileList[count]}
                    # assume and strip airr.tsv
                    fileOutname="${file##*/}"
                    fileBasename="${fileOutname%.*}"
                    fileBasename="${fileBasename%.*}"
    
                    echo "$RSCRIPT clonal_abundance.R -d $file -o $fileBasename" >> joblist-clones
    
                    count=$(( $count + 1 ))
                done
            fi
        fi

        if [[ $has_gene_clone -eq 1 ]]; then
            if [[ $split_locus -eq 1 ]]; then
                for locus_name in $gene_clone_locus; do
                    processing_stage=${locus_name}.igblast.makedb.gene.clone
                    fileList=($(ls *.${processing_stage}.airr.tsv))
        
                    count=0
                    while [ "x${fileList[count]}" != "x" ]
                    do
                        file=${fileList[count]}
                        # assume and strip airr.tsv
                        fileOutname="${file##*/}"
                        fileBasename="${fileOutname%.*}"
                        fileBasename="${fileBasename%.*}"
        
                        echo "$RSCRIPT clonal_abundance.R -d $file -o $fileBasename" >> joblist-clones
        
                        count=$(( $count + 1 ))
                    done
                done
            else
                processing_stage=igblast.makedb.gene.clone
                fileList=($(ls *.${processing_stage}.airr.tsv))
    
                count=0
                while [ "x${fileList[count]}" != "x" ]
                do
                    file=${fileList[count]}
                    # assume and strip airr.tsv
                    fileOutname="${file##*/}"
                    fileBasename="${fileOutname%.*}"
                    fileBasename="${fileBasename%.*}"
    
                    echo "$RSCRIPT clonal_abundance.R -d $file -o $fileBasename" >> joblist-clones
    
                    count=$(( $count + 1 ))
                done
            fi
        fi

        # check number of jobs to be run
        export LAUNCHER_JOB_FILE=joblist-clones
        numJobs=$(cat joblist-clones | wc -l)
        export LAUNCHER_PPN=$LAUNCHER_MID_PPN
        if [ $numJobs -lt $LAUNCHER_PPN ]; then
            export LAUNCHER_PPN=$numJobs
        fi

        # run launcher
        $LAUNCHER_DIR/paramrun

        # bulk provenance for output files
        initEntryFile clone_entries.csv

        # repertoires
        count=0
        while [ "x${repertoires[count]}" != "x" ]
        do
            rep_id=${repertoires[count]}
            group=${rep_id//./_}

            if [[ $has_igblast_clone -eq 1 ]]; then
                orig_processing_stage=igblast.allele.clone
                if [[ $split_locus -eq 1 ]]; then
                    for locus_name in $igblast_clone_locus; do
                        processing_stage=${locus_name}.igblast.allele.clone
                        addEntryToFile clone_entries.csv output ${rep_id}.${processing_stage}.abundance.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz clonal_abundance "${rep_id} Clonal Abundance (${processing_stage})" "tsv"
                        addEntryToFile clone_entries.csv output ${rep_id}.${processing_stage}.count.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz clonal_abundance "${rep_id} Clone Counts (${processing_stage})" "tsv"
                    done
                else
                    processing_stage=igblast.allele.clone
                    addEntryToFile clone_entries.csv output ${rep_id}.${processing_stage}.abundance.tsv ${rep_id}.${processing_stage}.airr.tsv.gz clonal_abundance "${rep_id} Clonal Abundance (${processing_stage})" "tsv"
                    addEntryToFile clone_entries.csv output ${rep_id}.${processing_stage}.count.tsv ${rep_id}.${processing_stage}.airr.tsv.gz clonal_abundance "${rep_id} Clone Counts (${processing_stage})" "tsv"
                fi
            fi

            if [[ $has_makedb_clone -eq 1 ]]; then
                orig_processing_stage=igblast.makedb.allele.clone
                if [[ $split_locus -eq 1 ]]; then
                    for locus_name in $makedb_clone_locus; do
                        processing_stage=${locus_name}.igblast.makedb.allele.clone
                        addEntryToFile clone_entries.csv output ${rep_id}.${processing_stage}.abundance.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz clonal_abundance "${rep_id} Clonal Abundance (${processing_stage})" "tsv"
                        addEntryToFile clone_entries.csv output ${rep_id}.${processing_stage}.count.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz clonal_abundance "${rep_id} Clone Counts (${processing_stage})" "tsv"
                    done
                else
                    processing_stage=igblast.makedb.allele.clone
                    addEntryToFile clone_entries.csv output ${rep_id}.${processing_stage}.abundance.tsv ${rep_id}.${processing_stage}.airr.tsv.gz clonal_abundance "${rep_id} Clonal Abundance (${processing_stage})" "tsv"
                    addEntryToFile clone_entries.csv output ${rep_id}.${processing_stage}.count.tsv ${rep_id}.${processing_stage}.airr.tsv.gz clonal_abundance "${rep_id} Clone Counts (${processing_stage})" "tsv"
                fi
            fi

            if [[ $has_gene_clone -eq 1 ]]; then
                orig_processing_stage=igblast.makedb.gene.clone
                if [[ $split_locus -eq 1 ]]; then
                    for locus_name in $gene_clone_locus; do
                        processing_stage=${locus_name}.igblast.makedb.gene.clone
                        addEntryToFile clone_entries.csv output ${rep_id}.${processing_stage}.abundance.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz clonal_abundance "${rep_id} Clonal Abundance (${processing_stage})" "tsv"
                        addEntryToFile clone_entries.csv output ${rep_id}.${processing_stage}.count.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz clonal_abundance "${rep_id} Clone Counts (${processing_stage})" "tsv"
                    done
                else
                    processing_stage=igblast.makedb.gene.clone
                    addEntryToFile clone_entries.csv output ${rep_id}.${processing_stage}.abundance.tsv ${rep_id}.${processing_stage}.airr.tsv.gz clonal_abundance "${rep_id} Clonal Abundance (${processing_stage})" "tsv"
                    addEntryToFile clone_entries.csv output ${rep_id}.${processing_stage}.count.tsv ${rep_id}.${processing_stage}.airr.tsv.gz clonal_abundance "${rep_id} Clone Counts (${processing_stage})" "tsv"
                fi
            fi

            count=$(( $count + 1 ))
        done
        addFileEntries clone_entries.csv

        # archive of data files
        zip clonal_abundance_data.zip *.clone.abundance.tsv
        zip clonal_abundance_data.zip *.clone.count.tsv
        wasGeneratedBy clonal_abundance_data.zip ${ACTIVITY_NAME} clonal_abundance_archive "Archive of Clonal Abundance chart data" "zip"
    fi

    # Diversity analysis
    if [[ $DiversityFlag -eq 1 ]]; then
        echo "Calculate diversity profile"

        # launcher job file
        if [ -f joblist-diversity ]; then
            echo "Warning: removing file 'joblist-diversity'.  That filename is reserved." 1>&2
            rm joblist-diversity
        fi
        touch joblist-diversity

        if [[ $has_igblast_clone -eq 1 ]]; then
            if [[ $split_locus -eq 1 ]]; then
                for locus_name in $igblast_clone_locus; do
                    processing_stage=${locus_name}.igblast.allele.clone
                    fileList=($(ls *.${processing_stage}.airr.tsv))
        
                    count=0
                    while [ "x${fileList[count]}" != "x" ]
                    do
                        file=${fileList[count]}
                        # assume and strip airr.tsv
                        fileOutname="${file##*/}"
                        fileBasename="${fileOutname%.*}"
                        fileBasename="${fileBasename%.*}"
        
                        echo "$RSCRIPT diversity_curve.R -d $file -o $fileBasename" >> joblist-diversity
        
                        count=$(( $count + 1 ))
                    done
                done
            else
                processing_stage=igblast.allele.clone
                fileList=($(ls *.${processing_stage}.airr.tsv))
    
                count=0
                while [ "x${fileList[count]}" != "x" ]
                do
                    file=${fileList[count]}
                    # assume and strip airr.tsv
                    fileOutname="${file##*/}"
                    fileBasename="${fileOutname%.*}"
                    fileBasename="${fileBasename%.*}"
    
                    echo "$RSCRIPT diversity_curve.R -d $file -o $fileBasename" >> joblist-diversity
    
                    count=$(( $count + 1 ))
                done
            fi
        fi

        if [[ $has_makedb_clone -eq 1 ]]; then
            if [[ $split_locus -eq 1 ]]; then
                for locus_name in $makedb_clone_locus; do
                    processing_stage=${locus_name}.igblast.makedb.allele.clone
                    fileList=($(ls *.${processing_stage}.airr.tsv))
        
                    count=0
                    while [ "x${fileList[count]}" != "x" ]
                    do
                        file=${fileList[count]}
                        # assume and strip airr.tsv
                        fileOutname="${file##*/}"
                        fileBasename="${fileOutname%.*}"
                        fileBasename="${fileBasename%.*}"
        
                        echo "$RSCRIPT diversity_curve.R -d $file -o $fileBasename" >> joblist-diversity
        
                        count=$(( $count + 1 ))
                    done
                done
            else
                processing_stage=igblast.makedb.allele.clone
                fileList=($(ls *.${processing_stage}.airr.tsv))
    
                count=0
                while [ "x${fileList[count]}" != "x" ]
                do
                    file=${fileList[count]}
                    # assume and strip airr.tsv
                    fileOutname="${file##*/}"
                    fileBasename="${fileOutname%.*}"
                    fileBasename="${fileBasename%.*}"
    
                    echo "$RSCRIPT diversity_curve.R -d $file -o $fileBasename" >> joblist-diversity
    
                    count=$(( $count + 1 ))
                done
            fi
        fi

        if [[ $has_gene_clone -eq 1 ]]; then
            if [[ $split_locus -eq 1 ]]; then
                for locus_name in $gene_clone_locus; do
                    processing_stage=${locus_name}.igblast.makedb.gene.clone
                    fileList=($(ls *.${processing_stage}.airr.tsv))
        
                    count=0
                    while [ "x${fileList[count]}" != "x" ]
                    do
                        file=${fileList[count]}
                        # assume and strip airr.tsv
                        fileOutname="${file##*/}"
                        fileBasename="${fileOutname%.*}"
                        fileBasename="${fileBasename%.*}"
        
                        echo "$RSCRIPT diversity_curve.R -d $file -o $fileBasename" >> joblist-diversity
        
                        count=$(( $count + 1 ))
                    done
                done
            else
                processing_stage=igblast.makedb.gene.clone
                fileList=($(ls *.${processing_stage}.airr.tsv))
    
                count=0
                while [ "x${fileList[count]}" != "x" ]
                do
                    file=${fileList[count]}
                    # assume and strip airr.tsv
                    fileOutname="${file##*/}"
                    fileBasename="${fileOutname%.*}"
                    fileBasename="${fileBasename%.*}"
    
                    echo "$RSCRIPT diversity_curve.R -d $file -o $fileBasename" >> joblist-diversity
    
                    count=$(( $count + 1 ))
                done
            fi
        fi

        # check number of jobs to be run
        export LAUNCHER_JOB_FILE=joblist-diversity
        numJobs=$(cat joblist-diversity | wc -l)
        export LAUNCHER_PPN=$LAUNCHER_MID_PPN
        if [ $numJobs -lt $LAUNCHER_PPN ]; then
            export LAUNCHER_PPN=$numJobs
        fi

        # run launcher
        $LAUNCHER_DIR/paramrun

        # bulk provenance for output files
        initEntryFile diversity_entries.csv

        # repertoires
        count=0
        while [ "x${repertoires[count]}" != "x" ]
        do
            rep_id=${repertoires[count]}
            group=${rep_id//./_}

            if [[ $has_igblast_clone -eq 1 ]]; then
                orig_processing_stage=igblast.allele.clone
                if [[ $split_locus -eq 1 ]]; then
                    for locus_name in $igblast_clone_locus; do
                        processing_stage=${locus_name}.igblast.allele.clone
                        addEntryToFile diversity_entries.csv output ${rep_id}.${processing_stage}.diversity.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz diversity_curve "${rep_id} Diversity Curve (${processing_stage})" "tsv"
                    done
                else
                    processing_stage=igblast.allele.clone
                    addEntryToFile diversity_entries.csv output ${rep_id}.${processing_stage}.diversity.tsv ${rep_id}.${processing_stage}.airr.tsv.gz diversity_curve "${rep_id} Diversity Curve (${processing_stage})" "tsv"
                fi
            fi

            if [[ $has_makedb_clone -eq 1 ]]; then
                orig_processing_stage=igblast.makedb.allele.clone
                if [[ $split_locus -eq 1 ]]; then
                    for locus_name in $makedb_clone_locus; do
                        processing_stage=${locus_name}.igblast.makedb.allele.clone
                        addEntryToFile diversity_entries.csv output ${rep_id}.${processing_stage}.diversity.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz diversity_curve "${rep_id} Diversity Curve (${processing_stage})" "tsv"
                    done
                else
                    processing_stage=igblast.makedb.allele.clone
                    addEntryToFile diversity_entries.csv output ${rep_id}.${processing_stage}.diversity.tsv ${rep_id}.${processing_stage}.airr.tsv.gz diversity_curve "${rep_id} Diversity Curve (${processing_stage})" "tsv"
                fi
            fi

            if [[ $has_gene_clone -eq 1 ]]; then
                orig_processing_stage=igblast.makedb.gene.clone
                if [[ $split_locus -eq 1 ]]; then
                    for locus_name in $gene_clone_locus; do
                        processing_stage=${locus_name}.igblast.makedb.gene.clone
                        addEntryToFile diversity_entries.csv output ${rep_id}.${processing_stage}.diversity.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz diversity_curve "${rep_id} Diversity Curve (${processing_stage})" "tsv"
                    done
                else
                    processing_stage=igblast.makedb.gene.clone
                    addEntryToFile diversity_entries.csv output ${rep_id}.${processing_stage}.diversity.tsv ${rep_id}.${processing_stage}.airr.tsv.gz diversity_curve "${rep_id} Diversity Curve (${processing_stage})" "tsv"
                fi
            fi

            count=$(( $count + 1 ))
        done
        addFileEntries diversity_entries.csv

        # archive of data files
        zip diversity_curve_data.zip *.diversity.tsv
        wasGeneratedBy diversity_curve_data.zip ${ACTIVITY_NAME} diversity_curve_archive "Archive of Diversity Curve chart data" "zip"

    fi

    # Mutational analysis
    if [ "$locus" == "TR" ]; then
        MutationalFlag=0
    fi
    if [[ $MutationalFlag -eq 1 ]]; then
        echo "Calculate mutations"

        # launcher job file
        if [ -f joblist-mutations ]; then
            echo "Warning: removing file 'joblist-mutations'.  That filename is reserved." 1>&2
            rm joblist-mutations
        fi
        touch joblist-mutations

        count=0
        while [ "x${repertoires[count]}" != "x" ]
        do
            rep_id=${repertoires[count]}

            if [[ $has_makedb_clone -eq 1 ]]; then
                if [[ $split_locus -eq 1 ]]; then
                    for locus_name in $makedb_clone_locus; do
                        processing_stage=${locus_name}.igblast.makedb.allele.clone
                        file=${rep_id}.${processing_stage}.airr.tsv
                        echo "apptainer exec -e ${repcalc_image} bash ./mutational_analysis.sh ${AIRRMetadata} $rep_id $germline_fasta $species $file $processing_stage" >> joblist-mutations
                    done
                else
                    processing_stage=igblast.makedb.allele.clone
                    file=${rep_id}.${processing_stage}.airr.tsv
                    echo "apptainer exec -e ${repcalc_image} bash ./mutational_analysis.sh ${AIRRMetadata} $rep_id $germline_fasta $species $file $processing_stage" >> joblist-mutations
                fi
            fi

            if [[ $has_gene_clone -eq 1 ]]; then
                if [[ $split_locus -eq 1 ]]; then
                    for locus_name in $gene_clone_locus; do
                        processing_stage=${locus_name}.igblast.makedb.gene.clone
                        file=${rep_id}.${processing_stage}.airr.tsv
                        echo "apptainer exec -e ${repcalc_image} bash ./mutational_analysis.sh ${AIRRMetadata} $rep_id $germline_fasta $species $file $processing_stage" >> joblist-mutations
                    done
                else
                    processing_stage=igblast.makedb.gene.clone
                    file=${rep_id}.${processing_stage}.airr.tsv
                    echo "apptainer exec -e ${repcalc_image} bash ./mutational_analysis.sh ${AIRRMetadata} $rep_id $germline_fasta $species $file $processing_stage" >> joblist-mutations
                fi
            fi

            count=$(( $count + 1 ))
        done

        # mutational analysis is memory intensive so use the low setting
        # check number of jobs to be run
        export LAUNCHER_JOB_FILE=joblist-mutations
        numJobs=$(cat joblist-mutations | wc -l)
        export LAUNCHER_PPN=$LAUNCHER_MID_PPN
        if [ $numJobs -lt $LAUNCHER_PPN ]; then
            export LAUNCHER_PPN=$numJobs
        fi

        # run launcher
        $LAUNCHER_DIR/paramrun

        # bulk provenance for output files
        initEntryFile mutation_entries.csv

        # repertoires
        count=0
        while [ "x${repertoires[count]}" != "x" ]
        do
            rep_id=${repertoires[count]}

            if [[ $has_makedb_clone -eq 1 ]]; then
                orig_processing_stage=igblast.makedb.allele.clone
                if [[ $split_locus -eq 1 ]]; then
                    for locus_name in $makedb_clone_locus; do
                        processing_stage=${locus_name}.igblast.makedb.allele.clone
                        addEntryToFile mutation_entries.csv output ${rep_id}.${processing_stage}.mutations.airr.tsv.gz ${rep_id}.${orig_processing_stage}.airr.tsv.gz mutations "${rep_id} Mutations AIRR TSV (${processing_stage})" "tsv"
                        gzipFile ${rep_id}.${processing_stage}.mutations.airr.tsv
                        addArchiveFile ${rep_id}.${processing_stage}.mutations.airr.tsv.gz
                        addEntryToFile mutation_entries.csv output ${rep_id}.${processing_stage}.selection.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz selection "${rep_id} Selection Pressure TSV (${processing_stage})" "tsv"
                        addArchiveFile ${rep_id}.${processing_stage}.selection.tsv
                        addEntryToFile mutation_entries.csv output "${rep_id}.${processing_stage}.germ.json" ${rep_id}.${orig_processing_stage}.airr.tsv.gz create_germlines "${rep_id} Create Germlines Log (${processing_stage})" "json"
                        addArchiveFile ${rep_id}.${processing_stage}.germ.json
                        if [ -e "${rep_id}.${processing_stage}.germ-fail.airr.tsv" ]; then
                            addEntryToFile mutation_entries.csv output ${rep_id}.${processing_stage}.germ-fail.airr.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz germ_fail "${rep_id} Create Germlines Failed AIRR TSV (${processing_stage})" "tsv"
                            addArchiveFile ${rep_id}.${processing_stage}.germ-fail.airr.tsv
                        fi
                    done
                else
                    processing_stage=igblast.makedb.allele.clone
                    addEntryToFile mutation_entries.csv output ${rep_id}.${processing_stage}.mutations.airr.tsv.gz ${rep_id}.${processing_stage}.airr.tsv.gz mutations "${rep_id} Mutations AIRR TSV (${processing_stage})" "tsv"
                    gzipFile ${rep_id}.${processing_stage}.mutations.airr.tsv
                    addArchiveFile ${rep_id}.${processing_stage}.mutations.airr.tsv.gz
                    addEntryToFile mutation_entries.csv output ${rep_id}.${processing_stage}.selection.tsv ${rep_id}.${processing_stage}.airr.tsv.gz selection "${rep_id} Selection Pressure TSV (${processing_stage})" "tsv"
                    addArchiveFile ${rep_id}.${processing_stage}.selection.tsv
                    addEntryToFile mutation_entries.csv output "${rep_id}.${processing_stage}.germ.json" ${rep_id}.${processing_stage}.airr.tsv.gz create_germlines "${rep_id} Create Germlines Log (${processing_stage})" "json"
                    addArchiveFile ${rep_id}.${processing_stage}.germ.json
                    if [ -e "${rep_id}.${processing_stage}.germ-fail.airr.tsv" ]; then
                        addEntryToFile mutation_entries.csv output ${rep_id}.${processing_stage}.germ-fail.airr.tsv ${rep_id}.${processing_stage}.airr.tsv.gz germ_fail "${rep_id} Create Germlines Failed AIRR TSV (${processing_stage})" "tsv"
                        addArchiveFile ${rep_id}.${processing_stage}.germ-fail.airr.tsv
                    fi
                fi
            fi

            if [[ $has_gene_clone -eq 1 ]]; then
                orig_processing_stage=igblast.makedb.gene.clone
                if [[ $split_locus -eq 1 ]]; then
                    for locus_name in $gene_clone_locus; do
                        processing_stage=${locus_name}.igblast.makedb.gene.clone
                        addEntryToFile mutation_entries.csv output ${rep_id}.${processing_stage}.mutations.airr.tsv.gz ${rep_id}.${orig_processing_stage}.airr.tsv.gz mutations "${rep_id} Mutations AIRR TSV (${processing_stage})" "tsv"
                        gzipFile ${rep_id}.${processing_stage}.mutations.airr.tsv
                        addArchiveFile ${rep_id}.${processing_stage}.mutations.airr.tsv.gz
                        addEntryToFile mutation_entries.csv output ${rep_id}.${processing_stage}.selection.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz selection "${rep_id} Selection Pressure TSV (${processing_stage})" "tsv"
                        addArchiveFile ${rep_id}.${processing_stage}.selection.tsv
                        addEntryToFile mutation_entries.csv output "${rep_id}.${processing_stage}.germ.json" ${rep_id}.${orig_processing_stage}.airr.tsv.gz create_germlines "${rep_id} Create Germlines Log (${processing_stage})" "json"
                        addArchiveFile ${rep_id}.${processing_stage}.germ.json
                        if [ -e "${rep_id}.${processing_stage}.germ-fail.airr.tsv" ]; then
                            addEntryToFile mutation_entries.csv output ${rep_id}.${processing_stage}.germ-fail.airr.tsv ${rep_id}.${orig_processing_stage}.airr.tsv.gz germ_fail "${rep_id} Create Germlines Failed AIRR TSV (${processing_stage})" "tsv"
                            addArchiveFile ${rep_id}.${processing_stage}.germ-fail.airr.tsv
                        fi
                    done
                else
                    processing_stage=igblast.makedb.gene.clone
                    addEntryToFile mutation_entries.csv output ${rep_id}.${processing_stage}.mutations.airr.tsv.gz ${rep_id}.${processing_stage}.airr.tsv.gz mutations "${rep_id} Mutations AIRR TSV (${processing_stage})" "tsv"
                    gzipFile ${rep_id}.${processing_stage}.mutations.airr.tsv
                    addArchiveFile ${rep_id}.${processing_stage}.mutations.airr.tsv.gz
                    addEntryToFile mutation_entries.csv output ${rep_id}.${processing_stage}.selection.tsv ${rep_id}.${processing_stage}.airr.tsv.gz selection "${rep_id} Selection Pressure TSV (${processing_stage})" "tsv"
                    addArchiveFile ${rep_id}.${processing_stage}.selection.tsv
                    addEntryToFile mutation_entries.csv output "${rep_id}.${processing_stage}.germ.json" ${rep_id}.${processing_stage}.airr.tsv.gz create_germlines "${rep_id} Create Germlines Log (${processing_stage})" "json"
                    addArchiveFile ${rep_id}.${processing_stage}.germ.json
                    if [ -e "${rep_id}.${processing_stage}.germ-fail.airr.tsv" ]; then
                        addEntryToFile mutation_entries.csv output ${rep_id}.${processing_stage}.germ-fail.airr.tsv ${rep_id}.${processing_stage}.airr.tsv.gz germ_fail "${rep_id} Create Germlines Failed AIRR TSV (${processing_stage})" "tsv"
                        addArchiveFile ${rep_id}.${processing_stage}.germ-fail.airr.tsv
                    fi
                fi
            fi

            count=$(( $count + 1 ))
        done
        addFileEntries mutation_entries.csv

        echo "Calculate mutational summaries"

        if [[ $has_makedb_clone -eq 1 ]]; then
            if [[ $split_locus -eq 1 ]]; then
                for locus_name in $makedb_clone_locus; do
                    processing_stage=${locus_name}.igblast.makedb.allele.clone.mutations
                    # generate config
                    if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                        python3 repcalc_create_config.py --init mutational_analysis_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --stage ${processing_stage} mutational_analysis.${processing_stage}.json
                    else
                        python3 repcalc_create_config.py --init mutational_analysis_template.json ${AIRRMetadata} --stage ${processing_stage} mutational_analysis.${processing_stage}.json
                    fi
                    $REPCALC_EXE mutational_analysis.${processing_stage}.json
        
                    wasGeneratedBy ${processing_stage}.repertoire.count.mutational_report.csv ${ACTIVITY_NAME} mutation_count "Mutational Count Statistics (${processing_stage})" "csv"
                    wasGeneratedBy ${processing_stage}.repertoire.frequency.mutational_report.csv ${ACTIVITY_NAME} mutation_frequency "Mutational Frequency Statistics (${processing_stage})" "csv"
        
                    # add group summaries
                    if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                        grpcnt=0
                        while [ "x${repertoire_groups[grpcnt]}" != "x" ]
                        do
                            rep_group_id=${repertoire_groups[grpcnt]}
                            group=${rep_group_id//./_}
            
                            wasGeneratedBy ${rep_group_id}.${processing_stage}.repertoire.count.mutational_report.csv ${ACTIVITY_NAME} group_mutation_count "${rep_group_id} Mutational Count Statistics (${processing_stage})" "csv"
                            wasGeneratedBy ${rep_group_id}.${processing_stage}.repertoire.frequency.mutational_report.csv ${ACTIVITY_NAME} group_mutation_frequency "${rep_group_id} Mutational Frequency Statistics (${processing_stage})" "csv"
            
                            grpcnt=$(( $grpcnt + 1 ))
                        done
        
                        wasGeneratedBy ${processing_stage}.repertoire_group.count.mutational_report.csv ${ACTIVITY_NAME} group_mutation_count "Group Mutational Count Statistics (${processing_stage})" "csv"
                        wasGeneratedBy ${processing_stage}.repertoire_group.frequency.mutational_report.csv ${ACTIVITY_NAME} group_mutation_frequency "Group Mutational Frequency Statistics (${processing_stage})" "csv"
                    fi
                done
            else
                processing_stage=igblast.makedb.allele.clone.mutations
                # generate config
                if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                    python3 repcalc_create_config.py --init mutational_analysis_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --stage ${processing_stage} mutational_analysis.${processing_stage}.json
                else
                    python3 repcalc_create_config.py --init mutational_analysis_template.json ${AIRRMetadata} --stage ${processing_stage} mutational_analysis.${processing_stage}.json
                fi
                $REPCALC_EXE mutational_analysis.${processing_stage}.json
    
                wasGeneratedBy ${processing_stage}.repertoire.count.mutational_report.csv ${ACTIVITY_NAME} mutation_count "Mutational Count Statistics (${processing_stage})" "csv"
                wasGeneratedBy ${processing_stage}.repertoire.frequency.mutational_report.csv ${ACTIVITY_NAME} mutation_frequency "Mutational Frequency Statistics (${processing_stage})" "csv"
    
                # add group summaries
                if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                    grpcnt=0
                    while [ "x${repertoire_groups[grpcnt]}" != "x" ]
                    do
                        rep_group_id=${repertoire_groups[grpcnt]}
                        group=${rep_group_id//./_}
        
                        wasGeneratedBy ${rep_group_id}.${processing_stage}.repertoire.count.mutational_report.csv ${ACTIVITY_NAME} group_mutation_count "${rep_group_id} Mutational Count Statistics (${processing_stage})" "csv"
                        wasGeneratedBy ${rep_group_id}.${processing_stage}.repertoire.frequency.mutational_report.csv ${ACTIVITY_NAME} group_mutation_frequency "${rep_group_id} Mutational Frequency Statistics (${processing_stage})" "csv"
        
                        grpcnt=$(( $grpcnt + 1 ))
                    done
                    wasGeneratedBy ${processing_stage}.repertoire_group.count.mutational_report.csv ${ACTIVITY_NAME} group_mutation_count "Group Mutational Count Statistics (${processing_stage})" "csv"
                    wasGeneratedBy ${processing_stage}.repertoire_group.frequency.mutational_report.csv ${ACTIVITY_NAME} group_mutation_frequency "Group Mutational Frequency Statistics (${processing_stage})" "csv"
                fi
            fi
        fi

        if [[ $has_gene_clone -eq 1 ]]; then
            if [[ $split_locus -eq 1 ]]; then
                for locus_name in $gene_clone_locus; do
                    processing_stage=${locus_name}.igblast.makedb.gene.clone.mutations
                    # generate config
                    if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                        python3 repcalc_create_config.py --init mutational_analysis_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --stage ${processing_stage} mutational_analysis.${processing_stage}.json
                    else
                        python3 repcalc_create_config.py --init mutational_analysis_template.json ${AIRRMetadata} --stage ${processing_stage} mutational_analysis.${processing_stage}.json
                    fi
                    $REPCALC_EXE mutational_analysis.${processing_stage}.json
        
                    wasGeneratedBy ${processing_stage}.repertoire.count.mutational_report.csv ${ACTIVITY_NAME} mutation_count "Mutational Count Statistics (${processing_stage})" "csv"
                    wasGeneratedBy ${processing_stage}.repertoire.frequency.mutational_report.csv ${ACTIVITY_NAME} mutation_frequency "Mutational Frequency Statistics (${processing_stage})" "csv"
        
                    # add group summaries
                    if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                        grpcnt=0
                        while [ "x${repertoire_groups[grpcnt]}" != "x" ]
                        do
                            rep_group_id=${repertoire_groups[grpcnt]}
                            group=${rep_group_id//./_}
            
                            wasGeneratedBy ${rep_group_id}.${processing_stage}.repertoire.count.mutational_report.csv ${ACTIVITY_NAME} group_mutation_count "${rep_group_id} Mutational Count Statistics (${processing_stage})" "csv"
                            wasGeneratedBy ${rep_group_id}.${processing_stage}.repertoire.frequency.mutational_report.csv ${ACTIVITY_NAME} group_mutation_frequency "${rep_group_id} Mutational Frequency Statistics (${processing_stage})" "csv"
            
                            grpcnt=$(( $grpcnt + 1 ))
                        done
                        wasGeneratedBy ${processing_stage}.repertoire_group.count.mutational_report.csv ${ACTIVITY_NAME} group_mutation_count "Group Mutational Count Statistics (${processing_stage})" "csv"
                        wasGeneratedBy ${processing_stage}.repertoire_group.frequency.mutational_report.csv ${ACTIVITY_NAME} group_mutation_frequency "Group Mutational Frequency Statistics (${processing_stage})" "csv"
                    fi
                done
            else
                processing_stage=igblast.makedb.gene.clone.mutations
                # generate config
                if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                    python3 repcalc_create_config.py --init mutational_analysis_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --stage ${processing_stage} mutational_analysis.${processing_stage}.json
                else
                    python3 repcalc_create_config.py --init mutational_analysis_template.json ${AIRRMetadata} --stage ${processing_stage} mutational_analysis.${processing_stage}.json
                fi
                $REPCALC_EXE mutational_analysis.${processing_stage}.json
    
                wasGeneratedBy ${processing_stage}.repertoire.count.mutational_report.csv ${ACTIVITY_NAME} mutation_count "Mutational Count Statistics (${processing_stage})" "csv"
                wasGeneratedBy ${processing_stage}.repertoire.frequency.mutational_report.csv ${ACTIVITY_NAME} mutation_frequency "Mutational Frequency Statistics (${processing_stage})" "csv"
    
                # add group summaries
                if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                    grpcnt=0
                    while [ "x${repertoire_groups[grpcnt]}" != "x" ]
                    do
                        rep_group_id=${repertoire_groups[grpcnt]}
                        group=${rep_group_id//./_}
        
                        wasGeneratedBy ${rep_group_id}.${processing_stage}.repertoire.count.mutational_report.csv ${ACTIVITY_NAME} group_mutation_count "${rep_group_id} Mutational Count Statistics (${processing_stage})" "csv"
                        wasGeneratedBy ${rep_group_id}.${processing_stage}.repertoire.frequency.mutational_report.csv ${ACTIVITY_NAME} group_mutation_frequency "${rep_group_id} Mutational Frequency Statistics (${processing_stage})" "csv"
        
                        grpcnt=$(( $grpcnt + 1 ))
                    done
                    wasGeneratedBy ${processing_stage}.repertoire_group.count.mutational_report.csv ${ACTIVITY_NAME} group_mutation_count "Group Mutational Count Statistics (${processing_stage})" "csv"
                    wasGeneratedBy ${processing_stage}.repertoire_group.frequency.mutational_report.csv ${ACTIVITY_NAME} group_mutation_frequency "Group Mutational Frequency Statistics (${processing_stage})" "csv"
                fi
            fi
        fi
    fi

#     # turn off lineage reconstruction for now
#     LineageFlag=0
#     # Lineage reconstruction
#     if [ "$seqtype" == "TCR" ]; then
#         LineageFlag=0
#     fi
#     if [[ $LineageFlag -eq 1 ]]; then
#         rm -f joblist
#         touch joblist
# 
#         scriptList=$($PYTHON ./create_r_scripts.py repcalc_config.json process_metadata.json --lineage lineage)
#         #echo ${scriptList[@]}
#         for script in ${scriptList[@]}; do
#             echo "export R_LIBS=\"$R_LIBS\" && export TMPDIR=$PWD && R --quiet --no-save < ${script}" >> joblist
#             noArchive ${script}
#         done
#         #cat joblist
# 
#         # check number of jobs to be run
#         numJobs=$(cat joblist | wc -l)
#         export LAUNCHER_PPN=$LAUNCHER_MID_PPN
#         if [ $numJobs -lt $LAUNCHER_PPN ]; then
#             export LAUNCHER_PPN=$numJobs
#         fi
# 
#         # run launcher
#         $LAUNCHER_DIR/paramrun
#     fi


    # Provenance file
    wasGeneratedBy "provenance_output.json" "${ACTIVITY_NAME}" prov "Analysis Provenance" json
    wasGeneratedBy ${_tapisJobUUID}.zip ${ACTIVITY_NAME} archive "Archive of Output Files" "zip"
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
#            cp -f $file output
        fi
    done

    # manually save some important input files
    cp -f ${AIRRMetadata} ${_tapisJobUUID}
    if [ "x${RepertoireGroupMetadata}" != "x" ]; then
        cp -f ${RepertoireGroupMetadata} ${_tapisJobUUID}
    fi
    cp -f ${germline_db_file} ${_tapisJobUUID}
    zip ${_tapisJobUUID}.zip ${_tapisJobUUID}/*
    
    cp ${_tapisJobUUID}.zip output
    

    # HACK: manually archive the output as it is too many files for Tapis
    archive_dir=${_tapisArchiveSystemDir#/}
    archive_dir=${archive_dir%%/*}
    if [[ "$archive_dir" != "scratch" ]] ; then
        cp -f ${_tapisJobUUID}/* /corral-repl/projects/vdjZ${_tapisArchiveSystemDir}
    fi
}
