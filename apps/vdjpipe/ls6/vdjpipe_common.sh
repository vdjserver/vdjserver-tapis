#
# VDJServer VDJPipe common functions
#
# This script relies upon global variables
# source vdjpipe_common.sh
#
# Author: Scott Christley
# Copyright (C) 2016-2024 The University of Texas Southwestern Medical Center
# Date: Sep 6, 2016
# 

# the app
export APP_NAME=vdjpipe
# TODO: this is not generic enough
export ACTIVITY_NAME="vdjserver:activity:vdjpipe"

# bring in common functions
source ./common_functions.sh

# bring in provenance functions
source ./provenance_functions.sh

# ----------------------------------------------------------------------------

function print_versions() {
    # Start
    echo "VERSIONS:"
    echo "  $($VDJ_PIPE --version 2>&1)"
    echo ""
}

function print_parameters() {
    echo "Input files:"
    echo "vdj_pipe_image=${vdj_pipe_image}"
    echo "repcalc_image=${repcalc_image}"
    echo "analysis_provenance=${analysis_provenance}"
    echo "ProjectDirectory=${ProjectDirectory}"
    echo "JobFiles=${JobFiles}"
    echo "SequenceFASTQ=$SequenceFASTQ"
    echo "SequenceFASTA=$SequenceFASTA"
    echo "SequenceQualityFiles=$SequenceQualityFiles"
    echo "SequenceForwardPairedFiles=$SequenceForwardPairedFiles"
    echo "SequenceReversePairedFiles=$SequenceReversePairedFiles"
    echo "ForwardPrimerFile=$ForwardPrimerFile"
    echo "ReversePrimerFile=$ReversePrimerFile"
    echo "BarcodeFile=$BarcodeFile"
    echo ""
    echo "Application parameters:"
    echo "Workflow=$Workflow"
    echo "Merge paired-end reads:"
    echo "MergeMinimumScore=${MergeMinimumScore}"
    echo "Pre-filter statistics:"
    echo "PreFilterStatisticsFlag=$PreFilterStatisticsFlag"
    echo "Filters:"
    echo "FilterFlag=$FilterFlag"
    echo "MinimumAverageQuality=$MinimumAverageQuality"
    echo "MinimumLength=$MinimumLength"
    echo "MaximumHomopolymer=${MaximumHomopolymer}"
    echo "Post-filter statistics:"
    echo "PostFilterStatisticsFlag=$PostFilterStatisticsFlag"
    echo "Barcodes:"
    echo "Barcode=$Barcode"
    echo "BarcodeLocation=${BarcodeLocation}"
    echo "BarcodeDiscard=${BarcodeDiscard}"
    echo "BarcodeGenerateHistogram=${BarcodeGenerateHistogram}"
    echo "BarcodeMaximumMismatches=${BarcodeMaximumMismatches}"
    echo "BarcodeTrim=${BarcodeTrim}"
    echo "BarcodeSearchWindow=${BarcodeSearchWindow}"
    echo "BarcodeSplitFlag=${BarcodeSplitFlag}"
    echo "Forward primer:"
    echo "ForwardPrimer=${ForwardPrimer}"
    echo "ForwardPrimerMaximumMismatches=${ForwardPrimerMaximumMismatches}"
    echo "ForwardPrimerTrim=${ForwardPrimerTrim}"
    echo "ForwardPrimerSearchWindow=${ForwardPrimerSearchWindow}"
    echo "Reverse primer:"
    echo "ReversePrimer=${ReversePrimer}"
    echo "ReversePrimerMaximumMismatches=${ReversePrimerMaximumMismatches}"
    echo "ReversePrimerTrim=${ReversePrimerTrim}"
    echo "ReversePrimerSearchWindow=${ReversePrimerSearchWindow}"
    echo "Find unique sequences:"
    echo "FindUniqueFlag=$FindUniqueFlag"
    echo ""
}

