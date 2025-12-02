#
# VDJServer pRESTO common functions
#
# VDJServer Analysis Portal
# VDJServer Tapis applications
# https://vdjserver.org
#
# This script relies upon global variables
# source presto_common.sh
#
# Copyright (C) 2016-2024 The University of Texas Southwestern Medical Center
# Author: Scott Christley
# Date: August 11, 2016
# 

export APP_NAME=presto
# TODO: this is not generic enough
export ACTIVITY_NAME="vdjserver:activity:presto"

# bring in common functions
source ./common_functions.sh

# bring in provenance functions
source ./provenance_functions.sh

# ----------------------------------------------------------------------------
# presto workflow

function print_versions() {
    # Start
    echo "VERSIONS:"
    echo "  $($ALIGN_SETS_PY --version 2>&1)"
    echo "  $($ASSEMBLE_PAIRS_PY --version 2>&1)"
    echo "  $($BUILD_CONSENSUS_PY --version 2>&1)"
    echo "  $($CLUSTER_SETS_PY --version 2>&1)"
    echo "  $($COLLAPSE_SEQ_PY --version 2>&1)"
    echo "  $($CONVERT_HEADERS_PY --version 2>&1)"
    echo "  $($FILTER_SEQ_PY --version 2>&1)"
    echo "  $($MASK_PRIMERS_PY --version 2>&1)"
    echo "  $($PAIR_SEQ_PY --version 2>&1)"
    echo "  $($PARSE_HEADERS_PY --version 2>&1)"
    echo "  $($PARSE_LOG_PY --version 2>&1)"
    echo "  $($SPLIT_SEQ_PY --version 2>&1)"
    echo "  $($VDJ_PIPE --version 2>&1)"
    echo -e "\nSTART at $(date)"
}

function print_parameters() {
    echo "Input files:"
    echo "singularity_image=${singularity_image}"
    echo "vdj_pipe_image=${vdj_pipe_image}"
    echo "ProjectDirectory=${ProjectDirectory}"
    echo "JobFiles=$JobFiles"
    echo "SequenceFiles=$SequenceFiles"
    echo "SequenceForwardPairedFiles=$SequenceForwardPairedFiles"
    echo "SequenceReversePairedFiles=$SequenceReversePairedFiles"
    echo "ForwardPrimerFile=$ForwardPrimerFile"
    echo "ReversePrimerFile=$ReversePrimerFile"
    echo "BarcodeFile=$BarcodeFile"
    echo ""
    echo "Application parameters:"
    echo "Workflow=$Workflow"
    echo "SequenceFileTypes=$SequenceFileTypes"
    echo "Pre-filter statistics:"
    echo "PreFilterStatisticsFlag=$PreFilterStatisticsFlag"
    echo "Filters:"
    echo "FilterFlag=$FilterFlag"
    echo "MinimumQuality=$MinimumQuality"
    echo "MinimumLength=$MinimumLength"
    echo "Post-filter statistics:"
    echo "PostFilterStatisticsFlag=$PostFilterStatisticsFlag"
    echo "Barcodes:"
    echo "Barcode=$Barcode"
    echo "BarcodeMaxError=$BarcodeMaxError"
    echo "BarcodeStartPosition=$BarcodeStartPosition"
    echo "BarcodeSplitFlag=$BarcodeSplitFlag"
    echo "UMI:"
    echo "UMIConsensus=$UMIConsensus"
    echo "UMIMaxError=$UMIMaxError"
    echo "UMIMaxGap=$UMIMaxGap"
    echo "UMIMinFrequency=$UMIMinFrequency"
    echo "Forward primer:"
    echo "ForwardPrimerFlag=$ForwardPrimerFlag"
    echo "ForwardPrimer=$ForwardPrimer"
    echo "ForwardPrimerMaxError=$ForwardPrimerMaxError"
    echo "ForwardPrimerMaxLength=$ForwardPrimerMaxLength"
    echo "ForwardPrimerStartPosition=$ForwardPrimerStartPosition"
    echo "Forward UMI primer:"
    echo "ForwardPrimerUMI=$ForwardPrimerUMI"
    echo "ForwardPrimerUMIStart=$ForwardPrimerUMIStart"
    echo "ForwardPrimerUMILength=$ForwardPrimerUMILength"
    echo "Reverse primer:"
    echo "ReversePrimerFlag=$ReversePrimerFlag"
    echo "ReversePrimer=$ReversePrimer"
    echo "ReversePrimerMaxError=$ReversePrimerMaxError"
    echo "ReversePrimerMaxLength=$ReversePrimerMaxLength"
    echo "ReversePrimerStartPosition=$ReversePrimerStartPosition"
    echo "Reverse UMI primer:"
    echo "ReversePrimerUMI=$ReversePrimerUMI"
    echo "ReversePrimerUMIStart=$ReversePrimerUMIStart"
    echo "ReversePrimerUMILength=$ReversePrimerUMILength"
    echo "Find unique sequences:"
    echo "FindUniqueFlag=$FindUniqueFlag"
    echo "FindUniqueMaxNucleotides=$FindUniqueMaxNucleotides"
    echo "FindUniqueExclude=$FindUniqueExclude"
}

# Check for errors
check_presto_error() {
    if [ -s $ERROR_LOG ]; then
        echo -e "ERROR:"
        cat $ERROR_LOG | sed 's/^/    /'
        return 1
    fi
    return 0
}

