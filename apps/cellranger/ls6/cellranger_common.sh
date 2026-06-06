#
# CellRanger common functions
#
# This script relies upon global variables
# source cellranger_common.sh
#
# Author: Scott Christley
# Date: Jun 04, 2026
# 

APP_NAME=cellranger

export ACTIVITY_NAME="vdjserver:activity:cellranger"


# IgBlast germline database and extra files
# VDJ_DB_VERSION=db.2019.01.23
# IGDATA="$WORK/../common/igblast-db/$VDJ_DB_VERSION"
# export IGDATA
# export VDJ_DB_ROOT="$IGDATA/germline/"

# bring in common functions
source ./common_functions.sh

# bring in provenance functions
source ./provenance_functions.sh
# ----------------------------------------------------------------------------

# ----------------------------------------------------------------------------
# CellRanger workflow

function print_versions() {
    echo "VERSIONS:"
    echo "  $($PYTHON --version 2>&1)"
    echo "  $($IGBLASTN_EXE -version 2>&1)"
    echo "  $($AIRR_TOOLS_EXE --version 2>&1)"
    apptainer exec -e ${cellranger_image} cellranger --version
    apptainer exec -e ${repcalc_image} igblastn -version
    apptainer exec -e ${repcalc_image} airr-tools --version
    echo -e "\nSTART at $(date)"
}

function print_parameters() {
    echo "Input files:"
    echo "repcalc_image=${cellranger_image}"
    echo "repcalc_image=${repcalc_image}"
    echo "germline_archives=${germline_archives}"
    echo "analysis_provenance=${analysis_provenance}"
    echo "AIRRMetadata=${AIRRMetadata}"
    echo "ForwardPairedFile=${ForwardPairedFile}"
    echo "ReversePairedFile=${ReversePairedFile}"

    echo ""
    echo "Application parameters:"
    echo "species=$species"
    echo "strain=$strain"
    echo "germline_db_TR=${germline_db_TR}"
    echo "germline_db_IG=${germline_db_IG}"
}