# param: output prefix
# param: config file name
function run_vdjpipe() {
    OutPrefix=$1
    ConfigFile=$2
    SourceEntity=$3

    # Pre-filter statistics
    if [[ $PreFilterStatisticsFlag -eq 1 ]]; then
        PreFilterStatisticsFilename="${OutPrefix}.pre-filter_"
        if [[ $PostFilterStatisticsFlag -eq 1 ]]; then
            wasGeneratedBy "${OutPrefix}.pre-filter_composition.csv" "${ACTIVITY_NAME}" "quality_statistics,composition" "Nucleotide Composition" tsv
            wasGeneratedBy "${OutPrefix}.pre-filter_gc_hist.csv" "${ACTIVITY_NAME}" "quality_statistics,gc_histogram" "GC% Histogram" tsv
            wasGeneratedBy "${OutPrefix}.pre-filter_heat_map.csv" "${ACTIVITY_NAME}" "quality_statistics,heatmap" "Heatmap" tsv
            wasGeneratedBy "${OutPrefix}.pre-filter_len_hist.csv" "${ACTIVITY_NAME}" "quality_statistics,length_histogram" "Sequence Length Histogram" tsv
            wasGeneratedBy "${OutPrefix}.pre-filter_mean_q_hist.csv" "${ACTIVITY_NAME}" "quality_statistics,mean_quality_histogram" "Mean Quality Histogram" tsv
            wasGeneratedBy "${OutPrefix}.pre-filter_qstats.csv" "${ACTIVITY_NAME}" "quality_statistics" "Quality Scores" tsv
        else
            # if no post then must be just a single statistics run
            PreFilterStatisticsFilename="${OutPrefix}.stats_"
            wasGeneratedBy "${OutPrefix}.stats_composition.csv" "${ACTIVITY_NAME}" "quality_statistics,composition" "Nucleotide Composition" tsv
            wasGeneratedBy "${OutPrefix}.stats_gc_hist.csv" "${ACTIVITY_NAME}" "quality_statistics,gc_histogram" "GC% Histogram" tsv
            wasGeneratedBy "${OutPrefix}.stats_heat_map.csv" "${ACTIVITY_NAME}" "quality_statistics,heatmap" "Heatmap" tsv
            wasGeneratedBy "${OutPrefix}.stats_len_hist.csv" "${ACTIVITY_NAME}" "quality_statistics,length_histogram" "Sequence Length Histogram" tsv
            wasGeneratedBy "${OutPrefix}.stats_mean_q_hist.csv" "${ACTIVITY_NAME}" "quality_statistics,mean_quality_histogram" "Mean Quality Histogram" tsv
            wasGeneratedBy "${OutPrefix}.stats_qstats.csv" "${ACTIVITY_NAME}" "quality_statistics" "Quality Scores" tsv
            #addCalculation "statistics"
        fi
        $PYTHON ./vdjpipe_create_config.py ${ConfigFile} --statistics $PreFilterStatisticsFilename
    fi

    # Filtering
    if [[ $FilterFlag -eq 1 ]]; then
        $PYTHON ./vdjpipe_create_config.py ${ConfigFile} --length $MinimumLength
        $PYTHON ./vdjpipe_create_config.py ${ConfigFile} --quality $MinimumAverageQuality
        $PYTHON ./vdjpipe_create_config.py ${ConfigFile} --homopolymer $MaximumHomopolymer
        # TODO: provenance
        #addCalculation length_filtering
        #addCalculation quality_filtering
        #addCalculation homopolymer_filtering
    fi

    # Post-filter statistics
    if [[ $PostFilterStatisticsFlag -eq 1 ]]; then
        PostFilterStatisticsFilename="${OutPrefix}.post-filter_"
        $PYTHON ./vdjpipe_create_config.py ${ConfigFile} --statistics $PostFilterStatisticsFilename
        wasGeneratedBy "${OutPrefix}.post-filter_composition.csv" "${ACTIVITY_NAME}" "quality_statistics,composition" "Nucleotide Composition" tsv
        wasGeneratedBy "${OutPrefix}.post-filter_gc_hist.csv" "${ACTIVITY_NAME}" "quality_statistics,gc_histogram" "GC% Histogram" tsv
        wasGeneratedBy "${OutPrefix}.post-filter_heat_map.csv" "${ACTIVITY_NAME}" "quality_statistics,heatmap" "Heatmap" tsv
        wasGeneratedBy "${OutPrefix}.post-filter_len_hist.csv" "${ACTIVITY_NAME}" "quality_statistics,length_histogram" "Sequence Length Histogram" tsv
        wasGeneratedBy "${OutPrefix}.post-filter_mean_q_hist.csv" "${ACTIVITY_NAME}" "quality_statistics,mean_quality_histogram" "Mean Quality Histogram" tsv
        wasGeneratedBy "${OutPrefix}.post-filter_qstats.csv" "${ACTIVITY_NAME}" "quality_statistics" "Quality Scores" tsv
        #addCalculation "post-filter_statistics"
    fi

    # Barcode
    if [[ $Barcode -eq 1 ]]; then
        ARGS=""
        if [[ -n "$BarcodeLocation" ]]; then
            ARGS="${ARGS} $BarcodeLocation"
        else
            ARGS="${ARGS} forward"
        fi
        if [[ $BarcodeDiscard -eq 1 ]]; then
            ARGS="${ARGS} $BarcodeDiscard"
        else
            ARGS="${ARGS} False"
        fi
        if [[ -n "$BarcodeMaximumMismatches" ]]; then
            ARGS="${ARGS} $BarcodeMaximumMismatches"
        else
            ARGS="${ARGS} 0"
        fi
        ARGS="${ARGS} $BarcodeFile"
        if [[ $BarcodeTrim -eq 1 ]]; then
            ARGS="${ARGS} $BarcodeTrim"
        else
            ARGS="${ARGS} False"
        fi
        if [[ -n "$BarcodeSearchWindow" ]]; then
            ARGS="${ARGS} $BarcodeSearchWindow"
        else
            ARGS="${ARGS} 30"
        fi
        ARGS="${ARGS} MID"

        $PYTHON ./vdjpipe_create_config.py ${ConfigFile} --barcode $ARGS
        # TODO: provenance
        #addCalculation barcode_demultiplexing
    fi

    # Forward primer
    if [[ $ForwardPrimer -eq 1 ]]; then
        ARGS=""
        if [[ -n "$ForwardPrimerMaximumMismatches" ]]; then
            ARGS="${ARGS} $ForwardPrimerMaximumMismatches"
        else
            ARGS="${ARGS} 0"
        fi
        ARGS="${ARGS} $ForwardPrimerFile"
        if [[ $ForwardPrimerTrim -eq 1 ]]; then
            ARGS="${ARGS} $ForwardPrimerTrim"
        else
            ARGS="${ARGS} False"
        fi
        if [[ -n "$ForwardPrimerSearchWindow" ]]; then
            ARGS="${ARGS} $ForwardPrimerSearchWindow"
        else
            ARGS="${ARGS} 30"
        fi

        $PYTHON ./vdjpipe_create_config.py ${ConfigFile} --forwardPrimer $ARGS
        # TODO: provenance
        #addCalculation forward_primer
    fi

    # Reverse primer
    if [[ $ReversePrimer -eq 1 ]]; then
        ARGS=""
        if [[ -n "$ReversePrimerMaximumMismatches" ]]; then
            ARGS="${ARGS} $ReversePrimerMaximumMismatches"
        else
            ARGS="${ARGS} 0"
        fi
        ARGS="${ARGS} $ReversePrimerFile"
        if [[ $ReversePrimerTrim -eq 1 ]]; then
            ARGS="${ARGS} $ReversePrimerTrim"
        else
            ARGS="${ARGS} False"
        fi
        if [[ -n "$ReversePrimerSearchWindow" ]]; then
            ARGS="${ARGS} $ReversePrimerSearchWindow"
        else
            ARGS="${ARGS} 30"
        fi

        $PYTHON ./vdjpipe_create_config.py ${ConfigFile} --reversePrimer $ARGS
        # TODO: provenance
        #addCalculation reverse_primer
    fi

    # Write final sequences
    TotalOutputFilename="${OutPrefix}.total"
    if [[ $Barcode -eq 1 ]]; then
        $PYTHON ./vdjpipe_create_config.py ${ConfigFile} --write "${TotalOutputFilename}-{MID}.fastq"
        wasDerivedFrom "${TotalOutputFilename}-{MID}.fastq" "${SourceEntity}" "sequence_reads,sequenced_quality" "Total Post-Filter Sequences (${fileBasename})" "fastq"
    else
        $PYTHON ./vdjpipe_create_config.py ${ConfigFile} --write "${TotalOutputFilename}.fastq"
        wasDerivedFrom "${TotalOutputFilename}.fastq" "${SourceEntity}" "sequence_reads,sequenced_quality" "Total Post-Filter Sequences (${fileBasename})" "fastq"
    fi

    # Find unique sequences
    if [[ $FindUniqueFlag -eq 1 ]]; then
        FindUniqueOutput="${OutPrefix}.unique"
        FindUniqueDuplicates="${OutPrefix}.unique-duplicates"

        # TODO: provenance
        if [[ $Barcode -eq 1 ]]; then
            $PYTHON ./vdjpipe_create_config.py ${ConfigFile} --uniqueGroup "${FindUniqueOutput}-{MID}.fasta" "${FindUniqueDuplicates}-{MID}.tsv"
            #addLogFile $APP_NAME log sharing_summary sharing_summary.csv "Sharing Summary Log (${fileBasename})" "log" null
        else
            $PYTHON ./vdjpipe_create_config.py ${ConfigFile} --unique "${FindUniqueOutput}.fasta" "${FindUniqueDuplicates}.tsv"
            wasDerivedFrom "${FindUniqueOutput}.fasta" "${SourceEntity}" sequence "Unique Post-Filter Sequences (${fileBasename})" "fasta"
            wasDerivedFrom "${FindUniqueDuplicates}.tsv" "${SourceEntity}" duplicates "Unique Sequence Duplicates Table (${fileBasename})" "tsv"
        fi
        #addCalculation find_unique_sequences
    fi

    # Barcode histogram
    if [[ $BarcodeGenerateHistogram -eq 1 ]]; then
        $PYTHON ./vdjpipe_create_config.py ${ConfigFile} --barcodeHistogram MID
        # TODO: provenance
        #addStatisticsFile $group barcode value "${OutPrefix}.MID.tsv" "Barcode Histogram (${fileBasename})" "tsv" "${WasDerivedFrom}"
        #addStatisticsFile $group barcode score "${OutPrefix}.MID-score.tsv" "Barcode Score Histogram (${fileBasename})" "tsv" "${WasDerivedFrom}"
        #addCalculation barcode_histogram
    fi

    # run the main workflow
    echo "Main VDJPipe workflow"
    $VDJ_PIPE --config ${ConfigFile}

    # VDJPipe only seems to be able to tag output sequences with their barcode
    # when the sequences are split into different files. Therefore, we always
    # split then concatenate if the user does not want them split.
    if [[ $Barcode -eq 1 ]]; then
        if [[ $BarcodeSplitFlag -eq 1 ]]; then
            # put split files into process metadata
            $BIO_PYTHON ./vdjpipe_barcodes.py --barcodeFiles "${TotalOutputFilename}-{MID}.fastq" $BarcodeFile "${fileBasename}" "${SourceEntity}" >vdjpipe_barcodes.sh
            bash ./vdjpipe_barcodes.sh
            rm -f vdjpipe_barcodes.sh

            $BIO_PYTHON ./vdjpipe_barcodes.py --uniqueGroup "${FindUniqueOutput}-{MID}.fasta" "${FindUniqueDuplicates}-{MID}.tsv" $BarcodeFile "${fileBasename}" "${SourceEntity}" >vdjpipe_barcodes.sh
            bash ./vdjpipe_barcodes.sh
            rm -f vdjpipe_barcodes.sh

            # make sure spit files get archived
            fileList=$($BIO_PYTHON ./vdjpipe_barcodes.py --fileList "${TotalOutputFilename}-{MID}.fastq" $BarcodeFile)
            addArchiveFile ${fileList}
            fileList=$($BIO_PYTHON ./vdjpipe_barcodes.py --fileList "${FindUniqueOutput}-{MID}.fasta" $BarcodeFile)
            addArchiveFile ${fileList}
            fileList=$($BIO_PYTHON ./vdjpipe_barcodes.py --fileList "${FindUniqueDuplicates}-{MID}.tsv" $BarcodeFile)
            addArchiveFile ${fileList}
        else
            # concatenate, exclude the split files from archiving
            $BIO_PYTHON ./vdjpipe_barcodes.py --catFiles "${TotalOutputFilename}-{MID}.fastq" $BarcodeFile >vdjpipe_barcodes.sh
            bash ./vdjpipe_barcodes.sh "${TotalOutputFilename}.fastq"
            rm -f vdjpipe_barcodes.sh
            wasDerivedFrom "${TotalOutputFilename}.fastq" "${SourceEntity}" "sequence_reads,sequenced_quality" "Total Post-Filter Sequences (${fileBasename})" "fastq"

            $BIO_PYTHON ./vdjpipe_barcodes.py --catFiles "${FindUniqueOutput}-{MID}.fasta" $BarcodeFile >vdjpipe_barcodes.sh
            bash ./vdjpipe_barcodes.sh "${FindUniqueOutput}.fasta"
            rm -f vdjpipe_barcodes.sh
            wasDerivedFrom "${FindUniqueOutput}.fasta" "${SourceEntity}" sequence "Unique Post-Filter Sequences (${fileBasename})" "fasta"

            $BIO_PYTHON ./vdjpipe_barcodes.py --catFiles "${FindUniqueDuplicates}-{MID}.tsv" $BarcodeFile >vdjpipe_barcodes.sh
            bash ./vdjpipe_barcodes.sh "${FindUniqueDuplicates}.tsv"
            rm -f vdjpipe_barcodes.sh
            wasDerivedFrom "${FindUniqueDuplicates}.tsv" "${SourceEntity}" duplicates "Unique Sequence Duplicates Table (${fileBasename})" "tsv"
        fi
    fi
}

