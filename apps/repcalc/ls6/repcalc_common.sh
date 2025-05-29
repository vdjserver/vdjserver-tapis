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
    echo "strain=${strain}"
    echo "locus=${locus}"
    echo "germline_db=${germline_db}"
    echo "germline_fasta=${germline_fasta}"
    echo "GeneSegmentFlag=${GeneSegmentFlag}"
    echo "CDR3Flag=${CDR3Flag}"
    echo "DiversityFlag=${DiversityFlag}"
    echo "ClonalFlag=${ClonalFlag}"
    echo "MutationalFlag=${MutationalFlag}"
    echo "LineageFlag=${LineageFlag}"
}

function run_repcalc_workflow() {
    initProvenance
#    addLogFile $APP_NAME log stdout "${AGAVE_LOG_NAME}.out" "Job Output Log" "log" null
#    addLogFile $APP_NAME log stderr "${AGAVE_LOG_NAME}.err" "Job Error Log" "log" null
#    addLogFile $APP_NAME log agave_log .agave.log "Agave Output Log" "log" null

    # Exclude input files from archive
#    noArchive ${repcalc_image}
#    noArchive "${ProjectDirectory}"
    for file in $JobFiles; do
        if [ -f $file ]; then
            unzip -o $file
#            noArchive $file
#            noArchive "${file%.*}"
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
#        noArchive $file
        count=$(( $count + 1 ))
    done

    # hack AIRR
    repertoires=($($PYTHON ./airr_metadata.py --list Repertoire repertoire_id ${AIRRMetadata}))
    count=0
    while [ "x${repertoires[count]}" != "x" ]
    do
        rep_id=${repertoires[count]}
        group=${rep_id//./_}
        addGroup $group file
        count=$(( $count + 1 ))
    done
    if [ "x${RepertoireGroupMetadata}" != "x" ]; then
        repertoire_groups=($($PYTHON ./airr_metadata.py --list RepertoireGroup repertoire_group_id ${RepertoireGroupMetadata}))
        grpcnt=0
        while [ "x${repertoire_groups[grpcnt]}" != "x" ]
        do
            rep_group_id=${repertoire_groups[grpcnt]}
            group=${rep_group_id//./_}
            addGroup $group repertoire_group
            grpcnt=$(( $grpcnt + 1 ))
        done
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

    # Gene segment usage
    if [[ $GeneSegmentFlag -eq 1 ]]; then
        echo "Calculate gene segment and combo usage"

        # launcher job file
        if [ -f joblist-gene ]; then
            echo "Warning: removing file 'joblist-gene'.  That filename is reserved." 1>&2
            rm joblist-gene
        fi
        touch joblist-gene
#        noArchive "joblist-gene"

        if [[ $has_igblast -eq 1 ]]; then
            processing_stage=igblast
            if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                python3 repcalc_create_config.py --init gene_usage_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db} --stage ${processing_stage} gene_usage_config.${processing_stage}.json
            else
                python3 repcalc_create_config.py --init gene_usage_template.json ${AIRRMetadata} --germline ${germline_db} --stage ${processing_stage} gene_usage_config.${processing_stage}.json
            fi
            addConfigFile $APP_NAME config ${processing_stage//./_}-gene_usage "gene_usage_config.${processing_stage}.json" "RepCalc Input Configuration" "json" null
            echo "$REPCALC_EXE gene_usage_config.${processing_stage}.json" >> joblist-gene

            if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                python3 repcalc_create_config.py --init gene_combo_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db} --stage ${processing_stage} gene_combo_config.${processing_stage}.json
            else
                python3 repcalc_create_config.py --init gene_combo_template.json ${AIRRMetadata} --germline ${germline_db} --stage ${processing_stage} gene_combo_config.${processing_stage}.json
            fi
            addConfigFile $APP_NAME config ${processing_stage//./_}-gene_combo "gene_combo_config.${processing_stage}.json" "RepCalc Input Configuration" "json" null
            echo "$REPCALC_EXE gene_combo_config.${processing_stage}.json" >> joblist-gene
        fi
        if [[ $has_makedb -eq 1 ]]; then
            processing_stage=igblast.makedb
            if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                python3 repcalc_create_config.py --init gene_usage_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db} --stage ${processing_stage} gene_usage_config.${processing_stage}.json
            else
                python3 repcalc_create_config.py --init gene_usage_template.json ${AIRRMetadata} --germline ${germline_db} --stage ${processing_stage} gene_usage_config.${processing_stage}.json
            fi
            addConfigFile $APP_NAME config ${processing_stage//./_}-gene_usage "gene_usage_config.${processing_stage}.json" "RepCalc Input Configuration" "json" null
            echo "$REPCALC_EXE gene_usage_config.${processing_stage}.json" >> joblist-gene

            if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                python3 repcalc_create_config.py --init gene_combo_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db} --stage ${processing_stage} gene_combo_config.${processing_stage}.json
            else
                python3 repcalc_create_config.py --init gene_combo_template.json ${AIRRMetadata} --germline ${germline_db} --stage ${processing_stage} gene_combo_config.${processing_stage}.json
            fi
            addConfigFile $APP_NAME config ${processing_stage//./_}-gene_combo "gene_combo_config.${processing_stage}.json" "RepCalc Input Configuration" "json" null
            echo "$REPCALC_EXE gene_combo_config.${processing_stage}.json" >> joblist-gene
        fi
        if [[ $has_igblast_clone -eq 1 ]]; then
            processing_stage=igblast.allele.clone
            if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                python3 repcalc_create_config.py --init gene_usage_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db} --stage ${processing_stage} gene_usage_config.${processing_stage}.json
            else
                python3 repcalc_create_config.py --init gene_usage_template.json ${AIRRMetadata} --germline ${germline_db} --stage ${processing_stage} gene_usage_config.${processing_stage}.json
            fi
            addConfigFile $APP_NAME config ${processing_stage//./_}-gene_usage "gene_usage_config.${processing_stage}.json" "RepCalc Input Configuration" "json" null
            echo "$REPCALC_EXE gene_usage_config.${processing_stage}.json" >> joblist-gene

            if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                python3 repcalc_create_config.py --init gene_combo_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db} --stage ${processing_stage} gene_combo_config.${processing_stage}.json
            else
                python3 repcalc_create_config.py --init gene_combo_template.json ${AIRRMetadata} --germline ${germline_db} --stage ${processing_stage} gene_combo_config.${processing_stage}.json
            fi
            addConfigFile $APP_NAME config ${processing_stage//./_}-gene_combo "gene_combo_config.${processing_stage}.json" "RepCalc Input Configuration" "json" null
            echo "$REPCALC_EXE gene_combo_config.${processing_stage}.json" >> joblist-gene
        fi
        if [[ $has_makedb_clone -eq 1 ]]; then
            processing_stage=igblast.makedb.allele.clone
            if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                python3 repcalc_create_config.py --init gene_usage_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db} --stage ${processing_stage} gene_usage_config.${processing_stage}.json
            else
                python3 repcalc_create_config.py --init gene_usage_template.json ${AIRRMetadata} --germline ${germline_db} --stage ${processing_stage} gene_usage_config.${processing_stage}.json
            fi
            addConfigFile $APP_NAME config ${processing_stage//./_}-gene_usage "gene_usage_config.${processing_stage}.json" "RepCalc Input Configuration" "json" null
            echo "$REPCALC_EXE gene_usage_config.${processing_stage}.json" >> joblist-gene

            if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                python3 repcalc_create_config.py --init gene_combo_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db} --stage ${processing_stage} gene_combo_config.${processing_stage}.json
            else
                python3 repcalc_create_config.py --init gene_combo_template.json ${AIRRMetadata} --germline ${germline_db} --stage ${processing_stage} gene_combo_config.${processing_stage}.json
            fi
            addConfigFile $APP_NAME config ${processing_stage//./_}-gene_combo "gene_combo_config.${processing_stage}.json" "RepCalc Input Configuration" "json" null
            echo "$REPCALC_EXE gene_combo_config.${processing_stage}.json" >> joblist-gene
        fi
        if [[ $has_gene_clone -eq 1 ]]; then
            processing_stage=igblast.makedb.gene.clone
            if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                python3 repcalc_create_config.py --init gene_usage_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db} --stage ${processing_stage} gene_usage_config.${processing_stage}.json
            else
                python3 repcalc_create_config.py --init gene_usage_template.json ${AIRRMetadata} --germline ${germline_db} --stage ${processing_stage} gene_usage_config.${processing_stage}.json
            fi
            addConfigFile $APP_NAME config ${processing_stage//./_}-gene_usage "gene_usage_config.${processing_stage}.json" "RepCalc Input Configuration" "json" null
            echo "$REPCALC_EXE gene_usage_config.${processing_stage}.json" >> joblist-gene

            if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                python3 repcalc_create_config.py --init gene_combo_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db} --stage ${processing_stage} gene_combo_config.${processing_stage}.json
            else
                python3 repcalc_create_config.py --init gene_combo_template.json ${AIRRMetadata} --germline ${germline_db} --stage ${processing_stage} gene_combo_config.${processing_stage}.json
            fi
            addConfigFile $APP_NAME config ${processing_stage//./_}-gene_combo "gene_combo_config.${processing_stage}.json" "RepCalc Input Configuration" "json" null
            echo "$REPCALC_EXE gene_combo_config.${processing_stage}.json" >> joblist-gene
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

        # add output files to process metadata
        # TODO: provenance functions check for file existence
        initEntryFile gene_segment_entries.csv
        #noArchive gene_segment_entries.csv
        count=0
        while [ "x${repertoires[count]}" != "x" ]
        do
            rep_id=${repertoires[count]}
            group=${rep_id//./_}

            if [[ $has_igblast -eq 1 ]]; then
                processing_stage=igblast
                addEntryToFile gene_segment_entries.csv output $group gene_segment_usage ${processing_stage//./_}-v_call ${rep_id}.${processing_stage}.v_call.tsv "${rep_id} V Gene Usage (${processing_stage})" "tsv" null
                addEntryToFile gene_segment_entries.csv output $group gene_segment_usage ${processing_stage//./_}-d_call ${rep_id}.${processing_stage}.d_call.tsv "${rep_id} D Gene Usage (${processing_stage})" "tsv" null
                addEntryToFile gene_segment_entries.csv output $group gene_segment_usage ${processing_stage//./_}-j_call ${rep_id}.${processing_stage}.j_call.tsv "${rep_id} J Gene Usage (${processing_stage})" "tsv" null
                addEntryToFile gene_segment_entries.csv output $group gene_segment_usage ${processing_stage//./_}-c_call ${rep_id}.${processing_stage}.c_call.tsv "${rep_id} C Gene Usage (${processing_stage})" "tsv" null
                addEntryToFile gene_segment_entries.csv output $group gene_segment_combos ${processing_stage//./_}-vj_combo ${rep_id}.${processing_stage}.vj_combo.tsv "${rep_id} VJ Gene Combo (${processing_stage})" "tsv" null
                addEntryToFile gene_segment_entries.csv output $group gene_segment_combos ${processing_stage//./_}-vd_combo ${rep_id}.${processing_stage}.vd_combo.tsv "${rep_id} VD Gene Combo (${processing_stage})" "tsv" null
                addEntryToFile gene_segment_entries.csv output $group gene_segment_combos ${processing_stage//./_}-vdj_combo ${rep_id}.${processing_stage}.vdj_combo.tsv "${rep_id} VDJ Gene Combo (${processing_stage})" "tsv" null
                addEntryToFile gene_segment_entries.csv output $group gene_segment_combos ${processing_stage//./_}-dj_combo ${rep_id}.${processing_stage}.dj_combo.tsv "${rep_id} DJ Gene Combo (${processing_stage})" "tsv" null
            fi

            if [[ $has_makedb -eq 1 ]]; then
                processing_stage=igblast.makedb
                addEntryToFile gene_segment_entries.csv output $group gene_segment_usage ${processing_stage//./_}-v_call ${rep_id}.${processing_stage}.v_call.tsv "${rep_id} V Gene Usage (${processing_stage})" "tsv" null
                addEntryToFile gene_segment_entries.csv output $group gene_segment_usage ${processing_stage//./_}-d_call ${rep_id}.${processing_stage}.d_call.tsv "${rep_id} D Gene Usage (${processing_stage})" "tsv" null
                addEntryToFile gene_segment_entries.csv output $group gene_segment_usage ${processing_stage//./_}-j_call ${rep_id}.${processing_stage}.j_call.tsv "${rep_id} J Gene Usage (${processing_stage})" "tsv" null
                addEntryToFile gene_segment_entries.csv output $group gene_segment_usage ${processing_stage//./_}-c_call ${rep_id}.${processing_stage}.c_call.tsv "${rep_id} C Gene Usage (${processing_stage})" "tsv" null
                addEntryToFile gene_segment_entries.csv output $group gene_segment_combos ${processing_stage//./_}-vj_combo ${rep_id}.${processing_stage}.vj_combo.tsv "${rep_id} VJ Gene Combo (${processing_stage})" "tsv" null
                addEntryToFile gene_segment_entries.csv output $group gene_segment_combos ${processing_stage//./_}-vd_combo ${rep_id}.${processing_stage}.vd_combo.tsv "${rep_id} VD Gene Combo (${processing_stage})" "tsv" null
                addEntryToFile gene_segment_entries.csv output $group gene_segment_combos ${processing_stage//./_}-vdj_combo ${rep_id}.${processing_stage}.vdj_combo.tsv "${rep_id} VDJ Gene Combo (${processing_stage})" "tsv" null
                addEntryToFile gene_segment_entries.csv output $group gene_segment_combos ${processing_stage//./_}-dj_combo ${rep_id}.${processing_stage}.dj_combo.tsv "${rep_id} DJ Gene Combo (${processing_stage})" "tsv" null
            fi

            if [[ $has_igblast_clone -eq 1 ]]; then
                processing_stage=igblast.allele.clone
                addEntryToFile gene_segment_entries.csv output $group gene_segment_usage ${processing_stage//./_}-v_call ${rep_id}.${processing_stage}.v_call.tsv "${rep_id} V Gene Usage (${processing_stage})" "tsv" null
                addEntryToFile gene_segment_entries.csv output $group gene_segment_usage ${processing_stage//./_}-d_call ${rep_id}.${processing_stage}.d_call.tsv "${rep_id} D Gene Usage (${processing_stage})" "tsv" null
                addEntryToFile gene_segment_entries.csv output $group gene_segment_usage ${processing_stage//./_}-j_call ${rep_id}.${processing_stage}.j_call.tsv "${rep_id} J Gene Usage (${processing_stage})" "tsv" null
                addEntryToFile gene_segment_entries.csv output $group gene_segment_usage ${processing_stage//./_}-c_call ${rep_id}.${processing_stage}.c_call.tsv "${rep_id} C Gene Usage (${processing_stage})" "tsv" null
                addEntryToFile gene_segment_entries.csv output $group gene_segment_combos ${processing_stage//./_}-vj_combo ${rep_id}.${processing_stage}.vj_combo.tsv "${rep_id} VJ Gene Combo (${processing_stage})" "tsv" null
                addEntryToFile gene_segment_entries.csv output $group gene_segment_combos ${processing_stage//./_}-vd_combo ${rep_id}.${processing_stage}.vd_combo.tsv "${rep_id} VD Gene Combo (${processing_stage})" "tsv" null
                addEntryToFile gene_segment_entries.csv output $group gene_segment_combos ${processing_stage//./_}-vdj_combo ${rep_id}.${processing_stage}.vdj_combo.tsv "${rep_id} VDJ Gene Combo (${processing_stage})" "tsv" null
                addEntryToFile gene_segment_entries.csv output $group gene_segment_combos ${processing_stage//./_}-dj_combo ${rep_id}.${processing_stage}.dj_combo.tsv "${rep_id} DJ Gene Combo (${processing_stage})" "tsv" null
            fi

            if [[ $has_makedb_clone -eq 1 ]]; then
                processing_stage=igblast.makedb.allele.clone
                addEntryToFile gene_segment_entries.csv output $group gene_segment_usage ${processing_stage//./_}-v_call ${rep_id}.${processing_stage}.v_call.tsv "${rep_id} V Gene Usage (${processing_stage})" "tsv" null
                addEntryToFile gene_segment_entries.csv output $group gene_segment_usage ${processing_stage//./_}-d_call ${rep_id}.${processing_stage}.d_call.tsv "${rep_id} D Gene Usage (${processing_stage})" "tsv" null
                addEntryToFile gene_segment_entries.csv output $group gene_segment_usage ${processing_stage//./_}-j_call ${rep_id}.${processing_stage}.j_call.tsv "${rep_id} J Gene Usage (${processing_stage})" "tsv" null
                addEntryToFile gene_segment_entries.csv output $group gene_segment_usage ${processing_stage//./_}-c_call ${rep_id}.${processing_stage}.c_call.tsv "${rep_id} C Gene Usage (${processing_stage})" "tsv" null
                addEntryToFile gene_segment_entries.csv output $group gene_segment_combos ${processing_stage//./_}-vj_combo ${rep_id}.${processing_stage}.vj_combo.tsv "${rep_id} VJ Gene Combo (${processing_stage})" "tsv" null
                addEntryToFile gene_segment_entries.csv output $group gene_segment_combos ${processing_stage//./_}-vd_combo ${rep_id}.${processing_stage}.vd_combo.tsv "${rep_id} VD Gene Combo (${processing_stage})" "tsv" null
                addEntryToFile gene_segment_entries.csv output $group gene_segment_combos ${processing_stage//./_}-vdj_combo ${rep_id}.${processing_stage}.vdj_combo.tsv "${rep_id} VDJ Gene Combo (${processing_stage})" "tsv" null
                addEntryToFile gene_segment_entries.csv output $group gene_segment_combos ${processing_stage//./_}-dj_combo ${rep_id}.${processing_stage}.dj_combo.tsv "${rep_id} DJ Gene Combo (${processing_stage})" "tsv" null
            fi

            if [[ $has_gene_clone -eq 1 ]]; then
                processing_stage=igblast.makedb.gene.clone
                addEntryToFile gene_segment_entries.csv output $group gene_segment_usage ${processing_stage//./_}-v_call ${rep_id}.${processing_stage}.v_call.tsv "${rep_id} V Gene Usage (${processing_stage})" "tsv" null
                addEntryToFile gene_segment_entries.csv output $group gene_segment_usage ${processing_stage//./_}-d_call ${rep_id}.${processing_stage}.d_call.tsv "${rep_id} D Gene Usage (${processing_stage})" "tsv" null
                addEntryToFile gene_segment_entries.csv output $group gene_segment_usage ${processing_stage//./_}-j_call ${rep_id}.${processing_stage}.j_call.tsv "${rep_id} J Gene Usage (${processing_stage})" "tsv" null
                addEntryToFile gene_segment_entries.csv output $group gene_segment_usage ${processing_stage//./_}-c_call ${rep_id}.${processing_stage}.c_call.tsv "${rep_id} C Gene Usage (${processing_stage})" "tsv" null
                addEntryToFile gene_segment_entries.csv output $group gene_segment_combos ${processing_stage//./_}-vj_combo ${rep_id}.${processing_stage}.vj_combo.tsv "${rep_id} VJ Gene Combo (${processing_stage})" "tsv" null
                addEntryToFile gene_segment_entries.csv output $group gene_segment_combos ${processing_stage//./_}-vd_combo ${rep_id}.${processing_stage}.vd_combo.tsv "${rep_id} VD Gene Combo (${processing_stage})" "tsv" null
                addEntryToFile gene_segment_entries.csv output $group gene_segment_combos ${processing_stage//./_}-vdj_combo ${rep_id}.${processing_stage}.vdj_combo.tsv "${rep_id} VDJ Gene Combo (${processing_stage})" "tsv" null
                addEntryToFile gene_segment_entries.csv output $group gene_segment_combos ${processing_stage//./_}-dj_combo ${rep_id}.${processing_stage}.dj_combo.tsv "${rep_id} DJ Gene Combo (${processing_stage})" "tsv" null
            fi

            count=$(( $count + 1 ))
        done

        # add output files for repertoire groups to process metadata
        if [ "x${RepertoireGroupMetadata}" != "x" ]; then
            grpcnt=0
            while [ "x${repertoire_groups[grpcnt]}" != "x" ]
            do
                rep_group_id=${repertoire_groups[grpcnt]}
                group=${rep_group_id//./_}

                if [[ $has_igblast -eq 1 ]]; then
                    processing_stage=igblast
                    addEntryToFile gene_segment_entries.csv output $group gene_segment_usage ${processing_stage//./_}-v_call ${rep_group_id}.${processing_stage}.group.v_call.tsv "${rep_group_id} V Gene Usage (${processing_stage})" "tsv" null
                    addEntryToFile gene_segment_entries.csv output $group gene_segment_usage ${processing_stage//./_}-d_call ${rep_group_id}.${processing_stage}.group.d_call.tsv "${rep_group_id} D Gene Usage (${processing_stage})" "tsv" null
                    addEntryToFile gene_segment_entries.csv output $group gene_segment_usage ${processing_stage//./_}-j_call ${rep_group_id}.${processing_stage}.group.j_call.tsv "${rep_group_id} J Gene Usage (${processing_stage})" "tsv" null
                    addEntryToFile gene_segment_entries.csv output $group gene_segment_usage ${processing_stage//./_}-c_call ${rep_group_id}.${processing_stage}.group.c_call.tsv "${rep_group_id} C Gene Usage (${processing_stage})" "tsv" null
                    addEntryToFile gene_segment_entries.csv output $group gene_segment_combos ${processing_stage//./_}-vj_combo ${rep_group_id}.${processing_stage}.group.vj_combo.tsv "${rep_group_id} VJ Gene Combo (${processing_stage})" "tsv" null
                    addEntryToFile gene_segment_entries.csv output $group gene_segment_combos ${processing_stage//./_}-vd_combo ${rep_group_id}.${processing_stage}.group.vd_combo.tsv "${rep_group_id} VD Gene Combo (${processing_stage})" "tsv" null
                    addEntryToFile gene_segment_entries.csv output $group gene_segment_combos ${processing_stage//./_}-vdj_combo ${rep_group_id}.${processing_stage}.group.vdj_combo.tsv "${rep_group_id} VDJ Gene Combo (${processing_stage})" "tsv" null
                    addEntryToFile gene_segment_entries.csv output $group gene_segment_combos ${processing_stage//./_}-dj_combo ${rep_group_id}.${processing_stage}.group.dj_combo.tsv "${rep_group_id} DJ Gene Combo (${processing_stage})" "tsv" null
                fi

                if [[ $has_makedb -eq 1 ]]; then
                    processing_stage=igblast.makedb
                    addEntryToFile gene_segment_entries.csv output $group gene_segment_usage ${processing_stage//./_}-v_call ${rep_group_id}.${processing_stage}.group.v_call.tsv "${rep_group_id} V Gene Usage (${processing_stage})" "tsv" null
                    addEntryToFile gene_segment_entries.csv output $group gene_segment_usage ${processing_stage//./_}-d_call ${rep_group_id}.${processing_stage}.group.d_call.tsv "${rep_group_id} D Gene Usage (${processing_stage})" "tsv" null
                    addEntryToFile gene_segment_entries.csv output $group gene_segment_usage ${processing_stage//./_}-j_call ${rep_group_id}.${processing_stage}.group.j_call.tsv "${rep_group_id} J Gene Usage (${processing_stage})" "tsv" null
                    addEntryToFile gene_segment_entries.csv output $group gene_segment_usage ${processing_stage//./_}-c_call ${rep_group_id}.${processing_stage}.group.c_call.tsv "${rep_group_id} C Gene Usage (${processing_stage})" "tsv" null
                    addEntryToFile gene_segment_entries.csv output $group gene_segment_combos ${processing_stage//./_}-vj_combo ${rep_group_id}.${processing_stage}.group.vj_combo.tsv "${rep_group_id} VJ Gene Combo (${processing_stage})" "tsv" null
                    addEntryToFile gene_segment_entries.csv output $group gene_segment_combos ${processing_stage//./_}-vd_combo ${rep_group_id}.${processing_stage}.group.vd_combo.tsv "${rep_group_id} VD Gene Combo (${processing_stage})" "tsv" null
                    addEntryToFile gene_segment_entries.csv output $group gene_segment_combos ${processing_stage//./_}-vdj_combo ${rep_group_id}.${processing_stage}.group.vdj_combo.tsv "${rep_group_id} VDJ Gene Combo (${processing_stage})" "tsv" null
                    addEntryToFile gene_segment_entries.csv output $group gene_segment_combos ${processing_stage//./_}-dj_combo ${rep_group_id}.${processing_stage}.group.dj_combo.tsv "${rep_group_id} DJ Gene Combo (${processing_stage})" "tsv" null
                fi

                if [[ $has_igblast_clone -eq 1 ]]; then
                    processing_stage=igblast.allele.clone
                    addEntryToFile gene_segment_entries.csv output $group gene_segment_usage ${processing_stage//./_}-v_call ${rep_group_id}.${processing_stage}.group.v_call.tsv "${rep_group_id} V Gene Usage (${processing_stage})" "tsv" null
                    addEntryToFile gene_segment_entries.csv output $group gene_segment_usage ${processing_stage//./_}-d_call ${rep_group_id}.${processing_stage}.group.d_call.tsv "${rep_group_id} D Gene Usage (${processing_stage})" "tsv" null
                    addEntryToFile gene_segment_entries.csv output $group gene_segment_usage ${processing_stage//./_}-j_call ${rep_group_id}.${processing_stage}.group.j_call.tsv "${rep_group_id} J Gene Usage (${processing_stage})" "tsv" null
                    addEntryToFile gene_segment_entries.csv output $group gene_segment_usage ${processing_stage//./_}-c_call ${rep_group_id}.${processing_stage}.group.c_call.tsv "${rep_group_id} C Gene Usage (${processing_stage})" "tsv" null
                    addEntryToFile gene_segment_entries.csv output $group gene_segment_combos ${processing_stage//./_}-vj_combo ${rep_group_id}.${processing_stage}.group.vj_combo.tsv "${rep_group_id} VJ Gene Combo (${processing_stage})" "tsv" null
                    addEntryToFile gene_segment_entries.csv output $group gene_segment_combos ${processing_stage//./_}-vd_combo ${rep_group_id}.${processing_stage}.group.vd_combo.tsv "${rep_group_id} VD Gene Combo (${processing_stage})" "tsv" null
                    addEntryToFile gene_segment_entries.csv output $group gene_segment_combos ${processing_stage//./_}-vdj_combo ${rep_group_id}.${processing_stage}.group.vdj_combo.tsv "${rep_group_id} VDJ Gene Combo (${processing_stage})" "tsv" null
                    addEntryToFile gene_segment_entries.csv output $group gene_segment_combos ${processing_stage//./_}-dj_combo ${rep_group_id}.${processing_stage}.group.dj_combo.tsv "${rep_group_id} DJ Gene Combo (${processing_stage})" "tsv" null
                fi

                if [[ $has_makedb_clone -eq 1 ]]; then
                    processing_stage=igblast.makedb.allele.clone
                    addEntryToFile gene_segment_entries.csv output $group gene_segment_usage ${processing_stage//./_}-v_call ${rep_group_id}.${processing_stage}.group.v_call.tsv "${rep_group_id} V Gene Usage (${processing_stage})" "tsv" null
                    addEntryToFile gene_segment_entries.csv output $group gene_segment_usage ${processing_stage//./_}-d_call ${rep_group_id}.${processing_stage}.group.d_call.tsv "${rep_group_id} D Gene Usage (${processing_stage})" "tsv" null
                    addEntryToFile gene_segment_entries.csv output $group gene_segment_usage ${processing_stage//./_}-j_call ${rep_group_id}.${processing_stage}.group.j_call.tsv "${rep_group_id} J Gene Usage (${processing_stage})" "tsv" null
                    addEntryToFile gene_segment_entries.csv output $group gene_segment_usage ${processing_stage//./_}-c_call ${rep_group_id}.${processing_stage}.group.c_call.tsv "${rep_group_id} C Gene Usage (${processing_stage})" "tsv" null
                    addEntryToFile gene_segment_entries.csv output $group gene_segment_combos ${processing_stage//./_}-vj_combo ${rep_group_id}.${processing_stage}.group.vj_combo.tsv "${rep_group_id} VJ Gene Combo (${processing_stage})" "tsv" null
                    addEntryToFile gene_segment_entries.csv output $group gene_segment_combos ${processing_stage//./_}-vd_combo ${rep_group_id}.${processing_stage}.group.vd_combo.tsv "${rep_group_id} VD Gene Combo (${processing_stage})" "tsv" null
                    addEntryToFile gene_segment_entries.csv output $group gene_segment_combos ${processing_stage//./_}-vdj_combo ${rep_group_id}.${processing_stage}.group.vdj_combo.tsv "${rep_group_id} VDJ Gene Combo (${processing_stage})" "tsv" null
                    addEntryToFile gene_segment_entries.csv output $group gene_segment_combos ${processing_stage//./_}-dj_combo ${rep_group_id}.${processing_stage}.group.dj_combo.tsv "${rep_group_id} DJ Gene Combo (${processing_stage})" "tsv" null
                fi

                if [[ $has_gene_clone -eq 1 ]]; then
                    processing_stage=igblast.makedb.gene.clone
                    addEntryToFile gene_segment_entries.csv output $group gene_segment_usage ${processing_stage//./_}-v_call ${rep_group_id}.${processing_stage}.group.v_call.tsv "${rep_group_id} V Gene Usage (${processing_stage})" "tsv" null
                    addEntryToFile gene_segment_entries.csv output $group gene_segment_usage ${processing_stage//./_}-d_call ${rep_group_id}.${processing_stage}.group.d_call.tsv "${rep_group_id} D Gene Usage (${processing_stage})" "tsv" null
                    addEntryToFile gene_segment_entries.csv output $group gene_segment_usage ${processing_stage//./_}-j_call ${rep_group_id}.${processing_stage}.group.j_call.tsv "${rep_group_id} J Gene Usage (${processing_stage})" "tsv" null
                    addEntryToFile gene_segment_entries.csv output $group gene_segment_usage ${processing_stage//./_}-c_call ${rep_group_id}.${processing_stage}.group.c_call.tsv "${rep_group_id} C Gene Usage (${processing_stage})" "tsv" null
                    addEntryToFile gene_segment_entries.csv output $group gene_segment_combos ${processing_stage//./_}-vj_combo ${rep_group_id}.${processing_stage}.group.vj_combo.tsv "${rep_group_id} VJ Gene Combo (${processing_stage})" "tsv" null
                    addEntryToFile gene_segment_entries.csv output $group gene_segment_combos ${processing_stage//./_}-vd_combo ${rep_group_id}.${processing_stage}.group.vd_combo.tsv "${rep_group_id} VD Gene Combo (${processing_stage})" "tsv" null
                    addEntryToFile gene_segment_entries.csv output $group gene_segment_combos ${processing_stage//./_}-vdj_combo ${rep_group_id}.${processing_stage}.group.vdj_combo.tsv "${rep_group_id} VDJ Gene Combo (${processing_stage})" "tsv" null
                    addEntryToFile gene_segment_entries.csv output $group gene_segment_combos ${processing_stage//./_}-dj_combo ${rep_group_id}.${processing_stage}.group.dj_combo.tsv "${rep_group_id} DJ Gene Combo (${processing_stage})" "tsv" null
                fi

                grpcnt=$(( $grpcnt + 1 ))
            done
        fi
        addFileEntries gene_segment_entries.csv

        # chart data files
        zip segment_counts_data.zip *.v_call.tsv
        zip segment_counts_data.zip *.d_call.tsv
        zip segment_counts_data.zip *.j_call.tsv
        zip segment_counts_data.zip *.c_call.tsv
        addOutputFile $APP_NAME gene_segment_usage chart_data segment_counts_data.zip "Gene Segment Usage chart data" "tsv" null
        zip segment_combos_data.zip *.vj_combo.tsv
        zip segment_combos_data.zip *.vd_combo.tsv
        zip segment_combos_data.zip *.vdj_combo.tsv
        zip segment_combos_data.zip *.dj_combo.tsv
        addOutputFile $APP_NAME gene_segment_combos chart_data segment_combos_data.zip "Gene Segment Combinations chart data" "tsv" null
    fi

    # CDR3
    if [[ $CDR3Flag -eq 1 ]]; then
        echo "Calculate CDR3 junction length and distribution"

        # launcher job file
        if [ -f joblist-cdr3 ]; then
            echo "Warning: removing file 'joblist-cdr3'.  That filename is reserved." 1>&2
            rm joblist-cdr3
        fi
        touch joblist-cdr3
        #noArchive "joblist-cdr3"

        if [[ $has_igblast -eq 1 ]]; then
            processing_stage=igblast
            if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                python3 repcalc_create_config.py --init junction_length_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db} --stage ${processing_stage} junction_length_config.${processing_stage}.json
            else
                python3 repcalc_create_config.py --init junction_length_template.json ${AIRRMetadata} --germline ${germline_db} --stage ${processing_stage} junction_length_config.${processing_stage}.json
            fi
            addConfigFile $APP_NAME config ${processing_stage//./_}-junction_length "junction_length_config.${processing_stage}.json" "RepCalc Input Configuration" "json" null
            echo "$REPCALC_EXE junction_length_config.${processing_stage}.json" >> joblist-cdr3
        fi
        if [[ $has_makedb -eq 1 ]]; then
            processing_stage=igblast.makedb
            if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                python3 repcalc_create_config.py --init junction_length_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db} --stage ${processing_stage} junction_length_config.${processing_stage}.json
            else
                python3 repcalc_create_config.py --init junction_length_template.json ${AIRRMetadata} --germline ${germline_db} --stage ${processing_stage} junction_length_config.${processing_stage}.json
            fi
            addConfigFile $APP_NAME config ${processing_stage//./_}-junction_length "junction_length_config.${processing_stage}.json" "RepCalc Input Configuration" "json" null
            echo "$REPCALC_EXE junction_length_config.${processing_stage}.json" >> joblist-cdr3
        fi
        if [[ $has_igblast_clone -eq 1 ]]; then
            processing_stage=igblast.allele.clone
            if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                python3 repcalc_create_config.py --init junction_length_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db} --stage ${processing_stage} junction_length_config.${processing_stage}.json
            else
                python3 repcalc_create_config.py --init junction_length_template.json ${AIRRMetadata} --germline ${germline_db} --stage ${processing_stage} junction_length_config.${processing_stage}.json
            fi
            addConfigFile $APP_NAME config ${processing_stage//./_}-junction_length "junction_length_config.${processing_stage}.json" "RepCalc Input Configuration" "json" null
            echo "$REPCALC_EXE junction_length_config.${processing_stage}.json" >> joblist-cdr3

            if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                python3 repcalc_create_config.py --init junction_distribution_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db} --stage ${processing_stage} junction_distribution_config.${processing_stage}.json
            else
                python3 repcalc_create_config.py --init junction_distribution_template.json ${AIRRMetadata} --germline ${germline_db} --stage ${processing_stage} junction_distribution_config.${processing_stage}.json
            fi
            addConfigFile $APP_NAME config ${processing_stage//./_}-junction_distribution "junction_distribution_config.${processing_stage}.json" "RepCalc Input Configuration" "json" null
            echo "$REPCALC_EXE junction_distribution_config.${processing_stage}.json" >> joblist-cdr3

            python3 repcalc_create_config.py --init junction_shared_template.json ${AIRRMetadata} --germline ${germline_db} --stage ${processing_stage} junction_shared_config.${processing_stage}.json
            addConfigFile $APP_NAME config ${processing_stage//./_}-junction_shared "junction_shared_config.${processing_stage}.json" "RepCalc Input Configuration" "json" null
            echo "$REPCALC_EXE junction_shared_config.${processing_stage}.json" >> joblist-cdr3
        fi
        if [[ $has_makedb_clone -eq 1 ]]; then
            processing_stage=igblast.makedb.allele.clone
            if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                python3 repcalc_create_config.py --init junction_length_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db} --stage ${processing_stage} junction_length_config.${processing_stage}.json
            else
                python3 repcalc_create_config.py --init junction_length_template.json ${AIRRMetadata} --germline ${germline_db} --stage ${processing_stage} junction_length_config.${processing_stage}.json
            fi
            addConfigFile $APP_NAME config ${processing_stage//./_}-junction_length "junction_length_config.${processing_stage}.json" "RepCalc Input Configuration" "json" null
            echo "$REPCALC_EXE junction_length_config.${processing_stage}.json" >> joblist-cdr3

            if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                python3 repcalc_create_config.py --init junction_distribution_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db} --stage ${processing_stage} junction_distribution_config.${processing_stage}.json
            else
                python3 repcalc_create_config.py --init junction_distribution_template.json ${AIRRMetadata} --germline ${germline_db} --stage ${processing_stage} junction_distribution_config.${processing_stage}.json
            fi
            addConfigFile $APP_NAME config ${processing_stage//./_}-junction_distribution "junction_distribution_config.${processing_stage}.json" "RepCalc Input Configuration" "json" null
            echo "$REPCALC_EXE junction_distribution_config.${processing_stage}.json" >> joblist-cdr3

            if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                python3 repcalc_create_config.py --init junction_shared_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db} --stage ${processing_stage} junction_shared_config.${processing_stage}.json
            else
                python3 repcalc_create_config.py --init junction_shared_template.json ${AIRRMetadata} --germline ${germline_db} --stage ${processing_stage} junction_shared_config.${processing_stage}.json
            fi
            addConfigFile $APP_NAME config ${processing_stage//./_}-junction_shared "junction_shared_config.${processing_stage}.json" "RepCalc Input Configuration" "json" null
            echo "$REPCALC_EXE junction_shared_config.${processing_stage}.json" >> joblist-cdr3
        fi
        if [[ $has_gene_clone -eq 1 ]]; then
            processing_stage=igblast.makedb.gene.clone
            if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                python3 repcalc_create_config.py --init junction_length_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db} --stage ${processing_stage} junction_length_config.${processing_stage}.json
            else
                python3 repcalc_create_config.py --init junction_length_template.json ${AIRRMetadata} --germline ${germline_db} --stage ${processing_stage} junction_length_config.${processing_stage}.json
            fi
            addConfigFile $APP_NAME config ${processing_stage//./_}-junction_length "junction_length_config.${processing_stage}.json" "RepCalc Input Configuration" "json" null
            echo "$REPCALC_EXE junction_length_config.${processing_stage}.json" >> joblist-cdr3
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

        # add output files to process metadata
        initEntryFile cdr3_entries.csv
        #noArchive cdr3_entries.csv
        count=0
        while [ "x${repertoires[count]}" != "x" ]
        do
            rep_id=${repertoires[count]}
            group=${rep_id//./_}

            if [[ $has_igblast -eq 1 ]]; then
                processing_stage=igblast
                addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-junction_aa_length ${rep_id}.${processing_stage}.junction_aa_length.tsv "${rep_id} Junction AA Length (${processing_stage})" "tsv" null
                addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-junction_aa_wo_duplicates_length ${rep_id}.${processing_stage}.junction_aa_wo_duplicates_length.tsv "${rep_id} Junction AA Length (${processing_stage})" "tsv" null
                addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-junction_nucleotide_length ${rep_id}.${processing_stage}.junction_nucleotide_length.tsv "${rep_id} Junction NT Length (${processing_stage})" "tsv" null
                addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-junction_nucleotide_wo_duplicates_length ${rep_id}.${processing_stage}.junction_nucleotide_wo_duplicates_length.tsv "${rep_id} Junction NT Length (${processing_stage})" "tsv" null
                addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-productive_junction_aa_length ${rep_id}.${processing_stage}.productive.junction_aa_length.tsv "${rep_id} Junction AA Length (productive, ${processing_stage})" "tsv" null
                addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-productive_junction_aa_wo_duplicates_length ${rep_id}.${processing_stage}.productive.junction_aa_wo_duplicates_length.tsv "${rep_id} Junction AA Length (productive, ${processing_stage})" "tsv" null
                addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-productive_junction_nucleotide_length ${rep_id}.${processing_stage}.productive.junction_nucleotide_length.tsv "${rep_id} Junction NT Length (productive, ${processing_stage})" "tsv" null
                addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-productive_junction_nucleotide_wo_duplicates_length ${rep_id}.${processing_stage}.productive.junction_nucleotide_wo_duplicates_length.tsv "${rep_id} Junction NT Length (productive, ${processing_stage})" "tsv" null
            fi

            if [[ $has_makedb -eq 1 ]]; then
                processing_stage=igblast.makedb
                addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-junction_aa_length ${rep_id}.${processing_stage}.junction_aa_length.tsv "${rep_id} Junction AA Length (${processing_stage})" "tsv" null
                addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-junction_aa_wo_duplicates_length ${rep_id}.${processing_stage}.junction_aa_wo_duplicates_length.tsv "${rep_id} Junction AA Length (${processing_stage})" "tsv" null
                addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-junction_nucleotide_length ${rep_id}.${processing_stage}.junction_nucleotide_length.tsv "${rep_id} Junction NT Length (${processing_stage})" "tsv" null
                addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-junction_nucleotide_wo_duplicates_length ${rep_id}.${processing_stage}.junction_nucleotide_wo_duplicates_length.tsv "${rep_id} Junction NT Length (${processing_stage})" "tsv" null
                addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-productive_junction_aa_length ${rep_id}.${processing_stage}.productive.junction_aa_length.tsv "${rep_id} Junction AA Length (productive, ${processing_stage})" "tsv" null
                addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-productive_junction_aa_wo_duplicates_length ${rep_id}.${processing_stage}.productive.junction_aa_wo_duplicates_length.tsv "${rep_id} Junction AA Length (productive, ${processing_stage})" "tsv" null
                addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-productive_junction_nucleotide_length ${rep_id}.${processing_stage}.productive.junction_nucleotide_length.tsv "${rep_id} Junction NT Length (productive, ${processing_stage})" "tsv" null
                addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-productive_junction_nucleotide_wo_duplicates_length ${rep_id}.${processing_stage}.productive.junction_nucleotide_wo_duplicates_length.tsv "${rep_id} Junction NT Length (productive, ${processing_stage})" "tsv" null
            fi

            if [[ $has_igblast_clone -eq 1 ]]; then
                processing_stage=igblast.allele.clone
                addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-junction_aa_length ${rep_id}.${processing_stage}.junction_aa_length.tsv "${rep_id} Junction AA Length (${processing_stage})" "tsv" null
                addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-junction_aa_wo_duplicates_length ${rep_id}.${processing_stage}.junction_aa_wo_duplicates_length.tsv "${rep_id} Junction AA Length (${processing_stage})" "tsv" null
                addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-junction_nucleotide_length ${rep_id}.${processing_stage}.junction_nucleotide_length.tsv "${rep_id} Junction NT Length (${processing_stage})" "tsv" null
                addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-junction_nucleotide_wo_duplicates_length ${rep_id}.${processing_stage}.junction_nucleotide_wo_duplicates_length.tsv "${rep_id} Junction NT Length (${processing_stage})" "tsv" null
                addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-productive_junction_aa_length ${rep_id}.${processing_stage}.productive.junction_aa_length.tsv "${rep_id} Junction AA Length (productive, ${processing_stage})" "tsv" null
                addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-productive_junction_aa_wo_duplicates_length ${rep_id}.${processing_stage}.productive.junction_aa_wo_duplicates_length.tsv "${rep_id} Junction AA Length (productive, ${processing_stage})" "tsv" null
                addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-productive_junction_nucleotide_length ${rep_id}.${processing_stage}.productive.junction_nucleotide_length.tsv "${rep_id} Junction NT Length (productive, ${processing_stage})" "tsv" null
                addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-productive_junction_nucleotide_wo_duplicates_length ${rep_id}.${processing_stage}.productive.junction_nucleotide_wo_duplicates_length.tsv "${rep_id} Junction NT Length (productive, ${processing_stage})" "tsv" null
            fi

            if [[ $has_makedb_clone -eq 1 ]]; then
                processing_stage=igblast.makedb.allele.clone
                addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-junction_aa_length ${rep_id}.${processing_stage}.junction_aa_length.tsv "${rep_id} Junction AA Length (${processing_stage})" "tsv" null
                addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-junction_aa_wo_duplicates_length ${rep_id}.${processing_stage}.junction_aa_wo_duplicates_length.tsv "${rep_id} Junction AA Length (${processing_stage})" "tsv" null
                addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-junction_nucleotide_length ${rep_id}.${processing_stage}.junction_nucleotide_length.tsv "${rep_id} Junction NT Length (${processing_stage})" "tsv" null
                addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-junction_nucleotide_wo_duplicates_length ${rep_id}.${processing_stage}.junction_nucleotide_wo_duplicates_length.tsv "${rep_id} Junction NT Length (${processing_stage})" "tsv" null
                addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-productive_junction_aa_length ${rep_id}.${processing_stage}.productive.junction_aa_length.tsv "${rep_id} Junction AA Length (productive, ${processing_stage})" "tsv" null
                addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-productive_junction_aa_wo_duplicates_length ${rep_id}.${processing_stage}.productive.junction_aa_wo_duplicates_length.tsv "${rep_id} Junction AA Length (productive, ${processing_stage})" "tsv" null
                addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-productive_junction_nucleotide_length ${rep_id}.${processing_stage}.productive.junction_nucleotide_length.tsv "${rep_id} Junction NT Length (productive, ${processing_stage})" "tsv" null
                addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-productive_junction_nucleotide_wo_duplicates_length ${rep_id}.${processing_stage}.productive.junction_nucleotide_wo_duplicates_length.tsv "${rep_id} Junction NT Length (productive, ${processing_stage})" "tsv" null
            fi

            if [[ $has_gene_clone -eq 1 ]]; then
                processing_stage=igblast.makedb.gene.clone
                addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-junction_aa_length ${rep_id}.${processing_stage}.junction_aa_length.tsv "${rep_id} Junction AA Length (${processing_stage})" "tsv" null
                addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-junction_aa_wo_duplicates_length ${rep_id}.${processing_stage}.junction_aa_wo_duplicates_length.tsv "${rep_id} Junction AA Length (${processing_stage})" "tsv" null
                addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-junction_nucleotide_length ${rep_id}.${processing_stage}.junction_nucleotide_length.tsv "${rep_id} Junction NT Length (${processing_stage})" "tsv" null
                addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-junction_nucleotide_wo_duplicates_length ${rep_id}.${processing_stage}.junction_nucleotide_wo_duplicates_length.tsv "${rep_id} Junction NT Length (${processing_stage})" "tsv" null
                addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-productive_junction_aa_length ${rep_id}.${processing_stage}.productive.junction_aa_length.tsv "${rep_id} Junction AA Length (productive, ${processing_stage})" "tsv" null
                addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-productive_junction_aa_wo_duplicates_length ${rep_id}.${processing_stage}.productive.junction_aa_wo_duplicates_length.tsv "${rep_id} Junction AA Length (productive, ${processing_stage})" "tsv" null
                addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-productive_junction_nucleotide_length ${rep_id}.${processing_stage}.productive.junction_nucleotide_length.tsv "${rep_id} Junction NT Length (productive, ${processing_stage})" "tsv" null
                addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-productive_junction_nucleotide_wo_duplicates_length ${rep_id}.${processing_stage}.productive.junction_nucleotide_wo_duplicates_length.tsv "${rep_id} Junction NT Length (productive, ${processing_stage})" "tsv" null
            fi

            count=$(( $count + 1 ))
        done

        # add output files for repertoire groups to process metadata
        if [ "x${RepertoireGroupMetadata}" != "x" ]; then
            grpcnt=0
            while [ "x${repertoire_groups[grpcnt]}" != "x" ]
            do
                rep_group_id=${repertoire_groups[grpcnt]}
                group=${rep_group_id//./_}

                if [[ $has_igblast -eq 1 ]]; then
                    processing_stage=igblast
                    addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-junction_aa_length ${rep_group_id}.${processing_stage}.junction_aa_length.tsv "${rep_group_id} Junction AA Length (${processing_stage})" "tsv" null
                    addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-junction_aa_wo_duplicates_length ${rep_group_id}.${processing_stage}.junction_aa_wo_duplicates_length.tsv "${rep_group_id} Junction AA Length (${processing_stage})" "tsv" null
                    addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-junction_nucleotide_length ${rep_group_id}.${processing_stage}.junction_nucleotide_length.tsv "${rep_group_id} Junction NT Length (${processing_stage})" "tsv" null
                    addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-junction_nucleotide_wo_duplicates_length ${rep_group_id}.${processing_stage}.junction_nucleotide_wo_duplicates_length.tsv "${rep_group_id} Junction NT Length (${processing_stage})" "tsv" null
                    addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-productive_junction_aa_length ${rep_group_id}.${processing_stage}.productive.junction_aa_length.tsv "${rep_group_id} Junction AA Length (productive, ${processing_stage})" "tsv" null
                    addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-productive_junction_aa_wo_duplicates_length ${rep_group_id}.${processing_stage}.productive.junction_aa_wo_duplicates_length.tsv "${rep_group_id} Junction AA Length (productive, ${processing_stage})" "tsv" null
                    addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-productive_junction_nucleotide_length ${rep_group_id}.${processing_stage}.productive.junction_nucleotide_length.tsv "${rep_group_id} Junction NT Length (productive, ${processing_stage})" "tsv" null
                    addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-productive_junction_nucleotide_wo_duplicates_length ${rep_group_id}.${processing_stage}.productive.junction_nucleotide_wo_duplicates_length.tsv "${rep_group_id} Junction NT Length (productive, ${processing_stage})" "tsv" null
                fi

                if [[ $has_makedb -eq 1 ]]; then
                    processing_stage=igblast.makedb
                    addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-junction_aa_length ${rep_group_id}.${processing_stage}.junction_aa_length.tsv "${rep_group_id} Junction AA Length (${processing_stage})" "tsv" null
                    addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-junction_aa_wo_duplicates_length ${rep_group_id}.${processing_stage}.junction_aa_wo_duplicates_length.tsv "${rep_group_id} Junction AA Length (${processing_stage})" "tsv" null
                    addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-junction_nucleotide_length ${rep_group_id}.${processing_stage}.junction_nucleotide_length.tsv "${rep_group_id} Junction NT Length (${processing_stage})" "tsv" null
                    addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-junction_nucleotide_wo_duplicates_length ${rep_group_id}.${processing_stage}.junction_nucleotide_wo_duplicates_length.tsv "${rep_group_id} Junction NT Length (${processing_stage})" "tsv" null
                    addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-productive_junction_aa_length ${rep_group_id}.${processing_stage}.productive.junction_aa_length.tsv "${rep_group_id} Junction AA Length (productive, ${processing_stage})" "tsv" null
                    addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-productive_junction_aa_wo_duplicates_length ${rep_group_id}.${processing_stage}.productive.junction_aa_wo_duplicates_length.tsv "${rep_group_id} Junction AA Length (productive, ${processing_stage})" "tsv" null
                    addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-productive_junction_nucleotide_length ${rep_group_id}.${processing_stage}.productive.junction_nucleotide_length.tsv "${rep_group_id} Junction NT Length (productive, ${processing_stage})" "tsv" null
                    addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-productive_junction_nucleotide_wo_duplicates_length ${rep_group_id}.${processing_stage}.productive.junction_nucleotide_wo_duplicates_length.tsv "${rep_group_id} Junction NT Length (productive, ${processing_stage})" "tsv" null
                fi

                if [[ $has_igblast_clone -eq 1 ]]; then
                    processing_stage=igblast.allele.clone
                    addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-junction_aa_length ${rep_group_id}.${processing_stage}.junction_aa_length.tsv "${rep_group_id} Junction AA Length (${processing_stage})" "tsv" null
                    addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-junction_aa_wo_duplicates_length ${rep_group_id}.${processing_stage}.junction_aa_wo_duplicates_length.tsv "${rep_group_id} Junction AA Length (${processing_stage})" "tsv" null
                    addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-junction_nucleotide_length ${rep_group_id}.${processing_stage}.junction_nucleotide_length.tsv "${rep_group_id} Junction NT Length (${processing_stage})" "tsv" null
                    addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-junction_nucleotide_wo_duplicates_length ${rep_group_id}.${processing_stage}.junction_nucleotide_wo_duplicates_length.tsv "${rep_group_id} Junction NT Length (${processing_stage})" "tsv" null
                    addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-productive_junction_aa_length ${rep_group_id}.${processing_stage}.productive.junction_aa_length.tsv "${rep_group_id} Junction AA Length (productive, ${processing_stage})" "tsv" null
                    addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-productive_junction_aa_wo_duplicates_length ${rep_group_id}.${processing_stage}.productive.junction_aa_wo_duplicates_length.tsv "${rep_group_id} Junction AA Length (productive, ${processing_stage})" "tsv" null
                    addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-productive_junction_nucleotide_length ${rep_group_id}.${processing_stage}.productive.junction_nucleotide_length.tsv "${rep_group_id} Junction NT Length (productive, ${processing_stage})" "tsv" null
                    addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-productive_junction_nucleotide_wo_duplicates_length ${rep_group_id}.${processing_stage}.productive.junction_nucleotide_wo_duplicates_length.tsv "${rep_group_id} Junction NT Length (productive, ${processing_stage})" "tsv" null
                fi

                if [[ $has_makedb_clone -eq 1 ]]; then
                    processing_stage=igblast.makedb.allele.clone
                    addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-junction_aa_length ${rep_group_id}.${processing_stage}.junction_aa_length.tsv "${rep_group_id} Junction AA Length (${processing_stage})" "tsv" null
                    addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-junction_aa_wo_duplicates_length ${rep_group_id}.${processing_stage}.junction_aa_wo_duplicates_length.tsv "${rep_group_id} Junction AA Length (${processing_stage})" "tsv" null
                    addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-junction_nucleotide_length ${rep_group_id}.${processing_stage}.junction_nucleotide_length.tsv "${rep_group_id} Junction NT Length (${processing_stage})" "tsv" null
                    addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-junction_nucleotide_wo_duplicates_length ${rep_group_id}.${processing_stage}.junction_nucleotide_wo_duplicates_length.tsv "${rep_group_id} Junction NT Length (${processing_stage})" "tsv" null
                    addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-productive_junction_aa_length ${rep_group_id}.${processing_stage}.productive.junction_aa_length.tsv "${rep_group_id} Junction AA Length (productive, ${processing_stage})" "tsv" null
                    addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-productive_junction_aa_wo_duplicates_length ${rep_group_id}.${processing_stage}.productive.junction_aa_wo_duplicates_length.tsv "${rep_group_id} Junction AA Length (productive, ${processing_stage})" "tsv" null
                    addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-productive_junction_nucleotide_length ${rep_group_id}.${processing_stage}.productive.junction_nucleotide_length.tsv "${rep_group_id} Junction NT Length (productive, ${processing_stage})" "tsv" null
                    addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-productive_junction_nucleotide_wo_duplicates_length ${rep_group_id}.${processing_stage}.productive.junction_nucleotide_wo_duplicates_length.tsv "${rep_group_id} Junction NT Length (productive, ${processing_stage})" "tsv" null
                fi

                if [[ $has_gene_clone -eq 1 ]]; then
                    processing_stage=igblast.makedb.gene.clone
                    addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-junction_aa_length ${rep_group_id}.${processing_stage}.junction_aa_length.tsv "${rep_group_id} Junction AA Length (${processing_stage})" "tsv" null
                    addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-junction_aa_wo_duplicates_length ${rep_group_id}.${processing_stage}.junction_aa_wo_duplicates_length.tsv "${rep_group_id} Junction AA Length (${processing_stage})" "tsv" null
                    addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-junction_nucleotide_length ${rep_group_id}.${processing_stage}.junction_nucleotide_length.tsv "${rep_group_id} Junction NT Length (${processing_stage})" "tsv" null
                    addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-junction_nucleotide_wo_duplicates_length ${rep_group_id}.${processing_stage}.junction_nucleotide_wo_duplicates_length.tsv "${rep_group_id} Junction NT Length (${processing_stage})" "tsv" null
                    addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-productive_junction_aa_length ${rep_group_id}.${processing_stage}.productive.junction_aa_length.tsv "${rep_group_id} Junction AA Length (productive, ${processing_stage})" "tsv" null
                    addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-productive_junction_aa_wo_duplicates_length ${rep_group_id}.${processing_stage}.productive.junction_aa_wo_duplicates_length.tsv "${rep_group_id} Junction AA Length (productive, ${processing_stage})" "tsv" null
                    addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-productive_junction_nucleotide_length ${rep_group_id}.${processing_stage}.productive.junction_nucleotide_length.tsv "${rep_group_id} Junction NT Length (productive, ${processing_stage})" "tsv" null
                    addEntryToFile cdr3_entries.csv output $group cdr3_length ${processing_stage//./_}-productive_junction_nucleotide_wo_duplicates_length ${rep_group_id}.${processing_stage}.productive.junction_nucleotide_wo_duplicates_length.tsv "${rep_group_id} Junction NT Length (productive, ${processing_stage})" "tsv" null
                fi

                grpcnt=$(( $grpcnt + 1 ))
            done
        fi
        addFileEntries cdr3_entries.csv

        # junction comparison
        if [[ $has_makedb_clone -eq 1 ]]; then
            processing_stage=igblast.makedb.allele.clone
            if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                python3 repcalc_create_config.py --init junction_compare_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --germline ${germline_db} --stage ${processing_stage} junction_compare_config.${processing_stage}.json
                addConfigFile $APP_NAME config ${processing_stage//./_}-junction_compare "junction_compare_config.${processing_stage}.json" "RepCalc Input Configuration" "json" null
                $REPCALC_EXE junction_compare_config.${processing_stage}.json
            fi
        fi

        # chart data files
        zip cdr3_length_data.zip *.junction_aa_length.tsv
        zip cdr3_length_data.zip *.junction_aa_wo_duplicates_length.tsv
        zip cdr3_length_data.zip *.junction_nucleotide_length.tsv
        zip cdr3_length_data.zip *.junction_nucleotide_wo_duplicates_length.tsv
        addOutputFile $APP_NAME cdr3_length chart_data cdr3_length_data.zip "CDR3 Length Histogram chart data" "tsv" null

        zip cdr3_sharing_data.zip *cdr3_*_sharing.tsv
        addOutputFile $APP_NAME cdr3_sharing chart_data cdr3_sharing_data.zip "Shared/Unique CDR3 chart data" "tsv" null
        rm -r *cdr3_*_sharing.tsv

        zip cdr3_distribution_data.zip *distribution.tsv
        addOutputFile $APP_NAME cdr3_distribution chart_data cdr3_distribution_data.zip "CDR3 Distribution chart data" "tsv" null
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
        #noArchive "joblist-clones"

        if [[ $has_igblast_clone -eq 1 ]]; then
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

        if [[ $has_makedb_clone -eq 1 ]]; then
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

        if [[ $has_gene_clone -eq 1 ]]; then
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

         # check number of jobs to be run
         export LAUNCHER_JOB_FILE=joblist-clones
         numJobs=$(cat joblist-clones | wc -l)
         export LAUNCHER_PPN=$LAUNCHER_MID_PPN
         if [ $numJobs -lt $LAUNCHER_PPN ]; then
             export LAUNCHER_PPN=$numJobs
         fi
 
         # run launcher
         $LAUNCHER_DIR/paramrun

        # add output files to process metadata
        initEntryFile clone_entries.csv
        #noArchive clone_entries.csv
        count=0
        while [ "x${repertoires[count]}" != "x" ]
        do
            rep_id=${repertoires[count]}
            group=${rep_id//./_}

            if [[ $has_igblast_clone -eq 1 ]]; then
                processing_stage=igblast.allele.clone
                addEntryToFile clone_entries.csv output $group clonal_abundance ${processing_stage//./_}-clonal_abundance ${rep_id}.${processing_stage}.abundance.tsv "${rep_id} Clonal Abundance (${processing_stage})" "tsv" null
                addEntryToFile clone_entries.csv output $group clonal_abundance ${processing_stage//./_}-clonal_count ${rep_id}.${processing_stage}.count.tsv "${rep_id} Clone Counts (${processing_stage})" "tsv" null
            fi

            if [[ $has_makedb_clone -eq 1 ]]; then
                processing_stage=igblast.makedb.allele.clone
                addEntryToFile clone_entries.csv output $group clonal_abundance ${processing_stage//./_}-clonal_abundance ${rep_id}.${processing_stage}.abundance.tsv "${rep_id} Clonal Abundance (${processing_stage})" "tsv" null
                addEntryToFile clone_entries.csv output $group clonal_abundance ${processing_stage//./_}-clonal_count ${rep_id}.${processing_stage}.count.tsv "${rep_id} Clone Counts (${processing_stage})" "tsv" null
            fi

            if [[ $has_gene_clone -eq 1 ]]; then
                processing_stage=igblast.makedb.gene.clone
                addEntryToFile clone_entries.csv output $group clonal_abundance ${processing_stage//./_}-clonal_abundance ${rep_id}.${processing_stage}.abundance.tsv "${rep_id} Clonal Abundance (${processing_stage})" "tsv" null
                addEntryToFile clone_entries.csv output $group clonal_abundance ${processing_stage//./_}-clonal_count ${rep_id}.${processing_stage}.count.tsv "${rep_id} Clone Counts (${processing_stage})" "tsv" null
            fi

            count=$(( $count + 1 ))
        done
        addFileEntries clone_entries.csv

        # chart data files
        zip clonal_abundance_data.zip *.clone.abundance.tsv
        zip clonal_abundance_data.zip *.clone.count.tsv
        addOutputFile $APP_NAME clonal_abundance chart_data clonal_abundance_data.zip "Clonal Abundance chart data" "tsv" null
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
        #noArchive "joblist-diversity"

        if [[ $has_igblast_clone -eq 1 ]]; then
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

        if [[ $has_makedb_clone -eq 1 ]]; then
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

        if [[ $has_gene_clone -eq 1 ]]; then
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

         # check number of jobs to be run
         export LAUNCHER_JOB_FILE=joblist-diversity
         numJobs=$(cat joblist-diversity | wc -l)
         export LAUNCHER_PPN=$LAUNCHER_MID_PPN
         if [ $numJobs -lt $LAUNCHER_PPN ]; then
             export LAUNCHER_PPN=$numJobs
         fi
 
         # run launcher
         $LAUNCHER_DIR/paramrun

        # add output files to process metadata
        initEntryFile diversity_entries.csv
        #noArchive diversity_entries.csv
        count=0
        while [ "x${repertoires[count]}" != "x" ]
        do
            rep_id=${repertoires[count]}
            group=${rep_id//./_}

            if [[ $has_igblast_clone -eq 1 ]]; then
                processing_stage=igblast.allele.clone
                addEntryToFile diversity_entries.csv output $group diversity_curve ${processing_stage//./_}-diversity_curve ${rep_id}.${processing_stage}.diversity.tsv "${rep_id} Diversity Curve (${processing_stage})" "tsv" null
            fi

            if [[ $has_makedb_clone -eq 1 ]]; then
                processing_stage=igblast.makedb.allele.clone
                addEntryToFile diversity_entries.csv output $group diversity_curve ${processing_stage//./_}-diversity_curve ${rep_id}.${processing_stage}.diversity.tsv "${rep_id} Diversity Curve (${processing_stage})" "tsv" null
            fi

            if [[ $has_gene_clone -eq 1 ]]; then
                processing_stage=igblast.makedb.gene.clone
                addEntryToFile diversity_entries.csv output $group diversity_curve ${processing_stage//./_}-diversity_curve ${rep_id}.${processing_stage}.diversity.tsv "${rep_id} Diversity Curve (${processing_stage})" "tsv" null
            fi

            count=$(( $count + 1 ))
        done
        addFileEntries diversity_entries.csv

        # chart data files
        zip diversity_curve_data.zip *.diversity.tsv
        addOutputFile $APP_NAME diversity_curve chart_data diversity_curve_data.zip "Diversity Curve chart data" "tsv" null
    fi

    # Mutational analysis
    if [ "$seqtype" == "TR" ]; then
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
        #noArchive "joblist-mutations"

        count=0
        while [ "x${repertoires[count]}" != "x" ]
        do
            rep_id=${repertoires[count]}

            if [[ $has_makedb_clone -eq 1 ]]; then
                processing_stage=igblast.makedb.allele.clone
                file=${rep_id}.${processing_stage}.airr.tsv
                echo "apptainer exec -e ${repcalc_image} bash ./mutational_analysis.sh ${AIRRMetadata} $rep_id $germline_fasta $species $file $processing_stage" >> joblist-mutations
            fi

            if [[ $has_gene_clone -eq 1 ]]; then
                processing_stage=igblast.makedb.gene.clone
                file=${rep_id}.${processing_stage}.airr.tsv
                echo "apptainer exec -e ${repcalc_image} bash ./mutational_analysis.sh ${AIRRMetadata} $rep_id $germline_fasta $species $file $processing_stage" >> joblist-mutations
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

        # add output files to process metadata
        initEntryFile mutation_entries.csv
        #noArchive mutation_entries.csv
        count=0
        while [ "x${repertoires[count]}" != "x" ]
        do
            rep_id=${repertoires[count]}
            group=${rep_id//./_}

            if [[ $has_makedb_clone -eq 1 ]]; then
                processing_stage=igblast.makedb.allele.clone
                addEntryToFile mutation_entries.csv output $group $APP_NAME ${processing_stage//./_}-mutations ${rep_id}.${processing_stage}.mutations.airr.tsv.gz "${rep_id} Mutations AIRR TSV (${processing_stage})" "tsv" null
                gzipFile ${rep_id}.${processing_stage}.mutations.airr.tsv
                addEntryToFile mutation_entries.csv output $group $APP_NAME ${processing_stage//./_}-selection ${rep_id}.${processing_stage}.selection.tsv "${rep_id} Selection Pressure TSV (${processing_stage})" "tsv" null
                addEntryToFile mutation_entries.csv output $group $APP_NAME ${processing_stage//./_}-create_germlines "${rep_id}.${processing_stage}.germ.json" "${rep_id} Create Germlines Log (${processing_stage})" "json" null
                #noArchive ${rep_id}.${processing_stage}.germ.log
                #noArchive ${rep_id}.${processing_stage}.germ.airr.tsv
                #noArchive ${rep_id}.${processing_stage}.mutations.orig.airr.tsv
                #noArchive ${rep_id}.${processing_stage}.summary.mutations.airr.tsv
                #noArchive ${rep_id}.${processing_stage}.frequency.summary.mutations.airr.tsv
                if [ -e "${rep_id}.${processing_stage}.germ-fail.airr.tsv" ]; then
                    addEntryToFile mutation_entries.csv output $group $APP_NAME ${processing_stage//./_}-germ_fail ${rep_id}.${processing_stage}.germ-fail.airr.tsv "${rep_id} Create Germlines Failed AIRR TSV (${processing_stage})" "tsv" null
                fi
                #noArchive mutational_config.${rep_id}.${processing_stage}.json
            fi

            if [[ $has_gene_clone -eq 1 ]]; then
                processing_stage=igblast.makedb.gene.clone
                addEntryToFile mutation_entries.csv output $group $APP_NAME ${processing_stage//./_}-mutations ${rep_id}.${processing_stage}.mutations.airr.tsv.gz "${rep_id} Mutations AIRR TSV (${processing_stage})" "tsv" null
                gzipFile ${rep_id}.${processing_stage}.mutations.airr.tsv
                addEntryToFile mutation_entries.csv output $group $APP_NAME ${processing_stage//./_}-selection ${rep_id}.${processing_stage}.selection.tsv "${rep_id} Selection Pressure TSV (${processing_stage})" "tsv" null
                addEntryToFile mutation_entries.csv output $group $APP_NAME ${processing_stage//./_}-create_germlines "${rep_id}.${processing_stage}.germ.json" "${rep_id} Create Germlines Log (${processing_stage})" "json" null
                #noArchive ${rep_id}.${processing_stage}.germ.log
                #noArchive ${rep_id}.${processing_stage}.germ.airr.tsv
                #noArchive ${rep_id}.${processing_stage}.mutations.orig.airr.tsv
                #noArchive ${rep_id}.${processing_stage}.summary.mutations.airr.tsv
                #noArchive ${rep_id}.${processing_stage}.frequency.summary.mutations.airr.tsv
                if [ -e "${rep_id}.${processing_stage}.germ-fail.airr.tsv" ]; then
                    addEntryToFile mutation_entries.csv output $group $APP_NAME ${processing_stage//./_}-germ_fail ${rep_id}.${processing_stage}.germ-fail.airr.tsv "${rep_id} Create Germlines Failed AIRR TSV (${processing_stage})" "tsv" null
                fi
                #noArchive mutational_config.${rep_id}.${processing_stage}.json
            fi

            count=$(( $count + 1 ))
        done
        addFileEntries mutation_entries.csv

        echo "Calculate mutational summaries"

        if [[ $has_makedb_clone -eq 1 ]]; then
            processing_stage=igblast.makedb.allele.clone.mutations
            # generate config
            if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                python3 repcalc_create_config.py --init mutational_analysis_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --stage ${processing_stage} mutational_analysis.${processing_stage}.json
            else
                python3 repcalc_create_config.py --init mutational_analysis_template.json ${AIRRMetadata} --stage ${processing_stage} mutational_analysis.${processing_stage}.json
            fi
            #noArchive mutational_analysis.${processing_stage}.json
            $REPCALC_EXE mutational_analysis.${processing_stage}.json

            addLogFile $APP_NAME log ${processing_stage//./_}-mutation_count ${processing_stage}.repertoire.count.mutational_report.csv "Mutational Count Statistics (${processing_stage})" "csv" null
            addLogFile $APP_NAME log ${processing_stage//./_}-mutation_frequency ${processing_stage}.repertoire.frequency.mutational_report.csv "Mutational Frequency Statistics (${processing_stage})" "csv" null
        fi

        if [[ $has_gene_clone -eq 1 ]]; then
            processing_stage=igblast.makedb.gene.clone.mutations
            # generate config
            if [ "x${RepertoireGroupMetadata}" != "x" ]; then
                python3 repcalc_create_config.py --init mutational_analysis_template.json ${AIRRMetadata} --group ${RepertoireGroupMetadata} --stage ${processing_stage} mutational_analysis.${processing_stage}.json
            else
                python3 repcalc_create_config.py --init mutational_analysis_template.json ${AIRRMetadata} --stage ${processing_stage} mutational_analysis.${processing_stage}.json
            fi
            #noArchive mutational_analysis.${processing_stage}.json
            $REPCALC_EXE mutational_analysis.${processing_stage}.json

            addLogFile $APP_NAME log ${processing_stage//./_}-mutation_count ${processing_stage}.repertoire.count.mutational_report.csv "Mutational Count Statistics (${processing_stage})" "csv" null
            addLogFile $APP_NAME log ${processing_stage//./_}-mutation_frequency ${processing_stage}.repertoire.frequency.mutational_report.csv "Mutational Frequency Statistics (${processing_stage})" "csv" null
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

#     # chart data files
#     # the for loop is simple technique to check for wildcard files
#     for f in *.clones.lineage.*.rda; do
#         zip lineage_data.zip *.clones.lineage.*.rda
#         addOutputFile $APP_NAME lineage chart_data lineage_data.zip "Lineage Reconstruction chart data" "Rdata" null
#         break
#     done
#     for f in *.clones.mutational.*.tsv; do
#         zip observed_mutations_data.zip *.clones.mutational.*.tsv
#         addOutputFile $APP_NAME observed_mutations chart_data observed_mutations_data.zip "Observed Mutations chart data" "tsv" null
#         break
#     done
#     for f in *.clones.selection.*.tsv; do
#         zip selection_pressure_data.zip *.clones.selection.*.tsv
#         addOutputFile $APP_NAME selection_pressure chart_data selection_pressure_data.zip "Selection Pressure chart data" "tsv" null
#         break
#     done

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
    cp -f process_metadata.json ${_tapisJobUUID}
    cp -f ${AIRRMetadata} ${_tapisJobUUID}
    cp -f ${germline_db} ${_tapisJobUUID}
    zip ${_tapisJobUUID}.zip ${_tapisJobUUID}/*
    addLogFile $APP_NAME log output_archive ${_tapisJobUUID}.zip "Archive of Output Files" "zip" null
    cp ${_tapisJobUUID}.zip output
}
