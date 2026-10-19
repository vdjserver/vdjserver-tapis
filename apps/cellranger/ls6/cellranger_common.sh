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

# bring in common functions
source ./common_functions.sh

# bring in provenance functions
source ./provenance_functions.sh

# bring in igblast setup functions
source ./igblast_config.sh
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
    echo "cellranger_image=${cellranger_image}"
    echo "repcalc_image=${repcalc_image}"
    echo "germline_archives=${germline_archives}"
    echo "analysis_provenance=${analysis_provenance}"
    echo "AIRRMetadata=${AIRRMetadata}"
    echo "ForwardPairedFiles=${ForwardPairedFiles}"
    echo "ReversePairedFiles=${ReversePairedFiles}"

    echo ""
    echo "Application parameters:"
    echo "species=$species"
    echo "strain=$strain"
    echo "locus=$locus"
    echo "germline_db=${germline_db}"
    echo "germline_db_file=${germline_db_file}"
    echo "germline_fasta=${germline_fasta}"
}

function run_cellranger_workflow() {
    addCalculation "${ACTIVITY_NAME}" vdj_alignment

    ########################################
    # Parse input paired lists
    ########################################

    ForwardPairedFiles="${ForwardPairedFiles% }"
    ReversePairedFiles="${ReversePairedFiles% }"

    IFS=' ' read -r -a FWD <<< "$ForwardPairedFiles"
    IFS=' ' read -r -a REV <<< "$ReversePairedFiles"

    ##############################################################
    # Check if both forward and reverse file count match
    ##############################################################

    if [ "${#FWD[@]}" -ne "${#REV[@]}" ]; then
        echo "ERROR: Forward and Reverse file counts do not match"
        echo "FWD: ${#FWD[@]} REV: ${#REV[@]}"
        exit 1
    fi

    echo "Found ${#FWD[@]} paired samples"

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

    ########################################
    # Reference selection
    ########################################

    if [[ "$species" == "NCBITAXON:9606" ]]; then
        reference_dir=$PWD/$HUMAN_VDJ_REFDATA
    else
        reference_dir=$PWD/$MOUSE_VDJ_REFDATA
    fi

    echo "Species: $species"
    echo "Using reference: $reference_dir"

    ########################################
    # Main loop over samples
    ########################################

    for i in "${!FWD[@]}"; do
        ForwardPairedFile="${FWD[$i]}"
        ReversePairedFile="${REV[$i]}"
        echo "------------------------------------"
        echo "Processing pair $((i+1))"
        echo "R1: $ForwardPairedFile"
        echo "R2: $ReversePairedFile"

        ######################################################
        # Find repertoire_id for the fastq file
        ######################################################

        repertoire_id=$(getRepertoireForFile "$ForwardPairedFile")
        echo "Repertoire ID: $repertoire_id"

        ##################################################################
        # Rename sequence files to match what cellranger format
        ##################################################################

        fileExtension="${ForwardPairedFile#*.}" # file.fastq.gz => fastq.gz
        forwardFile=${repertoire_id}_S1_L001_R1_001.${fileExtension}

        fileExtension="${ReversePairedFile#*.}" # file.fastq.gz => fastq.gz
        reverseFile="${repertoire_id}_S1_L001_R2_001.${fileExtension}"

        mv "${ForwardPairedFile}" "${forwardFile}"
        mv "${ReversePairedFile}" "${reverseFile}"

        ####################################
        # Run Cell Ranger VDJ
        # With the chain parameter, cellranger should only produce output for one locus
        ####################################
        echo "Starting cellranger for $repertoire_id at $(date)"

        echo cellranger vdj --id "${repertoire_id}" --reference "${reference_dir}" --fastqs $PWD --sample "${repertoire_id}" --chain "$locus" --localmem $CELLRANGER_MEM 
        $CELLRANGER_EXE vdj --id "${repertoire_id}" --reference "${reference_dir}" --fastqs $PWD --sample "${repertoire_id}" --chain "$locus" --localmem $CELLRANGER_MEM 

        # check number of jobs to be run
        export LAUNCHER_PPN=$LAUNCHER_MAX_PPN
        numJobs=$(cat joblist | wc -l)
        if [ $numJobs -lt $LAUNCHER_PPN ]; then
            export LAUNCHER_PPN=$numJobs
        fi

        # cellranger AIRR TSV
        cp "${repertoire_id}/outs/airr_rearrangement.tsv" "./${repertoire_id}.airr_rearrangement.tsv"
        wasDerivedFrom ${repertoire_id}.airr_rearrangement.tsv "${ForwardPairedFile}" "10x_airr_rearrangement" "10x Airr Rearrangement TSV" tsv

        #######################################################################
        # Extract sequence for IGBlast from 10x AIRR TSV
        #######################################################################

        $PYTHON3_EXE airr_extract_fasta.py ${repertoire_id}.airr_rearrangement.tsv ${repertoire_id}

        #############################################
        # We want more annotations than cellranger gives, so run igblast on the output
        #############################################
        if [ -f ${repertoire_id}.fasta ]; then
            configure_igblast "$locus" "$species" "$germline_db"

            echo "Locus: $locus"
            echo "IgBLAST params: $IGBLAST_PARAMS"

            # igblast job with AIRR output
            AIRR_ARGS="-query ${repertoire_id}.fasta $IGBLAST_PARAMS -outfmt 19"
            echo "$IGBLASTN_EXE $AIRR_ARGS > ${repertoire_id}.10x.igblast.airr.tsv"
            $IGBLASTN_EXE $AIRR_ARGS > "${repertoire_id}.10x.igblast.airr.tsv"

            # igblast job with ChangeO output
            CO_ARGS="-query ${repertoire_id}.fasta $IGBLAST_PARAMS -outfmt"
            OUTFMT="7 qseqid qgi qacc qaccver qlen sseqid sallseqid sgi sallgi sacc saccver sallacc slen qstart qend sstart send qseq sseq evalue bitscore score length pident nident mismatch positive gapopen gaps ppos frames qframe sframe btop"
            echo "$IGBLASTN_EXE $CO_ARGS \"$OUTFMT\" > ${repertoire_id}.10x.igblast.makedb.airr.tsv"
            $IGBLASTN_EXE $CO_ARGS "$OUTFMT" > ${repertoire_id}.10x.igblast.txt

            ###########################################################################
            # Makedb parsing and processing
            ###########################################################################

            MDARGS=""
            MDARGS="$MDARGS ${repertoire_id}.fasta"
            MDARGS="$MDARGS ${repertoire_id}.10x.igblast.txt"
            MDARGS="$MDARGS $locus"
            MDARGS="$MDARGS $species"
            MDARGS="$MDARGS $germline_db"

            # the post processing jobs
            apptainer exec ${repcalc_image} bash ./do_airr_makedb.sh $MDARGS
        fi

        #############################################
        # Merge with 10x annotations into one file
        #############################################
        
        $PYTHON3_EXE 10x_merge_airr.py ${repertoire_id} "${_tapisJobUUID}" "igblast" #changed data_processing_id to _tapisJobUUID
        $PYTHON3_EXE 10x_merge_airr.py ${repertoire_id} "${_tapisJobUUID}" "igblast.makedb" #changed data_processing_id to _tapisJobUUID

        gzip ${repertoire_id}.igblast.airr.tsv
        wasDerivedFrom "${repertoire_id}.igblast.airr.tsv.gz" "${repertoire_id}.airr_rearrangement.tsv" "vdj_sequence_annotation" "IgBlast AIRR TSV" tsv
        gzip ${repertoire_id}.igblast.makedb.airr.tsv
        wasDerivedFrom "${repertoire_id}.igblast.makedb.airr.tsv.gz" "${repertoire_id}.airr_rearrangement.tsv" "makedb_parse,vdj_sequence_annotation" "Change-O MakeDb AIRR TSV" tsv

        # Add all of the CellRanger output files to provenance
        mkdir ${_tapisJobUUID}/${repertoire_id}
        cp -rf ${repertoire_id}/outs ${_tapisJobUUID}/${repertoire_id}

        cp ${repertoire_id}/outs/web_summary.html ./${repertoire_id}.web_summary.html
        wasDerivedFrom ${repertoire_id}.web_summary.html ${repertoire_id}.airr_rearrangement.tsv "10x_web_summary" "${repertoire_id} 10X Run Summary HTML" "html"

        cp ${repertoire_id}/outs/metrics_summary.csv ./${repertoire_id}.metrics_summary.csv
        wasDerivedFrom ${repertoire_id}.metrics_summary.csv ${repertoire_id}.airr_rearrangement.tsv "10x_metrics_summary" "${repertoire_id} 10X Run Summary CSV" "csv"

        cp ${repertoire_id}/outs/clonotypes.csv ./${repertoire_id}.clonotypes.csv
        wasDerivedFrom ${repertoire_id}.clonotypes.csv ${repertoire_id}.airr_rearrangement.tsv "10x_clonotypes" "${repertoire_id} 10X Clonotypes" "csv"

        cp ${repertoire_id}/outs/consensus_annotations.csv ./${repertoire_id}.consensus_annotations.csv
        wasDerivedFrom ${repertoire_id}.consensus_annotations.csv ${repertoire_id}.airr_rearrangement.tsv "10x_consensus_annotations" "${repertoire_id} 10X Clonotypes Consensus Annotations" "csv"
        cp ${repertoire_id}/outs/filtered_contig_annotations.csv ./${repertoire_id}.filtered_contig_annotations.csv
        wasDerivedFrom ${repertoire_id}.filtered_contig_annotations.csv ${repertoire_id}.airr_rearrangement.tsv "10x_filtered_contigs" "${repertoire_id} 10X Filtered Contigs" "csv"

        cp ${repertoire_id}/outs/vloupe.vloupe ./${repertoire_id}.vloupe.vloupe
        wasDerivedFrom ${repertoire_id}.vloupe.vloupe ${repertoire_id}.airr_rearrangement.tsv "10x_vloupe" "${repertoire_id} 10X Loupe V(D)J Browser file" "vloupe"
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

    echo "ARCHIVE_FILE_LIST: $ARCHIVE_FILE_LIST"

    # zip archive of all output files
    for file in $ARCHIVE_FILE_LIST; do
        if [ -f $file ]; then
            cp -f $file ${_tapisJobUUID}
            cp -f $file output
        fi
    done

    cp -f ${germline_db_file} ${_tapisJobUUID}
    zip ${_tapisJobUUID}.zip ${_tapisJobUUID}/*
    cp ${_tapisJobUUID}.zip output
}