function run_cellranger_workflow() {
    # initProcessMetadata
    # addLogFile $APP_NAME log stdout "${AGAVE_LOG_NAME}.out" "Job Output Log" "log" null
    # addLogFile $APP_NAME log stderr "${AGAVE_LOG_NAME}.err" "Job Error Log" "log" null
    # addLogFile $APP_NAME log agave_log .agave.log "Agave Output Log" "log" null
    # addCalculation vdj_alignment
    addCalculation "${ACTIVITY_NAME}" vdj_alignment

    # launcher job file
    if [ -f joblist ]; then
        echo "Warning: removing file 'joblist'.  That filename is reserved." 1>&2
        rm joblist
    fi
    touch joblist

    if [ -f joblist-post-process ]; then
        echo "Warning: removing file 'joblist-post-process'.  That filename is reserved." 1>&2
        rm joblist-post-process
    fi
    touch joblist-post-process

    ## Find repertoire_id for the fastq file
    repertoire_id=$(getRepertoireForFile $ForwardPairedFile)

    # # rename sequence files to match what cellranger wants
    # fileExtension="${ForwardPairedFile#*.}" # file.fastq.gz => fastq.gz
    # forwardFile=${repertoire_id}_S1_L001_R1_001.${fileExtension}
    # mv ${ForwardPairedFile} ${forwardFile}
    # noArchive ${forwardFile}

    # fileExtension="${ReversePairedFile#*.}" # file.fastq.gz => fastq.gz
    # reverseFile=${repertoire_id}_S1_L001_R2_001.${fileExtension}
    # mv ${ReversePairedFile} ${reverseFile}
    # noArchive ${reverseFile}

    # assume human
    reference_dir=$PWD/$HUMAN_VDJ_REFDATA
    if [[ "$species" == "mouse" ]]; then
        reference_dir=$PWD/$MOUSE_VDJ_REFDATA
    fi

    echo "Starting cellranger on $(date)"

    echo cellranger vdj --id ${repertoire_id} --reference ${reference_dir} --fastqs $PWD --localmem $CELLRANGER_MEM 
    $CELLRANGER_EXE vdj --id ${repertoire_id} --reference ${reference_dir} --fastqs $PWD --localmem $CELLRANGER_MEM 
    # noArchive ${repertoire_id}

    # check number of jobs to be run
    export LAUNCHER_PPN=$LAUNCHER_MAX_PPN
    numJobs=$(cat joblist | wc -l)
    if [ $numJobs -lt $LAUNCHER_PPN ]; then
        export LAUNCHER_PPN=$numJobs
    fi
    # not using launcher yet
    #$LAUNCHER_DIR/paramrun

    # We want more annotations than cellranger gives, so run igblast on the output
    # scripts will separate TCR and IG
    cp ${repertoire_id}/outs/airr_rearrangement.tsv ./${repertoire_id}.airr_rearrangement.tsv

    wasDerivedFrom ${repertoire_id}.airr_rearrangement.tsv "${ForwardPairedFile}" "10x_airr_rearrangement" "10x Airr Rearrangement TSV" tsv

    $PYTHON3_EXE airr_extract_fasta.py ${repertoire_id}.airr_rearrangement.tsv ${repertoire_id}


    AIRR_MERGE=""
    if [ -f ${repertoire_id}_TCR.fasta ]; then
        ## Setup the germline here
        setup_germline "${germline_db_TR}"
        ClonalTool=repcalc
        organism=${species}
        germline_set=${species}
        seqType=TR
        domain_system=imgt
        QUERY_ARGS=""
        ARGS=""
        QUERY_ARGS="-query ${repertoire_id}_TCR.fasta"
        ARGS="$ARGS -ig_seqtype TCR"
        if [ -n $organism ]; then 
            ARGS="$ARGS -organism $organism"
            ARGS="$ARGS -auxiliary_data $IGDATA/optional_file/${germline_set}_gl.aux"
            ARGS="$ARGS -germline_db_V $VDJ_DB_ROOT/${germline_set}/ReferenceDirectorySet/${germline_set}_${seqType}_V.fna"
            ARGS="$ARGS -germline_db_D $VDJ_DB_ROOT/${germline_set}/ReferenceDirectorySet/${germline_set}_${seqType}_D.fna"
            ARGS="$ARGS -germline_db_J $VDJ_DB_ROOT/${germline_set}/ReferenceDirectorySet/${germline_set}_${seqType}_J.fna"

            # If locus is TR then use old auxilary data file. Later we might need to rethink when ORGDB has TCR data
            if [ "$germline_db_TR" == "db.2019.01.23" ]; then
                ARGS="$ARGS -auxiliary_data $IGDATA/optional_file/${germline_set}_gl.aux"
            fi

            # for newer version of igblast we need an extra argument
            if [ "$germline_db_IG" == "db.2026.01.12" ]; then
                ARGS="$ARGS -c_region_db  $VDJ_DB_ROOT/${germline_set}/ReferenceDirectorySet/${germline_set}_${locus}_C.fna"
                ARGS="$ARGS -auxiliary_data  $VDJ_DB_ROOT/${germline_set}/ReferenceDirectorySet/${germline_set}_${locus}.aux"
                ARGS="$ARGS -custom_internal_data $VDJ_DB_ROOT/${germline_set}/ReferenceDirectorySet/${germline_set}_${locus}.ndm"
            fi

        fi
        if [ -n $domain_system ]; then ARGS="$ARGS -domain_system $domain_system"; fi
        IGBLAST_PARAMS="$ARGS"

        # AIRR output
        AIRR_ARGS="$QUERY_ARGS $ARGS -outfmt 19"
        echo "$IGBLASTN_EXE $AIRR_ARGS > ${repertoire_id}.TCR.igblast.airr.tsv"
        $IGBLASTN_EXE $AIRR_ARGS > ${repertoire_id}.TCR.igblast.airr.tsv

        AIRR_MERGE="$AIRR_MERGE ${repertoire_id}.TCR.igblast.airr.tsv"
        # noArchive ${repertoire_id}_TCR.fasta
        # noArchive ${repertoire_id}.TCR.igblast.airr.tsv
    fi

    if [ -f ${repertoire_id}_IG.fasta ]; then
        setup_germline "${germline_db_IG}"
        ClonalTool=changeo

        organism=${species}
        germline_set=${species}
        seqType=IG
        domain_system=imgt
        QUERY_ARGS=""
        ARGS=""
        QUERY_ARGS="-query ${repertoire_id}_IG.fasta"
        ARGS="$ARGS -ig_seqtype Ig"
        if [ -n $organism ]; then 
            ARGS="$ARGS -organism $organism"
            ARGS="$ARGS -auxiliary_data $IGDATA/optional_file/${germline_set}_gl.aux"
            ARGS="$ARGS -germline_db_V $VDJ_DB_ROOT/${germline_set}/ReferenceDirectorySet/${germline_set}_${seqType}_V.fna"
            ARGS="$ARGS -germline_db_D $VDJ_DB_ROOT/${germline_set}/ReferenceDirectorySet/${germline_set}_${seqType}_D.fna"
            ARGS="$ARGS -germline_db_J $VDJ_DB_ROOT/${germline_set}/ReferenceDirectorySet/${germline_set}_${seqType}_J.fna"

            # If locus is TR then use old auxilary data file.
            if [ "$germline_db_TR" == "db.2019.01.23" ]; then
                ARGS="$ARGS -auxiliary_data $IGDATA/optional_file/${germline_set}_gl.aux"
            fi

            # for newer version of igblast we need an extra argument
            if [ "$germline_db_IG" == "db.2026.01.12" ]; then
                ARGS="$ARGS -c_region_db  $VDJ_DB_ROOT/${germline_set}/ReferenceDirectorySet/${germline_set}_${locus}_C.fna"
                ARGS="$ARGS -auxiliary_data  $VDJ_DB_ROOT/${germline_set}/ReferenceDirectorySet/${germline_set}_${locus}.aux"
                ARGS="$ARGS -custom_internal_data $VDJ_DB_ROOT/${germline_set}/ReferenceDirectorySet/${germline_set}_${locus}.ndm"
            fi
        fi
        if [ -n $domain_system ]; then ARGS="$ARGS -domain_system $domain_system"; fi
        IGBLAST_PARAMS="$ARGS"

        # AIRR output
        AIRR_ARGS="$QUERY_ARGS $ARGS -outfmt 19"
        echo "$IGBLASTN_EXE $AIRR_ARGS > ${repertoire_id}.IG.igblast.airr.tsv"
        $IGBLASTN_EXE $AIRR_ARGS > ${repertoire_id}.IG.igblast.airr.tsv

        AIRR_MERGE="$AIRR_MERGE ${repertoire_id}.IG.igblast.airr.tsv"
        # noArchive ${repertoire_id}_IG.fasta
        # noArchive ${repertoire_id}.IG.igblast.airr.tsv
    fi

    # Merge with 10x annotations into one file
    $AIRR_TOOLS_EXE merge -a $AIRR_MERGE -o ${repertoire_id}.igblast.airr.tsv
    $PYTHON3_EXE 10x_merge_airr.py ${repertoire_id}.airr_rearrangement.tsv ${repertoire_id}.igblast.airr.tsv ${repertoire_id}.10x.igblast.airr.tsv
    # noArchive ${repertoire_id}.igblast.airr.tsv
    gzip ${repertoire_id}.10x.igblast.airr.tsv
    # addOutputFile group0 $APP_NAME airr ${repertoire_id}.10x.igblast.airr.tsv.gz "${repertoire_id} IgBlast AIRR TSV" "tsv" null
    wasDerivedFrom "${repertoire_id}.10x.igblast.airr.tsv.gz" "${repertoire_id}.airr_rearrangement.tsv" "vdj_sequence_annotation" "IgBlast AIRR TSV" tsv

    # Add all of the CellRanger output files to provenance
    mkdir ${_tapisJobUUID}/${repertoire_id}
    cp -rf ${repertoire_id}/outs ${_tapisJobUUID}/${repertoire_id}
    addOutputFile group0 $APP_NAME 10x_airr ${repertoire_id}.airr_rearrangement.tsv "${repertoire_id} 10X AIRR TSV" "tsv" null

    cp ${repertoire_id}/outs/web_summary.html ./${repertoire_id}.web_summary.html
    # addOutputFile group0 $APP_NAME 10x_web_summary ${repertoire_id}.web_summary.html "${repertoire_id} 10X Run Summary HTML" "html" null
    wasDerivedFrom ${repertoire_id}.web_summary.html ${repertoire_id}.airr_rearrangement.tsv "10x_web_summary" "${repertoire_id} 10X Run Summary HTML" "html"

    cp ${repertoire_id}/outs/metrics_summary.csv ./${repertoire_id}.metrics_summary.csv
    # addOutputFile group0 $APP_NAME 10x_metrics_summary ${repertoire_id}.metrics_summary.csv "${repertoire_id} 10X Run Summary CSV" "csv" null
    wasDerivedFrom ${repertoire_id}.metrics_summary.csv ${repertoire_id}.airr_rearrangement.tsv "10x_metrics_summary" "${repertoire_id} 10X Run Summary CSV" "csv"

    cp ${repertoire_id}/outs/clonotypes.csv ./${repertoire_id}.clonotypes.csv
    # addOutputFile group0 $APP_NAME 10x_clonotypes ${repertoire_id}_.lonotypes.csv "${repertoire_id} 10X Clonotypes" "csv" null
    wasDerivedFrom ${repertoire_id}_.lonotypes.csv ${repertoire_id}.airr_rearrangement.tsv "10x_clonotypes" "${repertoire_id} 10X Clonotypes" "csv"

    cp ${repertoire_id}/outs/consensus_annotations.csv ./${repertoire_id}.consensus_annotations.csv
    # addOutputFile group0 $APP_NAME 10x_consensus_annotations ${repertoire_id}.consensus_annotations.csv "${repertoire_id} 10X Clonotypes Consensus Annotations" "csv" null
    wasDerivedFrom ${repertoire_id}.consensus_annotations.csv ${repertoire_id}.airr_rearrangement.tsv "10x_consensus_annotations" "${repertoire_id} 10X Clonotypes Consensus Annotations" "csv"
    cp ${repertoire_id}/outs/filtered_contig_annotations.csv ./${repertoire_id}.filtered_contig_annotations.csv
    # addOutputFile group0 $APP_NAME 10x_filtered_contigs ${repertoire_id}.filtered_contig_annotations.csv "${repertoire_id} 10X Filtered Contigs" "csv" null
    wasDerivedFrom ${repertoire_id}.filtered_contig_annotations.csv ${repertoire_id}.airr_rearrangement.tsv "10x_filtered_contigs" "${repertoire_id} 10X Filtered Contigs" "csv"

    cp ${repertoire_id}/outs/vloupe.vloupe ./${repertoire_id}.vloupe.vloupe
    # addOutputFile group0 $APP_NAME 10x_vloupe ${repertoire_id}.vloupe.vloupe "${repertoire_id} 10X Loupe V(D)J Browser file" "vloupe" null
    wasDerivedFrom ${repertoire_id}.vloupe.vloupe ${repertoire_id}.airr_rearrangement.tsv "10x_vloupe" "${repertoire_id} 10X Loupe V(D)J Browser file" "vloupe"

    # # zip archive of all output files
    # for file in $ARCHIVE_FILE_LIST; do
    #     if [ -f $file ]; then
    #         cp -f $file ${_tapisJobUUID}
    #     fi
    # done
    # zip -r ${_tapisJobUUID}.zip ${_tapisJobUUID}/*
    # addLogFile $APP_NAME log output_archive ${_tapisJobUUID}.zip "Archive of Output Files" "zip" null
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
    cp -f ${germline_db_TR} ${_tapisJobUUID}
    cp -f ${germline_db_IG} ${_tapisJobUUID}
    zip ${_tapisJobUUID}.zip ${_tapisJobUUID}/*
    
    #addLogFile $APP_NAME log output_archive ${_tapisJobUUID}.zip "Archive of Output Files" "zip" null
    cp ${_tapisJobUUID}.zip output
    
}