function run_vdjpipe_workflow() {
    initProvenance

    # Exclude input files from archive
#    noArchive "${ProjectDirectory}"
#    for file in $SequenceFASTQ; do
#        noArchive "$file"
#    done
    for file in $JobFiles; do
        if [ -f $file ]; then
            expandfile $file
        fi
    done

    # Paired-end read workflow needs to merge
    if [ "$Workflow" = "paired" ]; then
        echo "Merging paired-end reads."
        forwardReads=($SequenceForwardPairedFiles)
        reverseReads=($SequenceReversePairedFiles)

        count=0
        while [ "x${forwardReads[count]}" != "x" ]
        do
            file=${forwardReads[count]}
            rfile=${reverseReads[count]}

            if [ -z "$MergeMinimumScore" ]; then
                MergeMinimumScore=10
            fi

            filePath="${file##*/}" # path/file.fastq -> file.fastq
            fileExtension="${filePath##*.}" # file.fastq -> fastq
            fileBasename="${filePath%.*}" # file.fastq -> file

            # attach prefix
            OutputPrefix="${fileBasename}.merged"

            # Construct VDJPipe config file
            SummaryFile=${OutputPrefix}.merge_summary.txt
            ConfigFile=${OutputPrefix}.vdjpipe_paired_config.json
            MergeFile=${OutputPrefix}.fastq
            $PYTHON ./vdjpipe_create_config.py --init ${SummaryFile} ${ConfigFile}
            $PYTHON ./vdjpipe_create_config.py ${ConfigFile} --merge $MergeMinimumScore $MergeFile --forwardReads $file --reverseReads $rfile
            wasGeneratedBy "${ConfigFile}" "${ACTIVITY_NAME}" config "VDJPipe Read Merging Configuration (${fileBasename})" json
            wasGeneratedBy "${SummaryFile}" "${ACTIVITY_NAME}" summary "VDJPipe Read Merging Output Summary (${fileBasename})" log

            # run the paired merging
            $VDJ_PIPE --config ${ConfigFile}
            addCalculation merge_paired_reads

            SequenceFASTQ="$SequenceFASTQ ${MergeFile}"
            wasDerivedFrom "${MergeFile}" "${file}" "sequence_reads,sequence_quality" "Merged Pre-Filter Sequences (${fileBasename})" fastq

            count=$(( $count + 1 ))
        done
    fi

    # FASTA/QUAL workflow
    readFiles=($SequenceFASTA)
    qualityFiles=($SequenceQualityFiles)

    count=0
    while [ "x${readFiles[count]}" != "x" ]
    do
        file=${readFiles[count]}
        qfile=${qualityFiles[count]}

        filePath="${file##*/}" # path/file.fastq -> file.fastq
        fileExtension="${filePath##*.}" # file.fastq -> fastq
        fileBasename="${filePath%.*}" # file.fastq -> file

        # Construct VDJPipe config file
        OutputPrefix=$fileBasename
        ConfigFile=${OutputPrefix}.vdjpipe_config.json
        SummaryFile=${OutputPrefix}.summary.txt
        $PYTHON ./vdjpipe_create_config.py --init ${SummaryFile} ${ConfigFile}
        wasGeneratedBy "${ConfigFile}" "${ACTIVITY_NAME}" config "VDJPipe Input Configuration (${fileBasename})" json
        wasGeneratedBy "${SummaryFile}" "${ACTIVITY_NAME}" summary "VDJPipe Output Summary (${fileBasename})" log

        $PYTHON ./vdjpipe_create_config.py ${ConfigFile} --fasta $file --quals $qfile

        run_vdjpipe "${OutputPrefix}" "${ConfigFile}" "${file}"

        count=$(( $count + 1 ))
    done

    # FASTQ workflow
    # use same counter
    readFiles=($SequenceFASTQ)

    while [ "x${readFiles[count]}" != "x" ]
    do
        file=${readFiles[count]}

        filePath="${file##*/}" # path/file.fastq -> file.fastq
        fileExtension="${filePath##*.}" # file.fastq -> fastq
        fileBasename="${filePath%.*}" # file.fastq -> file

        # Construct VDJPipe config file
        OutputPrefix=$fileBasename
        ConfigFile=${OutputPrefix}.vdjpipe_config.json
        SummaryFile=${OutputPrefix}.summary.txt
        $PYTHON ./vdjpipe_create_config.py --init ${SummaryFile} ${ConfigFile}
        wasGeneratedBy "${ConfigFile}" "${ACTIVITY_NAME}" config "VDJPipe Input Configuration (${fileBasename})" json
        wasGeneratedBy "${SummaryFile}" "${ACTIVITY_NAME}" summary "VDJPipe Output Summary (${fileBasename})" log

        $PYTHON ./vdjpipe_create_config.py ${ConfigFile} --fastq $file

        run_vdjpipe "${OutputPrefix}" "${ConfigFile}" "${file}"

        count=$(( $count + 1 ))
    done

    # Generate summary report
    $PYTHON ./vdjpipe_report.py *.summary.txt
    wasGeneratedBy vdjpipe_summary.csv "${ACTIVITY_NAME}" summary "VDJPipe Summary Report" csv

    # zip archive of all output files
    for file in $ARCHIVE_FILE_LIST; do
        if [ -f $file ]; then
            cp -f $file ${_tapisJobUUID}
            cp -f $file output
        fi
    done
    zip ${_tapisJobUUID}.zip ${_tapisJobUUID}/*
    wasGeneratedBy ${_tapisJobUUID}.zip "${ACTIVITY_NAME}" job_archive "Archive of Output Files" zip
    cp ${_tapisJobUUID}.zip output
}
