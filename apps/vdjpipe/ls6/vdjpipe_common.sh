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
export APP_NAME=vdjPipe

# bring in common functions
source ./common_functions.sh

# bring in provenance functions
source ./provenance_functions.sh

# ----------------------------------------------------------------------------

function gather_secondary_inputs() {
    # Gather secondary input files
    # This is used to get around Agave size limits for job inputs and parameters
    if [[ $SecondaryInputsFlag -eq 1 ]]; then
        echo "Gathering secondary input"
        moreFiles=$(${PYTHON} ./process_metadata.py --getSecondaryInput "${ProjectDirectory}/" SequenceFASTQMetadata study_metadata.json)
        SequenceFASTQ="${SequenceFASTQ} ${moreFiles}"
        moreFiles=$(${PYTHON} ./process_metadata.py --getSecondaryEntry SequenceFASTQMetadata study_metadata.json)
        SequenceFASTQMetadata="${SequenceFASTQMetadata} ${moreFiles}"
        moreFiles=$(${PYTHON} ./process_metadata.py --getSecondaryInput "${ProjectDirectory}/" SequenceFASTAMetadata study_metadata.json)
        SequenceFASTA="${SequenceFASTA} ${moreFiles}"
        moreFiles=$(${PYTHON} ./process_metadata.py --getSecondaryEntry SequenceFASTAMetadata study_metadata.json)
        SequenceFASTAMetadata="${SequenceFASTAMetadata} ${moreFiles}"
        moreFiles=$(${PYTHON} ./process_metadata.py --getSecondaryInput "${ProjectDirectory}/" SequenceQualityFilesMetadata study_metadata.json)
        SequenceQualityFiles="${SequenceQualityFiles} ${moreFiles}"
        moreFiles=$(${PYTHON} ./process_metadata.py --getSecondaryEntry SequenceQualityFilesMetadata study_metadata.json)
        SequenceQualityFilesMetadata="${SequenceQualityFilesMetadata} ${moreFiles}"
        moreFiles=$(${PYTHON} ./process_metadata.py --getSecondaryInput "${ProjectDirectory}/" SequenceForwardPairedFilesMetadata study_metadata.json)
        SequenceForwardPairedFiles="${SequenceForwardPairedFiles} ${moreFiles}"
        moreFiles=$(${PYTHON} ./process_metadata.py --getSecondaryEntry SequenceForwardPairedFilesMetadata study_metadata.json)
        SequenceForwardPairedFilesMetadata="${SequenceForwardPairedFilesMetadata} ${moreFiles}"
        moreFiles=$(${PYTHON} ./process_metadata.py --getSecondaryInput "${ProjectDirectory}/" SequenceReversePairedFilesMetadata study_metadata.json)
        SequenceReversePairedFiles="${SequenceReversePairedFiles} ${moreFiles}"
        moreFiles=$(${PYTHON} ./process_metadata.py --getSecondaryEntry SequenceReversePairedFilesMetadata study_metadata.json)
        SequenceReversePairedFilesMetadata="${SequenceReversePairedFilesMetadata} ${moreFiles}"
        moreFiles=$(${PYTHON} ./process_metadata.py --getSecondaryInput "${ProjectDirectory}/" ForwardPrimerFileMetadata study_metadata.json)
        ForwardPrimerFile="${ForwardPrimerFile} ${moreFiles}"
        moreFiles=$(${PYTHON} ./process_metadata.py --getSecondaryEntry ForwardPrimerFileMetadata study_metadata.json)
        ForwardPrimerFileMetadata="${ForwardPrimerFileMetadata} ${moreFiles}"
        moreFiles=$(${PYTHON} ./process_metadata.py --getSecondaryInput "${ProjectDirectory}/" ReversePrimerFileMetadata study_metadata.json)
        ReversePrimerFile="${ReversePrimerFile} ${moreFiles}"
        moreFiles=$(${PYTHON} ./process_metadata.py --getSecondaryEntry ReversePrimerFileMetadata study_metadata.json)
        ReversePrimerFileMetadata="${ReversePrimerFileMetadata} ${moreFiles}"
        moreFiles=$(${PYTHON} ./process_metadata.py --getSecondaryInput "${ProjectDirectory}/" BarcodeFileMetadata study_metadata.json)
        BarcodeFile="${BarcodeFile} ${moreFiles}"
        moreFiles=$(${PYTHON} ./process_metadata.py --getSecondaryEntry BarcodeFileMetadata study_metadata.json)
        BarcodeFileMetadata="${BarcodeFileMetadata} ${moreFiles}"
    fi
}

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
    echo "SecondaryInputsFlag=${SecondaryInputsFlag}"
    echo "Input file metadata:"
    echo "SequenceFASTQMetadata=${SequenceFASTQMetadata}"
    echo "SequenceFASTAMetadata=${SequenceFASTAMetadata}"
    echo "SequenceQualityFilesMetadata=${SequenceQualityFilesMetadata}"
    echo "SequenceForwardPairedFilesMetadata=${SequenceForwardPairedFilesMetadata}"
    echo "SequenceReversePairedFilesMetadata=${SequenceReversePairedFilesMetadata}"
    echo "ForwardPrimerFileMetadata=${ForwardPrimerFileMetadata}"
    echo "ReversePrimerFileMetadata=${ReversePrimerFileMetadata}"
    echo "BarcodeFileMetadata=${BarcodeFileMetadata}"
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
    WasDerivedFrom=$3

    # Pre-filter statistics
    if [[ $PreFilterStatisticsFlag -eq 1 ]]; then
        PreFilterStatisticsFilename="${OutPrefix}.pre-filter_"
        if [[ $PostFilterStatisticsFlag -eq 1 ]]; then
            addStatisticsFile $group pre composition "${OutPrefix}.pre-filter_composition.csv" "Nucleotide Composition" "tsv" "${WasDerivedFrom}"
            addStatisticsFile $group pre gc_hist "${OutPrefix}.pre-filter_gc_hist.csv" "GC% Histogram" "tsv" "${WasDerivedFrom}"
            addStatisticsFile $group pre heat_map "${OutPrefix}.pre-filter_heat_map.csv" "Heatmap" "tsv" "${WasDerivedFrom}"
            addStatisticsFile $group pre len_hist "${OutPrefix}.pre-filter_len_hist.csv" "Sequence Length Histogram" "tsv" "${WasDerivedFrom}"
            addStatisticsFile $group pre mean_q_hist "${OutPrefix}.pre-filter_mean_q_hist.csv" "Mean Quality Histogram" "tsv" "${WasDerivedFrom}"
            addStatisticsFile $group pre qstats "${OutPrefix}.pre-filter_qstats.csv" "Quality Scores" "tsv" "${WasDerivedFrom}"
            addCalculation "pre-filter_statistics"
        else
            # if no post then must be just a single statistics run
            PreFilterStatisticsFilename="${OutPrefix}.stats_"
            addStatisticsFile $group stats composition "${OutPrefix}.stats_composition.csv" "Nucleotide Composition" "tsv" "${WasDerivedFrom}"
            addStatisticsFile $group stats gc_hist "${OutPrefix}.stats_gc_hist.csv" "GC% Histogram" "tsv" "${WasDerivedFrom}"
            addStatisticsFile $group stats heat_map "${OutPrefix}.stats_heat_map.csv" "Heatmap" "tsv" "${WasDerivedFrom}"
            addStatisticsFile $group stats len_hist "${OutPrefix}.stats_len_hist.csv" "Sequence Length Histogram" "tsv" "${WasDerivedFrom}"
            addStatisticsFile $group stats mean_q_hist "${OutPrefix}.stats_mean_q_hist.csv" "Mean Quality Histogram" "tsv" "${WasDerivedFrom}"
            addStatisticsFile $group stats qstats "${OutPrefix}.stats_qstats.csv" "Quality Scores" "tsv" "${WasDerivedFrom}"
            addCalculation "statistics"
        fi
        $PYTHON ./vdjpipe_create_config.py ${ConfigFile} --statistics $PreFilterStatisticsFilename
    fi

    # Filtering
    if [[ $FilterFlag -eq 1 ]]; then
        $PYTHON ./vdjpipe_create_config.py ${ConfigFile} --length $MinimumLength
        $PYTHON ./vdjpipe_create_config.py ${ConfigFile} --quality $MinimumAverageQuality
        $PYTHON ./vdjpipe_create_config.py ${ConfigFile} --homopolymer $MaximumHomopolymer
        addCalculation length_filtering
        addCalculation quality_filtering
        addCalculation homopolymer_filtering
    fi

    # Post-filter statistics
    if [[ $PostFilterStatisticsFlag -eq 1 ]]; then
        PostFilterStatisticsFilename="${OutPrefix}.post-filter_"
        $PYTHON ./vdjpipe_create_config.py ${ConfigFile} --statistics $PostFilterStatisticsFilename
        addStatisticsFile $group post composition "${OutPrefix}.post-filter_composition.csv" "Nucleotide Composition" "tsv" "${WasDerivedFrom}"
        addStatisticsFile $group post gc_hist "${OutPrefix}.post-filter_gc_hist.csv" "GC% Histogram" "tsv" "${WasDerivedFrom}"
        addStatisticsFile $group post heat_map "${OutPrefix}.post-filter_heat_map.csv" "Heatmap" "tsv" "${WasDerivedFrom}"
        addStatisticsFile $group post len_hist "${OutPrefix}.post-filter_len_hist.csv" "Sequence Length Histogram" "tsv" "${WasDerivedFrom}"
        addStatisticsFile $group post mean_q_hist "${OutPrefix}.post-filter_mean_q_hist.csv" "Mean Quality Histogram" "tsv" "${WasDerivedFrom}"
        addStatisticsFile $group post qstats "${OutPrefix}.post-filter_qstats.csv" "Quality Scores" "tsv" "${WasDerivedFrom}"
        addCalculation "post-filter_statistics"
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
        addCalculation barcode_demultiplexing