# Takara Bio immune profiling kits with UMI
#
# https://www.takarabio.com/products/next-generation-sequencing/immune-profiling
# Bulk BCR, Bulk TCR
#
# Code is based upon pRESTO workflow in the Immcantation suite
#
function takara_bio_umi_workflow() {
    # this workflow calls the reverse reads as R1
    R2_READS=$1
    R1_READS=$2
    OUTNAME=$(basename ${R1_READS} | sed 's/\.[^.]*$//; s/_R[0-9]_[0-9]*//')
    count=$3

    # Argument defaults
    ALIGN_BARCODE=false
    NPROC=24
    COORD=$SequenceFileTypes

    if [ "$Workflow" = "takara_bio_umi_human_ig" ]; then
        VREF_SEQ="/usr/local/share/igblast/fasta/imgt_human_ig_v.fasta"
        C_PRIMERS="/usr/local/share/protocols/Universal/Human_IG_CRegion_RC.fasta"
    elif [ "$Workflow" = "takara_bio_umi_human_tr" ]; then
        VREF_SEQ="/usr/local/share/igblast/fasta/imgt_human_tr_v.fasta"
        C_PRIMERS="/usr/local/share/protocols/Universal/Human_TR_CRegion_RC.fasta"
    elif [ "$Workflow" = "takara_bio_umi_mouse_ig" ]; then
        VREF_SEQ="/usr/local/share/igblast/fasta/imgt_mouse_ig_v.fasta"
        C_PRIMERS="/usr/local/share/protocols/Universal/Mouse_IG_CRegion_RC.fasta"
    elif [ "$Workflow" = "takara_bio_umi_mouse_tr" ]; then
        VREF_SEQ="/usr/local/share/igblast/fasta/imgt_mouse_tr_v.fasta"
        C_PRIMERS="/usr/local/share/protocols/Universal/Mouse_TR_CRegion_RC.fasta"
    else
        echo "Unknown workflow: " $Workflow
        exit 1
    fi

    group="group${count}"
    addGroup $group file

    # TODO: need to add parameters to app

    # AssemblePairs-sequential run parameters
    AP_MAXERR=0.3
    AP_MINLEN=8
    AP_ALPHA=1e-5
    AP_MINIDENT=0.5
    AP_EVALUE=1e-5
    AP_MAXHITS=100

    # FilterSeq run parameters
    FS_QUAL=$MinimumQuality

    # MaskPrimers run parameters
    MP_MAXERR=$ReversePrimerMaxError
    MP_MAXLEN=$ReversePrimerMaxLength
    C_FIELD="C_CALL"

    # AlignSets run parameters
    MUSCLE_EXEC=muscle

    # CollapseSeq run parameters
    CS_MISS=0

    # BuildConsensus run parameters
    BC_QUAL=0
    BC_MINCOUNT=1
    BC_MAXERR=$UMIMaxError
    BC_PRCONS=$UMIMinFrequency
    BC_MAXGAP=$UMIMaxGap
    
    # Define log files
    LOGDIR="${OUTNAME}-logs"
    PIPELINE_LOG="${OUTNAME}-takara_bio_umi_workflow.log"
    ERROR_LOG="${OUTNAME}-takara_bio_umi_workflow.err"
    mkdir -p ${LOGDIR}
    echo '' > $PIPELINE_LOG
    echo '' > $ERROR_LOG

    STEP=0

    # Remove low quality reads
    printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 24 "FilterSeq quality"
    $FILTER_SEQ_PY quality -s $R1_READS -q $FS_QUAL --nproc $NPROC \
        --outname "${OUTNAME}-R1" --outdir . --log "${LOGDIR}/quality-R1.log" \
        >> $PIPELINE_LOG  2> $ERROR_LOG
    $FILTER_SEQ_PY quality -s $R2_READS -q $FS_QUAL --nproc $NPROC \
        --outname "${OUTNAME}-R2" --outdir . --log "${LOGDIR}/quality-R2.log" \
        >> $PIPELINE_LOG  2> $ERROR_LOG
    MPR1_FILE="${OUTNAME}-R1_quality-pass.fastq"
    MPR2_FILE="${OUTNAME}-R2_quality-pass.fastq"
    check_presto_error
    if [ $? -ne 0 ]; then
        return 1
    fi

    # Annotate -1 reads with internal C-region
    printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 24 "MaskPrimers align"
    $MASK_PRIMERS_PY align -s ${MPR1_FILE} \
        -p ${C_PRIMERS} \
        --maxlen ${MP_MAXLEN} --maxerror ${MP_MAXERR} \
        --mode cut --skiprc --pf ${C_FIELD} \
        --log "${LOGDIR}/primers-1.log" \
        --outname "${OUTNAME}-R1" --nproc ${NPROC} \
        --outdir .  >> $PIPELINE_LOG 2> $ERROR_LOG
    check_presto_error
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    # Identify primers and UMI in -2 reads
    printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 24 "MaskPrimers extract"
    $MASK_PRIMERS_PY extract -s ${MPR2_FILE} --nproc ${NPROC} \
        --start 12 --len 7 --barcode --bf BARCODE --mode cut \
        --log "${LOGDIR}/primers-2.log" \
        --outname "${OUTNAME}-R2" --outdir .  >> $PIPELINE_LOG 2> $ERROR_LOG
    check_presto_error
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    # Transfer annotation
    printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 24 "PairSeq"
    $PAIR_SEQ_PY -1 "${OUTNAME}-R2_primers-pass.fastq" \
        -2 "${OUTNAME}-R1_primers-pass.fastq" \
        --1f BARCODE --2f ${C_FIELD} --coord ${COORD}  >> $PIPELINE_LOG 2> $ERROR_LOG
    check_presto_error
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    # Multiple align UID read groups
    if $ALIGN_BARCODE; then
        printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 24 "AlignSets muscle"
        $ALIGN_SETS_PY muscle -s "${OUTNAME}-R1_primers-pass_pair-pass.fastq" --exec $MUSCLE_EXEC \
            --nproc $NPROC --log "${LOGDIR}/align-1.log" --outname "${OUTNAME}-R1" \
            >> $PIPELINE_LOG 2> $ERROR_LOG
        $ALIGN_SETS_PY muscle -s "${OUTNAME}-R2_primers-pass_pair-pass.fastq" --exec $MUSCLE_EXEC \
            --nproc $NPROC --log "${LOGDIR}/align-2.log" --outname "${OUTNAME}-R2" \
            >> $PIPELINE_LOG 2> $ERROR_LOG
        BCR1_FILE="${OUTNAME}-R1_align-pass.fastq"
        BCR2_FILE="${OUTNAME}-R2_align-pass.fastq"
        check_presto_error
        if [ $? -ne 0 ]; then
            return 1
        fi
    else
        BCR1_FILE="${OUTNAME}-R1_primers-pass_pair-pass.fastq"
        BCR2_FILE="${OUTNAME}-R2_primers-pass_pair-pass.fastq"
    fi
    
    # UMI consensus
    printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 24 "BuildConsensus"
    $BUILD_CONSENSUS_PY -s ${BCR1_FILE} \
        --bf BARCODE --pf ${C_FIELD} --prcons ${BC_PRCONS} \
        -n ${BC_MINCOUNT} -q ${BC_QUAL} --maxerror ${BC_MAXERR} --maxgap ${BC_MAXGAP}  \
        --nproc ${NPROC} --log "${LOGDIR}/consensus-1.log"  \
        --outdir . --outname "${OUTNAME}-R1" >> $PIPELINE_LOG 2> $ERROR_LOG
    $BUILD_CONSENSUS_PY -s ${BCR2_FILE} \
        --bf BARCODE --pf ${C_FIELD} --prcons ${BC_PRCONS} \
        -n ${BC_MINCOUNT} -q ${BC_QUAL} --maxerror ${BC_MAXERR} --maxgap ${BC_MAXGAP}  \
        --nproc ${NPROC} --log "${LOGDIR}/consensus-2.log" \
        --outdir . --outname "${OUTNAME}-R2" >> $PIPELINE_LOG 2> $ERROR_LOG
    check_presto_error
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    # Synchronize reads
    printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 24 "PairSeq"
    $PAIR_SEQ_PY -1 "${OUTNAME}-R1_consensus-pass.fastq" \
        -2 "${OUTNAME}-R2_consensus-pass.fastq" \
        --coord presto >> $PIPELINE_LOG 2> $ERROR_LOG
    check_presto_error
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    # Assemble pairs
    printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 24 "AssemblePairs sequential"
    $ASSEMBLE_PAIRS_PY sequential -1 "${OUTNAME}-R2_consensus-pass_pair-pass.fastq" \
        -2 "${OUTNAME}-R1_consensus-pass_pair-pass.fastq" \
        -r ${VREF_SEQ} \
        --coord presto --rc tail --1f CONSCOUNT --2f PRCONS CONSCOUNT \
        --minlen ${AP_MINLEN} --maxerror ${AP_MAXERR} --alpha $AP_ALPHA --scanrev \
        --minident ${AP_MINIDENT} --evalue ${AP_EVALUE} --maxhits ${AP_MAXHITS} --aligner blastn \
        --nproc  $NPROC --log "${LOGDIR}/assemble.log" \
        --outname "${OUTNAME}" >> $PIPELINE_LOG 2> $ERROR_LOG
    check_presto_error
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    # Rewrite header with minimum of CONSCOUNT
    printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 24 "ParseHeaders collapse"
    $PARSE_HEADERS_PY collapse -s "${OUTNAME}_assemble-pass.fastq" -f CONSCOUNT --act min \
        >> $PIPELINE_LOG 2> $ERROR_LOG
    check_presto_error
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    # Rename PRCONS to C_CALL
    printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 24 "ParseHeaders rename"
    $PARSE_HEADERS_PY rename -s "${OUTNAME}_assemble-pass_reheader.fastq" -f PRCONS -k C_CALL \
        -o "${OUTNAME}-final_total.fastq" >> $PIPELINE_LOG 2> $ERROR_LOG
    check_presto_error
    if [ $? -ne 0 ]; then
        return 1
    fi
    # addOutputFile $group $APP_NAME processed_sequence "${OUTNAME}-final_total.fastq" "Total Post-Filter Sequences (${OUTNAME})" "fastq" null
    wasDerivedFrom "${OUTNAME}-final_total.fastq" "${R1_READS}" "sequence_reads,sequence_quality" "Total Post-Filter Sequences (${OUTNAME})" "fastq"
    wasDerivedFrom "${OUTNAME}-final_total.fastq" "${R2_READS}" "sequence_reads,sequence_quality" "Total Post-Filter Sequences (${OUTNAME})" "fastq"
    
    # Remove duplicate sequences
    printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 24 "CollapseSeq"
    $COLLAPSE_SEQ_PY -s "${OUTNAME}-final_total.fastq" -n ${CS_MISS} \
        --uf C_CALL --cf CONSCOUNT --act sum --inner \
        --keepmiss --outname "${OUTNAME}-final" >> $PIPELINE_LOG 2> $ERROR_LOG
    check_presto_error
    if [ $? -ne 0 ]; then
        return 1
    fi
    # addOutputFile $group $APP_NAME sequence "${OUTNAME}-final_collapse-unique.fastq" "Unique Post-Filter Sequences (${OUTNAME})" "fastq" null
    wasDerivedFrom "${OUTNAME}-final_collapse-unique.fastq" "${OUTNAME}-final_total.fastq" "Unique Post-Filter Sequences (${OUTNAME})" "fastq" 

    # Subset to sequences seen at least twice
    printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 24 "SplitSeq"
    $SPLIT_SEQ_PY group -s "${OUTNAME}-final_collapse-unique.fastq" \
        -f CONSCOUNT --num 2 >> $PIPELINE_LOG 2> $ERROR_LOG
    check_presto_error
    if [ $? -ne 0 ]; then
        return 1
    fi
    # addOutputFile $group $APP_NAME sequence_ge2 "${OUTNAME}-final_collapse-unique_atleast-2.fastq" "Unique At Least 2 Post-Filter Sequences (${OUTNAME})" "fastq" null
    wasDerivedFrom "${OUTNAME}-final_collapse-unique_atleast-2.fastq" "${OUTNAME}-final_collapse-unique.fastq" "Unique At Least 2 Post-Filter Sequences (${OUTNAME})" "fastq" 
    # Create table of final repertoire
    printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 24 "ParseHeaders table"
    $PARSE_HEADERS_PY table -s "${OUTNAME}-final_total.fastq" -f ID ${C_FIELD} CONSCOUNT \
        --outname "final-total" --outdir ${LOGDIR} >> $PIPELINE_LOG 2> $ERROR_LOG
    $PARSE_HEADERS_PY table -s "${OUTNAME}-final_collapse-unique.fastq" -f ID ${C_FIELD} CONSCOUNT DUPCOUNT \
        --outname "final-unique" --outdir ${LOGDIR} >> $PIPELINE_LOG 2> $ERROR_LOG
    $PARSE_HEADERS_PY table -s "${OUTNAME}-final_collapse-unique_atleast-2.fastq" -f ID ${C_FIELD} CONSCOUNT DUPCOUNT \
        --outname "final-unique-atleast2" --outdir ${LOGDIR} >> $PIPELINE_LOG 2> $ERROR_LOG
    check_presto_error
    if [ $? -ne 0 ]; then
        return 1
    fi

    return 0
}

