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

APP_NAME=presto

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
    echo "ForwardPrimer=$ForwardPrimer"
    echo "ForwardPrimerUMI=$ForwardPrimerUMI"
    echo "ForwardPrimerMaxError=$ForwardPrimerMaxError"
    echo "ForwardPrimerMaxLength=$ForwardPrimerMaxLength"
    echo "ForwardPrimerStartPosition=$ForwardPrimerStartPosition"
    echo "Reverse primer:"
    echo "ReversePrimer=$ReversePrimer"
    echo "ReversePrimerUMI=$ReversePrimerUMI"
    echo "ReversePrimerMaxError=$ReversePrimerMaxError"
    echo "ReversePrimerMaxLength=$ReversePrimerMaxLength"
    echo "ReversePrimerStartPosition=$ReversePrimerStartPosition"
    echo "Find unique sequences:"
    echo "FindUniqueFlag=$FindUniqueFlag"
    echo "FindUniqueMaxNucleotides=$FindUniqueMaxNucleotides"
    echo "FindUniqueExclude=$FindUniqueExclude"
}

function run_presto_workflow() {
    initProvenance

    intermediateFiles=()

    # Exclude input files from archive
    for file in $JobFiles; do
        if [ -f $file ]; then
            unzip $file
        fi
    done

    # Assemble paired reads
    if [ "$Workflow" = "paired" ]; then
        echo "Convert and assemble paired reads"
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
            addCalculation merge_paired_reads

            SequenceFiles="$SequenceFiles ${OutputName}_assemble-pass.${fileExtension}"
            cp ${OutputName}_assemble-pass.${fileExtension} ${OutputPrefix}_assemble.${fileExtension}
            addOutputFile $group $APP_NAME merged_sequence "${OutputPrefix}_assemble.${fileExtension}" "Merged Pre-Filter Sequences (${OutputPrefix})" "read" null

            count=$(( $count + 1 ))
        done
    fi

    readFiles=($SequenceFiles)

    count=0
    while [ "x${readFiles[count]}" != "x" ]
    do
        file=${readFiles[count]}

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
            addStatisticsFile $group pre composition "pre-filter_${file}.composition.csv" "Nucleotide Composition" "tsv" null
            addStatisticsFile $group pre gc_hist "pre-filter_${file}.gc_hist.csv" "GC% Histogram" "tsv" null
            addStatisticsFile $group pre heat_map "pre-filter_${file}.heat_map.csv" "Heatmap" "tsv" null
            addStatisticsFile $group pre len_hist "pre-filter_${file}.len_hist.csv" "Sequence Length Histogram" "tsv" null
            addStatisticsFile $group pre mean_q_hist "pre-filter_${file}.mean_q_hist.csv" "Mean Quality Histogram" "tsv" null
            addStatisticsFile $group pre qstats "pre-filter_${file}.qstats.csv" "Quality Scores" "tsv" null

            $VDJ_PIPE --config pre-statistics.json
            addCalculation "pre-filter_statistics"
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
            addCalculation length_filtering

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
            addCalculation quality_filtering

            intermediateFiles[${#intermediateFiles[@]}]=$prevPassFile
            prevPassFile="${OutputName}_quality-pass.${fileExtension}"
        fi

        # Run vdjpipe to generate statistics
        if [[ $PostFilterStatisticsFlag -eq 1 ]]; then
            echo "Generate post-filter statistics"

            $PYTHON3 ./statistics.py statistics-template.json $prevPassFile "post-filter_" "post-statistics.json"
            addStatisticsFile $group post composition "post-filter_${prevPassFile}.composition.csv" "Nucleotide Composition" "tsv" null
            addStatisticsFile $group post gc_hist "post-filter_${prevPassFile}.gc_hist.csv" "GC% Histogram" "tsv" null
            addStatisticsFile $group post heat_map "post-filter_${prevPassFile}.heat_map.csv" "Heatmap" "tsv" null
            addStatisticsFile $group post len_hist "post-filter_${prevPassFile}.len_hist.csv" "Sequence Length Histogram" "tsv" null
            addStatisticsFile $group post mean_q_hist "post-filter_${prevPassFile}.mean_q_hist.csv" "Mean Quality Histogram" "tsv" null
            addStatisticsFile $group post qstats "post-filter_${prevPassFile}.qstats.csv" "Quality Scores" "tsv" null

            $VDJ_PIPE --config post-statistics.json
            addCalculation "post-filter_statistics"
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
            addCalculation barcode_demultiplexing

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
            addCalculation forward_primer

            intermediateFiles[${#intermediateFiles[@]}]=$prevPassFile
            prevPassFile="${OutputName}-V_primers-pass.${fileExtension}"
            EXPAND_PRIMER=1
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
            addCalculation reverse_primer

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
            addCalculation umi_consensus

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
        addOutputFile $group $APP_NAME processed_sequence "$prevPassFile" "Total Post-Filter Sequences (${OutputPrefix})" "read" null

        # Split by barcode
        if [[ $BarcodeSplitFlag -eq 1 ]]; then
            echo "Split by barcode"
            $SPLIT_SEQ_PY group -s $prevPassFile -f MID
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
            addCalculation find_unique_sequences

            prevPassFile="${OutputPrefix}_collapse-unique.${fileExtension}"
            addOutputFile $group $APP_NAME sequence "$prevPassFile" "Unique Post-Filter Sequences (${OutputPrefix})" "read" null

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

        count=$(( $count + 1 ))
    done

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