#        noArchive $BarcodeFile
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
        addCalculation forward_primer
#        noArchive $ForwardPrimerFile
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
        addCalculation reverse_primer
#        noArchive $ReversePrimerFile
    fi

    # Write final sequences
    TotalOutputFilename="${OutPrefix}.total"
    if [[ $Barcode -eq 1 ]]; then
        $PYTHON ./vdjpipe_create_config.py ${ConfigFile} --write "${TotalOutputFilename}-{MID}.fastq"
    else
        $PYTHON ./vdjpipe_create_config.py ${ConfigFile} --write "${TotalOutputFilename}.fastq"
        addOutputFile $group $APP_NAME processed_sequence "${TotalOutputFilename}.fastq" "Total Post-Filter Sequences (${fileBasename})" "read" "${WasDerivedFrom}"
    fi

    # Find unique sequences
    if [[ $FindUniqueFlag -eq 1 ]]; then
        FindUniqueOutput="${OutPrefix}.unique"
        FindUniqueDuplicates="${OutPrefix}.unique-duplicates"

        if [[ $Barcode -eq 1 ]]; then
            $PYTHON ./vdjpipe_create_config.py ${ConfigFile} --uniqueGroup "${FindUniqueOutput}-{MID}.fasta" "${FindUniqueDuplicates}-{MID}.tsv"
            addLogFile $APP_NAME log sharing_summary sharing_summary.csv "Sharing Summary Log (${fileBasename})" "log" null
        else
            $PYTHON ./vdjpipe_create_config.py ${ConfigFile} --unique "${FindUniqueOutput}.fasta" "${FindUniqueDuplicates}.tsv"
            addOutputFile $group $APP_NAME sequence "${FindUniqueOutput}.fasta" "Unique Post-Filter Sequences (${fileBasename})" "read" "${WasDerivedFrom}"
            addOutputFile $group $APP_NAME duplicates "${FindUniqueDuplicates}.tsv" "Unique Sequence Duplicates Table (${fileBasename})" "tsv" "${WasDerivedFrom}"
        fi
        addCalculation find_unique_sequences
    fi

    # Barcode histogram
    if [[ $BarcodeGenerateHistogram -eq 1 ]]; then
        $PYTHON ./vdjpipe_create_config.py ${ConfigFile} --barcodeHistogram MID
        addStatisticsFile $group barcode value "${OutPrefix}.MID.tsv" "Barcode Histogram (${fileBasename})" "tsv" "${WasDerivedFrom}"
        addStatisticsFile $group barcode score "${OutPrefix}.MID-score.tsv" "Barcode Score Histogram (${fileBasename})" "tsv" "${WasDerivedFrom}"
        addCalculation barcode_histogram
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
            $BIO_PYTHON ./vdjpipe_barcodes.py --barcodeFiles "${TotalOutputFilename}-{MID}.fastq" $BarcodeFile "${fileBasename}" "${WasDerivedFrom}" >vdjpipe_barcodes.sh
            bash ./vdjpipe_barcodes.sh
            rm -f vdjpipe_barcodes.sh

            $BIO_PYTHON ./vdjpipe_barcodes.py --uniqueGroup "${FindUniqueOutput}-{MID}.fasta" "${FindUniqueDuplicates}-{MID}.tsv" $BarcodeFile "${fileBasename}" "${WasDerivedFrom}" >vdjpipe_barcodes.sh
            bash ./vdjpipe_barcodes.sh
            rm -f vdjpipe_barcodes.sh

            # make sure spit files get archived
            fileList=$($BIO_PYTHON ./vdjpipe_barcodes.py --fileList "${TotalOutputFilename}-{MID}.fastq" $BarcodeFile)
            ARCHIVE_FILE_LIST="${ARCHIVE_FILE_LIST} ${fileList}"
            fileList=$($BIO_PYTHON ./vdjpipe_barcodes.py --fileList "${FindUniqueOutput}-{MID}.fasta" $BarcodeFile)
            ARCHIVE_FILE_LIST="${ARCHIVE_FILE_LIST} ${fileList}"
            fileList=$($BIO_PYTHON ./vdjpipe_barcodes.py --fileList "${FindUniqueDuplicates}-{MID}.tsv" $BarcodeFile)
            ARCHIVE_FILE_LIST="${ARCHIVE_FILE_LIST} ${fileList}"
        else
            # concatenate, exclude the split files from archiving
            $BIO_PYTHON ./vdjpipe_barcodes.py --catFiles "${TotalOutputFilename}-{MID}.fastq" $BarcodeFile >vdjpipe_barcodes.sh
            bash ./vdjpipe_barcodes.sh "${TotalOutputFilename}.fastq"
            rm -f vdjpipe_barcodes.sh
            addOutputFile $group $APP_NAME processed_sequence "${TotalOutputFilename}.fastq" "Total Post-Filter Sequences (${fileBasename})" "read" "${WasDerivedFrom}"
            $BIO_PYTHON ./vdjpipe_barcodes.py --fileList "${TotalOutputFilename}-{MID}.fastq" $BarcodeFile >> .agave.archive

            $BIO_PYTHON ./vdjpipe_barcodes.py --catFiles "${FindUniqueOutput}-{MID}.fasta" $BarcodeFile >vdjpipe_barcodes.sh
            bash ./vdjpipe_barcodes.sh "${FindUniqueOutput}.fasta"
            rm -f vdjpipe_barcodes.sh
            addOutputFile $group $APP_NAME sequence "${FindUniqueOutput}.fasta" "Unique Post-Filter Sequences (${fileBasename})" "read" "${WasDerivedFrom}"
            $BIO_PYTHON ./vdjpipe_barcodes.py --fileList "${FindUniqueOutput}-{MID}.fasta" $BarcodeFile >> .agave.archive

            $BIO_PYTHON ./vdjpipe_barcodes.py --catFiles "${FindUniqueDuplicates}-{MID}.tsv" $BarcodeFile >vdjpipe_barcodes.sh
            bash ./vdjpipe_barcodes.sh "${FindUniqueDuplicates}.tsv"
            rm -f vdjpipe_barcodes.sh
            addOutputFile $group $APP_NAME duplicates "${FindUniqueDuplicates}.tsv" "Unique Sequence Duplicates Table (${fileBasename})" "tsv" "${WasDerivedFrom}"
            $BIO_PYTHON ./vdjpipe_barcodes.py --fileList "${FindUniqueDuplicates}-{MID}.tsv" $BarcodeFile >> .agave.archive
        fi
    fi
}