# Generic VDJServer pRESTO single workflow
#
function single_presto_workflow() {
    file=$1
    count=$2

    group="group${count}"
    addGroup $group file

    # uncompress if needed
    expandfile $file

    # presto needs extension to be fastq
    testExt="${file##*.}" # file.fq -> fq
    if [ "$testExt" != "fastq" ]; then
        echo "Warning: Renaming file to have fastq extension"
        cp $file ${file}.fastq
        file=${file}.fastq
    fi

    fileExtension="${file##*.}" # file.fastq -> fastq
    fileBasename="${file%.*}" # file.fastq -> file
    fileOutname="${fileBasename##*/}" # test/file -> file
    filePrefix="${file%/*}" # test/file -> file, or file -> file
    if [ "$filePrefix" == "$file" ]; then
        # no directory in filename
        filePrefix=""
    fi

    # attach prefix
    OutputPrefix=$fileOutname
    if [ -n "${filePrefix}" ]; then
        OutputName="${filePrefix}/${fileOutname}"
    else
        OutputName="${fileOutname}"
    fi

    # Run vdjpipe to generate statistics
    if [[ $PreFilterStatisticsFlag -eq 1 ]]; then
        echo "Generate pre-filter statistics"

        $PYTHON3 ./statistics.py statistics-template.json $file "pre-filter_" "pre-statistics.json"
        

        
        # addStatisticsFile $group pre composition "pre-filter_${file}.composition.csv" "Nucleotide Composition" "tsv" null
        # addStatisticsFile $group pre gc_hist "pre-filter_${file}.gc_hist.csv" "GC% Histogram" "tsv" null
        # addStatisticsFile $group pre heat_map "pre-filter_${file}.heat_map.csv" "Heatmap" "tsv" null
        # addStatisticsFile $group pre len_hist "pre-filter_${file}.len_hist.csv" "Sequence Length Histogram" "tsv" null
        # addStatisticsFile $group pre mean_q_hist "pre-filter_${file}.mean_q_hist.csv" "Mean Quality Histogram" "tsv" null
        # addStatisticsFile $group pre qstats "pre-filter_${file}.qstats.csv" "Quality Scores" "tsv" null

        wasGeneratedBy "pre-filter_${file}.composition.csv" "${ACTIVITY_NAME}" "quality_statistics,composition" "Nucleotide Composition" "tsv"
        wasGeneratedBy "pre-filter_${file}.gc_hist.csv" "${ACTIVITY_NAME}" "quality_statistics,gc_histogram" "GC% Histogram" tsv
        wasGeneratedBy "pre-filter_${file}.heat_map.csv" "${ACTIVITY_NAME}" "quality_statistics,heatmap" "Heatmap" tsv
        wasGeneratedBy "pre-filter_${file}.len_hist.csv" "${ACTIVITY_NAME}" "quality_statistics,length_histogram" "Sequence Length Histogram" tsv
        wasGeneratedBy "pre-filter_${file}.mean_q_hist.csv" "${ACTIVITY_NAME}" "quality_statistics,mean_quality_histogram" "Mean Quality Histogram" tsv
        wasGeneratedBy "pre-filter_${file}.qstats.csv" "${ACTIVITY_NAME}" "quality_statistics" "Quality Scores" tsv

        $VDJ_PIPE --config pre-statistics.json
        addCalculation "${ACTIVITY_NAME}" "pre-filter_statistics"
    fi

    prevPassFile=$file

    # Filter sequences for quality and length
    if [[ $FilterFlag -eq 1 ]]; then
        ARGS="length --nproc 1"
        if [ -n "$MinimumLength" ]; then
            ARGS="${ARGS} -n $MinimumLength"
        fi
        ARGS="${ARGS} --outname $OutputPrefix"
        ARGS="${ARGS} -s $prevPassFile"
        echo FilterSeq.py $ARGS
        $FILTER_SEQ_PY $ARGS
        addCalculation "${ACTIVITY_NAME}" "length_filtering"

        intermediateFiles[${#intermediateFiles[@]}]=$prevPassFile
        prevPassFile="${OutputName}_length-pass.${fileExtension}"

        ARGS="quality --nproc 1"
        if [ -n "$MinimumQuality" ]; then
            ARGS="${ARGS} -q $MinimumQuality"
        fi
        ARGS="${ARGS} --outname $OutputPrefix"
        ARGS="${ARGS} -s $prevPassFile"
        echo FilterSeq.py $ARGS
        $FILTER_SEQ_PY $ARGS
        addCalculation "${ACTIVITY_NAME}" "quality_filtering"

        intermediateFiles[${#intermediateFiles[@]}]=$prevPassFile
        prevPassFile="${OutputName}_quality-pass.${fileExtension}"
    fi

    # Run vdjpipe to generate statistics
    if [[ $PostFilterStatisticsFlag -eq 1 ]]; then
        echo "Generate post-filter statistics"

        $PYTHON3 ./statistics.py statistics-template.json $prevPassFile "post-filter_" "post-statistics.json"
        # addStatisticsFile $group post composition "post-filter_${prevPassFile}.composition.csv" "Nucleotide Composition" "tsv" null
        # addStatisticsFile $group post gc_hist "post-filter_${prevPassFile}.gc_hist.csv" "GC% Histogram" "tsv" null
        # addStatisticsFile $group post heat_map "post-filter_${prevPassFile}.heat_map.csv" "Heatmap" "tsv" null
        # addStatisticsFile $group post len_hist "post-filter_${prevPassFile}.len_hist.csv" "Sequence Length Histogram" "tsv" null
        # addStatisticsFile $group post mean_q_hist "post-filter_${prevPassFile}.mean_q_hist.csv" "Mean Quality Histogram" "tsv" null
        # addStatisticsFile $group post qstats "post-filter_${prevPassFile}.qstats.csv" "Quality Scores" "tsv" null

        wasGeneratedBy "post-filter_${prevPassFile}.composition.csv" "${ACTIVITY_NAME}" "quality_statistics,composition" "Nucleotide Composition" tsv
        wasGeneratedBy "post-filter_${prevPassFile}.gc_hist.csv" "${ACTIVITY_NAME}" "quality_statistics,gc_histogram" "GC% Histogram" tsv
        wasGeneratedBy "post-filter_${prevPassFile}.heat_map.csv" "${ACTIVITY_NAME}" "quality_statistics,heatmap" "Heatmap" tsv
        wasGeneratedBy "post-filter_${prevPassFile}.len_hist.csv" "${ACTIVITY_NAME}" "quality_statistics,length_histogram" "Sequence Length Histogram" tsv
        wasGeneratedBy "post-filter_${prevPassFile}.mean_q_hist.csv" "${ACTIVITY_NAME}" "quality_statistics,mean_quality_histogram" "Mean Quality Histogram" tsv
        wasGeneratedBy "post-filter_${prevPassFile}.qstats.csv" "${ACTIVITY_NAME}" "quality_statistics" "Quality Scores" tsv

        $VDJ_PIPE --config post-statistics.json
        addCalculation "${ACTIVITY_NAME}" "post-filter_statistics"
    fi

    EXPAND_PRIMER=

    # Barcode
    if [[ $Barcode -eq 1 ]]; then
        echo "Processing barcodes"
        if [ -z "$BarcodeFile" ]; then
            echo "ERROR: Missing the required Barcode file."
            exit
        fi

        # presto needs extension to be fasta
        testExt="${BarcodeFile##*.}" # file.fasta -> fasta
        if [ "$testExt" != "fasta" ]; then
            echo "Warning: Renaming barcode file to have fasta extension"
            cp $BarcodeFile ${BarcodeFile}.fasta
            BarcodeFile=${BarcodeFile}.fasta
        fi

        ARGS="score --nproc 1 -p $BarcodeFile -s $prevPassFile"
        if [ -n "$BarcodeMaxError" ]; then
            ARGS="${ARGS} --maxerror $BarcodeMaxError"
        fi
        if [ -n "$BarcodeStartPosition" ]; then
            ARGS="${ARGS} --start $BarcodeStartPosition"
        fi
        ARGS="${ARGS} --outname ${OutputPrefix}-barcode --mode cut"
        echo MaskPrimers.py $ARGS
        $MASK_PRIMERS_PY $ARGS
        addCalculation "${ACTIVITY_NAME}" "barcode_demultiplexing"

        intermediateFiles[${#intermediateFiles[@]}]=$prevPassFile
        prevPassFile="${OutputName}-barcode_primers-pass.${fileExtension}"
        EXPAND_PRIMER=1
    fi

    # Forward Primers
    if [ -n "$ForwardPrimer" ]; then
        if [ "$ForwardPrimer" != "none" ]; then
            echo "Mask forward primers"
            if [ -z "$ForwardPrimerFile" ]; then
                echo "ERROR: Missing the required forward primer file."
                exit
            fi

            # presto needs extension to be fasta
            testExt="${ForwardPrimerFile##*.}" # file.fasta -> fasta
            if [ "$testExt" != "fasta" ]; then
                echo "Warning: Renaming forward primer file to have fasta extension"
                cp $ForwardPrimerFile ${ForwardPrimerFile}.fasta
                ForwardPrimerFile=${ForwardPrimerFile}.fasta
            fi

            if [ "$ForwardPrimer" = "score" ]; then
                ARGS="score --nproc 1 -p $ForwardPrimerFile -s $prevPassFile"
                if [ -n "$ForwardPrimerStartPosition" ]; then
                    ARGS="${ARGS} --start $ForwardPrimerStartPosition"
                fi
                if [ -n "$ForwardPrimerMaxError" ]; then
                    ARGS="${ARGS} --maxerror $ForwardPrimerMaxError"
                fi
            else
                ARGS="align --nproc 1 -p $ForwardPrimerFile -s $prevPassFile"
                if [ -n "$ForwardPrimerMaxError" ]; then
                    ARGS="${ARGS} --maxerror $ForwardPrimerMaxError"
                fi
                if [ -n "$ForwardPrimerMaxLength" ]; then
                    ARGS="${ARGS} --maxlen $ForwardPrimerMaxLength"
                fi
            fi
            if [[ $ForwardPrimerUMI -eq 1 ]]; then
                ARGS="${ARGS} --barcode"
            fi
            ARGS="${ARGS} --outname ${OutputPrefix}-V --mode mask"
            echo MaskPrimers.py $ARGS
            $MASK_PRIMERS_PY $ARGS
            addCalculation "${ACTIVITY_NAME}" "forward_primer"

            intermediateFiles[${#intermediateFiles[@]}]=$prevPassFile
            prevPassFile="${OutputName}-V_primers-pass.${fileExtension}"
            EXPAND_PRIMER=1
        else
            if [[ $ForwardPrimerUMI -ne 1 ]]; then
                echo "ERROR: Must specify UMI if no forward primer file."
                exit
            fi

            ARGS="extract --nproc 1 -s $prevPassFile --barcode --bf BARCODE"
            ARGS="${ARGS} --start 12 --len 7"
            ARGS="${ARGS} --outname ${OutputPrefix}-V --mode cut"
            echo MaskPrimers.py $ARGS
            $MASK_PRIMERS_PY $ARGS
            addCalculation "${ACTIVITY_NAME}" "forward_umi"

            intermediateFiles[${#intermediateFiles[@]}]=$prevPassFile
            prevPassFile="${OutputName}-V_primers-pass.${fileExtension}"
            EXPAND_PRIMER=0
        fi
    fi

    # Reverse Primers
    if [ -n "$ReversePrimer" ]; then
        if [ "$ReversePrimer" != "none" ]; then
            echo "Mask reverse primers"
            if [ -z "$ReversePrimerFile" ]; then
                echo "ERROR: Missing the required reverse primer file."
                exit
            fi

            # presto needs extension to be fasta
            testExt="${ReversePrimerFile##*.}" # file.fasta -> fasta
            if [ "$testExt" != "fasta" ]; then
                echo "Warning: Renaming reverse primer file to have fasta extension"
                cp $ReversePrimerFile ${ReversePrimerFile}.fasta
                ReversePrimerFile=${ReversePrimerFile}.fasta
            fi

            ARGS=""
            if [ "$ReversePrimer" = "score" ]; then
                ARGS="score --nproc 1 -p $ReversePrimerFile -s $prevPassFile"
                if [ -n "$ReversePrimerStartPosition" ]; then
                    ARGS="${ARGS} --start $ReversePrimerStartPosition"
                fi
                if [ -n "$ReversePrimerMaxError" ]; then
                    ARGS="${ARGS} --maxerror $ReversePrimerMaxError"
                fi
                ARGS="${ARGS} --mode cut --revpr"
            else
                ARGS="align --nproc 1 -p $ReversePrimerFile -s $prevPassFile"
                if [ -n "$ReversePrimerMaxError" ]; then
                    ARGS="${ARGS} --maxerror $ReversePrimerMaxError"
                fi
                if [ -n "$ReversePrimerMaxLength" ]; then
                    ARGS="${ARGS} --maxlen $ReversePrimerMaxLength"
                fi
                ARGS="${ARGS} --mode cut --revpr --skiprc"
            fi
            if [[ $ReversePrimerUMI -eq 1 ]]; then
                ARGS="${ARGS} --barcode"
            fi
            ARGS="${ARGS} --outname ${OutputPrefix}-J"
            echo MaskPrimers.py $ARGS
            $MASK_PRIMERS_PY $ARGS
            addCalculation "${ACTIVITY_NAME}" "reverse_primer"

            intermediateFiles[${#intermediateFiles[@]}]=$prevPassFile
            prevPassFile="${OutputName}-J_primers-pass.${fileExtension}"
            EXPAND_PRIMER=1
        fi
    fi

    if [[ $UMIConsensus -eq 1 ]]; then
        echo "Generating UMI consensus reads"
        ARGS="--nproc 1 -s $prevPassFile --bf BARCODE --pf PRIMER"
        if [ -n "$UMIMaxError" ]; then
            ARGS="${ARGS} --maxerror $UMIMaxError"
        fi
        if [ -n "$UMIMaxGap" ]; then
            ARGS="${ARGS} --maxgap $UMIMaxGap"
        fi
        if [ -n "$UMIMinFrequency" ]; then
            ARGS="${ARGS} --prcons $UMIMinFrequency"
        fi
        ARGS="${ARGS} --outname ${OutputPrefix}-UMI"

        echo BuildConsensus.py $ARGS
        $BUILD_CONSENSUS_PY $ARGS
        addCalculation "${ACTIVITY_NAME}" "umi_consensus"

        intermediateFiles[${#intermediateFiles[@]}]=$prevPassFile
        prevPassFile="${OutputName}-UMI_consensus-pass.${fileExtension}"

        EXPAND_PRIMER=0
        unique_fields=PRCONS
        copy_fields=CONSCOUNT
    fi

    # Expand and rename primer field
    if [[ $EXPAND_PRIMER -eq 1 ]]; then
        $PARSE_HEADERS_PY expand -s $prevPassFile --outname ${OutputPrefix}-expand -f PRIMER

        intermediateFiles[${#intermediateFiles[@]}]=$prevPassFile
        prevPassFile="${OutputName}-expand_reheader.${fileExtension}"

        old_num=1
        old_name=
        new_name=
        unique_fields=
        copy_fields=
        if [[ $Barcode -eq 1 ]]; then
            old_name="${old_name} PRIMER${old_num}"
            let "old_num+=1"
            new_name="${new_name} MID"
            unique_fields="${unique_fields} MID"
        fi
        if [ "$ForwardPrimer" != "none" ]; then
            old_name="${old_name} PRIMER${old_num}"
            let "old_num+=1"
            new_name="${new_name} VPRIMER"
            copy_fields="${copy_fields} VPRIMER"
        fi
        if [ "$ReversePrimer" != "none" ]; then
            old_name="${old_name} PRIMER${old_num}"
            let "old_num+=1"
            new_name="${new_name} JPRIMER"
            unique_fields="${unique_fields} JPRIMER"
        fi

        echo ParseHeaders.py rename -s $prevPassFile --outname ${OutputPrefix}-rename -f $old_name -k $new_name
        $PARSE_HEADERS_PY rename -s $prevPassFile --outname ${OutputPrefix}-rename -f $old_name -k $new_name

        intermediateFiles[${#intermediateFiles[@]}]=$prevPassFile
        prevPassFile="${OutputName}-rename_reheader.${fileExtension}"
    fi

    # Rename file output file
    intermediateFiles[${#intermediateFiles[@]}]=$prevPassFile
    cp $prevPassFile ${OutputPrefix}-final.${fileExtension}
    prevPassFile="${OutputPrefix}-final.${fileExtension}"
    #addOutputFile $group $APP_NAME processed_sequence "$prevPassFile" "Total Post-Filter Sequences (${OutputPrefix})" "read" null
    ## the source_entity is file as we are not sure of the intermediary files.
    wasDerivedFrom "$prevPassFile" "${file}" "Total Post-Filter Sequences (${OutputPrefix})" "read"

    # Split by barcode
    if [[ $Barcode -eq 1 ]]; then
        if [[ $BarcodeSplitFlag -eq 1 ]]; then
            echo "Split by barcode"
            $SPLIT_SEQ_PY group -s $prevPassFile -f MID
        fi
    fi

    # Find unique sequences
    if [[ $FindUniqueFlag -eq 1 ]]; then
        echo "Find unique sequences"
        if [[ $UMIConsensus -eq 1 ]]; then
            echo ParseHeaders.py collapse -s $prevPassFile -f CONSCOUNT --act min --outname ${OutputPrefix}
            $PARSE_HEADERS_PY collapse -s $prevPassFile -f CONSCOUNT --act min --outname ${OutputPrefix}

            prevPassFile="${OutputName}_reheader.${fileExtension}"
            intermediateFiles[${#intermediateFiles[@]}]=$prevPassFile
        fi

        ARGS="-s $prevPassFile"
        if [ -n "$FindUniqueMaxNucleotides" ]; then
            ARGS="${ARGS} -n $FindUniqueMaxNucleotides"
        fi
        if [ -n "$FindUniqueExclude" ]; then
            ARGS="${ARGS} --inner"
        fi
        if [ -n "$unique_fields" ]; then
            ARGS="${ARGS} --uf $unique_fields"
        fi
        if [ -n "$copy_fields" ]; then
            ARGS="${ARGS} --cf $copy_fields"
            if [[ $UMIConsensus -eq 1 ]]; then
                ARGS="${ARGS} --act sum"
            else
                ARGS="${ARGS} --act set"
            fi
        fi
        ARGS="${ARGS} --outname ${OutputPrefix}"
        echo CollapseSeq.py $ARGS
        $COLLAPSE_SEQ_PY $ARGS
        addCalculation "${ACTIVITY_NAME}" "find_unique_sequences"

        prevPassFile="${OutputPrefix}_collapse-unique.${fileExtension}"
        # addOutputFile $group $APP_NAME sequence "$prevPassFile" "Unique Post-Filter Sequences (${OutputPrefix})" "read" null
        # Not sure of the source entity for was derived here either.
        wasDerivedFrom "$prevPassFile" "${file}" "Unique Post-Filter Sequences (${OutputPrefix})" "read"

        # don't exclude DUPCOUNT=1 sequences
        #noArchive "$prevPassFile"
        #intermediateFiles[${#intermediateFiles[@]}]=$prevPassFile

        #$SPLIT_SEQ_PY group -s $prevPassFile -f DUPCOUNT --num 2 --outname "${OutputPrefix}"
        #prevPassFile="${OutputPrefix}_atleast-2.${fileExtension}"
        #addOutputFile $group $APP_NAME singletons "${OutputPrefix}_under-2.${fileExtension}" "Singleton Post-Filter Sequences (${OutputPrefix})" "read" null
        #addOutputFile $group $APP_NAME sequence "$prevPassFile" "Unique Post-Filter Sequences (${OutputPrefix})" "read" null

        # Split by barcode
        if [[ $BarcodeSplitFlag -eq 1 ]]; then
            echo "Split by barcode"
            $SPLIT_SEQ_PY group -s $prevPassFile -f MID
        fi
    fi

    # archive the intermediate files
    echo "Zip archive the intermediate files"
    for file in ${intermediateFiles[@]}; do
        zip ${OutputPrefix}_intermediateFiles.zip $file
    done
    addLogFile $group $APP_NAME intermediate "${OutputPrefix}_intermediateFiles.zip" "Intermediate Files (${OutputPrefix})" "zip" null
}

# Entry function for running VDJServer's pRESTO workflow
#
function run_presto_workflow() {
    initProvenance

    intermediateFiles=()

    # Flag for doing vdjserver single workflow
    DO_SINGLE=0

    # check for valid workflow
    case $Workflow in
        takara_bio_umi_human_ig)
            ;;
        takara_bio_umi_human_tr)
            ;;
        takara_bio_umi_mouse_ig)
            ;;
        takara_bio_umi_mouse_tr)
            ;;
        paired)
            ;;
        single)
            DO_SINGLE=1
            ;;
        *)
            echo "Unknown workflow: $Workflow"
            exit 1
    esac

    # Exclude input files from archive
    for file in $JobFiles; do
        if [ -f $file ]; then
            unzip $file
        fi
    done

    case $Workflow in
        takara_bio_umi_human_ig | takara_bio_umi_human_tr | takara_bio_umi_mouse_ig | takara_bio_umi_mouse_tr | paired)

            forwardReads=($SequenceForwardPairedFiles)
            reverseReads=($SequenceReversePairedFiles)

            count=0
            while [ "x${forwardReads[count]}" != "x" ]
            do
                group="merge${count}"
                addGroup $group file

                # uncompress if needed
                file=${reverseReads[count]}
                expandfile $file

                # presto needs extension to be fastq
                testExt="${file##*.}" # file.fq -> fq
                if [ "$testExt" != "fastq" ]; then
                    echo "Warning: Renaming file to have fastq extension"
                    cp $file ${file}.fastq
                    file=${file}.fastq
                fi
                rfile=$file

                file=${forwardReads[count]}
                expandfile $file

                # presto needs extension to be fastq
                testExt="${file##*.}" # file.fq -> fq
                if [ "$testExt" != "fastq" ]; then
                    echo "Warning: Renaming file to have fastq extension"
                    cp $file ${file}.fastq
                    file=${file}.fastq
                fi

                if [ "$Workflow" = "paired" ]; then
                    echo "Convert and assemble paired reads"

                    fileExtension="${file##*.}" # file.fastq -> fastq
                    fileBasename="${file%.*}" # file.fastq -> file
                    fileOutname="${fileBasename##*/}" # test/file -> file
                    filePrefix="${file%/*}" # test/file -> file, or file -> file
                    if [ "$filePrefix" == "$file" ]; then
                        # no directory in filename
                        filePrefix=""
                    fi

                    # attach prefix
                    OutputPrefix=$fileOutname
                    if [ -n "${filePrefix}" ]; then
                        OutputName="${filePrefix}/${fileOutname}"
                    else
                        OutputName="${fileOutname}"
                    fi

                    ARGS="align --nproc 1 -1 $file -2 $rfile --coord $SequenceFileTypes --rc tail"
                    ARGS="${ARGS} --outname $OutputPrefix"
                    echo AssemblePairs.py $ARGS
                    $ASSEMBLE_PAIRS_PY $ARGS
                    addCalculation "${ACTIVITY_NAME}" "merge_paired_reads"

                    # after merge, do the single workflow
                    DO_SINGLE=1
                    SequenceFiles="$SequenceFiles ${OutputName}_assemble-pass.${fileExtension}"
                    cp ${OutputName}_assemble-pass.${fileExtension} ${OutputPrefix}_assemble.${fileExtension}
                    # addOutputFile $group $APP_NAME merged_sequence "${OutputPrefix}_assemble.${fileExtension}" "Merged Pre-Filter Sequences (${OutputPrefix})" "read" null
                    wasDerivedFrom "${OutputPrefix}_assemble.${fileExtension}" "${file}" "Merged Pre-Filter Sequences (${OutputPrefix})" "read"
                    wasDerivedFrom "${OutputPrefix}_assemble.${fileExtension}" "${rfile}" "Merged Pre-Filter Sequences (${OutputPrefix})" "read"
                else
                    takara_bio_umi_workflow $file $rfile $count
                fi

                count=$(( $count + 1 ))
            done

            ;;
    esac

    if [[ $DO_SINGLE -eq 1 ]]; then
        readFiles=($SequenceFiles)

        count=0
        while [ "x${readFiles[count]}" != "x" ]
        do
            file=${readFiles[count]}
            single_presto_workflow $file $count
            count=$(( $count + 1 ))
        done
    fi

    # zip archive of all output files
    for file in $ARCHIVE_FILE_LIST; do
        if [ -f $file ]; then
            cp -f $file ${_tapisJobUUID}
            cp -f $file output
        fi
    done
    zip ${_tapisJobUUID}.zip ${_tapisJobUUID}/*
    addLogFile $APP_NAME log output_archive ${_tapisJobUUID}.zip "Archive of Output Files" "zip" null
    cp ${_tapisJobUUID}.zip output
}