function run_vdjpipe_workflow() {
    initProvenance
#    addLogFile $APP_NAME log stdout "${AGAVE_LOG_NAME}.out" "Job Output Log" "log" null
#    addLogFile $APP_NAME log stderr "${AGAVE_LOG_NAME}.err" "Job Error Log" "log" null
#    addLogFile $APP_NAME log agave_log .agave.log "Agave Output Log" "log" null

    # Exclude input files from archive
#    noArchive "${ProjectDirectory}"
#    for file in $SequenceFASTQ; do
#        noArchive "$file"
#    done
    for file in $JobFiles; do
        if [ -f $file ]; then
            expandfile $file
#            noArchive $file
#            noArchive "${file%.*}"
        fi
    done

    # Paired-end read workflow needs to merge
    if [ "$Workflow" = "paired" ]; then
        echo "Merging paired-end reads."
        forwardReads=($SequenceForwardPairedFiles)
        forwardReadsMetadata=($SequenceForwardPairedFilesMetadata)
        reverseReads=($SequenceReversePairedFiles)

        count=0
        while [ "x${forwardReads[count]}" != "x" ]
        do
            file=${forwardReads[count]}
            mfile=${forwardReadsMetadata[count]}
            rfile=${reverseReads[count]}
#            noArchive "$file"
#            noArchive "$rfile"

            group="merge${count}"
            addGroup $group file

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
            addConfigFile $group config paired "${ConfigFile}" "VDJPipe Read Merging Configuration (${fileBasename})" "json" null
            addLogFile $group log merge_summary "${SummaryFile}" "VDJPipe Read Merging Output Summary (${fileBasename})" "log" null

            # run the paired merging
            $VDJ_PIPE --config ${ConfigFile}
            addCalculation merge_paired_reads

            SequenceFASTQ="$SequenceFASTQ ${MergeFile}"
            SequenceFASTQMetadata="$SequenceFASTQMetadata $group"
            addOutputFile $group $APP_NAME merged_sequence "${MergeFile}" "Merged Pre-Filter Sequences (${fileBasename})" "read" $mfile

            count=$(( $count + 1 ))
        done
    fi

    # FASTA/QUAL workflow
    readFiles=($SequenceFASTA)
    readFilesMetadata=($SequenceFASTAMetadata)
    qualityFiles=($SequenceQualityFiles)

    count=0
    while [ "x${readFiles[count]}" != "x" ]
    do
        file=${readFiles[count]}
        mfile=${readFilesMetadata[count]}
        qfile=${qualityFiles[count]}
#        noArchive "$file"
#        noArchive "$qfile"

        group="group${count}"
        addGroup $group file

        filePath="${file##*/}" # path/file.fastq -> file.fastq
        fileExtension="${filePath##*.}" # file.fastq -> fastq
        fileBasename="${filePath%.*}" # file.fastq -> file

        # Construct VDJPipe config file
        OutputPrefix=$fileBasename
        ConfigFile=${OutputPrefix}.vdjpipe_config.json
        SummaryFile=${OutputPrefix}.summary.txt
        $PYTHON ./vdjpipe_create_config.py --init ${SummaryFile} ${ConfigFile}
        addConfigFile $group config main "${ConfigFile}" "VDJPipe Input Configuration (${fileBasename})" "json" null
        addLogFile $group log summary "${SummaryFile}" "VDJPipe Output Summary (${fileBasename})" "log" null

        $PYTHON ./vdjpipe_create_config.py ${ConfigFile} --fasta $file --quals $qfile

        run_vdjpipe "${OutputPrefix}" "${ConfigFile}" "${mfile}"

        count=$(( $count + 1 ))
    done

    # FASTQ workflow
    # use same counter
    readFiles=($SequenceFASTQ)
    readFilesMetadata=($SequenceFASTQMetadata)

    while [ "x${readFiles[count]}" != "x" ]
    do
        file=${readFiles[count]}
        mfile=${readFilesMetadata[count]}
#        noArchive "$file"

        group="group${count}"
        addGroup $group file

        filePath="${file##*/}" # path/file.fastq -> file.fastq
        fileExtension="${filePath##*.}" # file.fastq -> fastq
        fileBasename="${filePath%.*}" # file.fastq -> file

        # Construct VDJPipe config file
        OutputPrefix=$fileBasename
        ConfigFile=${OutputPrefix}.vdjpipe_config.json
        SummaryFile=${OutputPrefix}.summary.txt
        $PYTHON ./vdjpipe_create_config.py --init ${SummaryFile} ${ConfigFile}
        addConfigFile $group config main "${ConfigFile}" "VDJPipe Input Configuration (${fileBasename})" "json" null
        addLogFile $group log summary "${SummaryFile}" "VDJPipe Output Summary (${fileBasename})" "log" null

        $PYTHON ./vdjpipe_create_config.py ${ConfigFile} --fastq $file

        run_vdjpipe "${OutputPrefix}" "${ConfigFile}" "${mfile}"

        count=$(( $count + 1 ))
    done

    # Generate summary report
    $PYTHON ./vdjpipe_report.py *.summary.txt
    addLogFile $APP_NAME log vdjpipe_summary vdjpipe_summary.csv "VDJPipe Summary Report" "csv" null

    # zip archive of all output files
    for file in $ARCHIVE_FILE_LIST; do
        if [ -f $file ]; then
            cp -f $file ${_tapisJobUUID}
        fi
    done
    zip ${_tapisJobUUID}.zip ${_tapisJobUUID}/*
    addLogFile $APP_NAME log output_archive ${_tapisJobUUID}.zip "Archive of Output Files" "zip" null
}
