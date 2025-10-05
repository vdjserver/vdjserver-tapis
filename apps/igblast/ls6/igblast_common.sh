#
# VDJServer IgBlast common functions
#
# VDJServer Analysis Portal
# VDJServer Tapis applications
# https://vdjserver.org
#
# Copyright (C) 2016-2024 The University of Texas Southwestern Medical Center
# Author: Scott Christley
# Date: Sep 1, 2016
# 

# required global variables:
# IGBLASTN_EXE
# PYTHON
# AIRR_TOOLS
# and...
# The agave app input and parameters

APP_NAME=igBlast

# automatic parallelization of large files
READS_PER_FILE=10000

# bring in common functions
source ./common_functions.sh

# bring in provenance functions
source ./provenance_functions.sh

# ----------------------------------------------------------------------------
# IgBlast workflow

function gather_secondary_inputs() {
    # Gather secondary input files
    # This is used to get around Agave size limits for job inputs and parameters
    if [[ $SecondaryInputsFlag -eq 1 ]]; then
        echo "Gathering secondary inputs"
        moreFiles=$(${PYTHON} ./process_metadata.py --getSecondaryInput "${ProjectDirectory}/" QueryFilesMetadata study_metadata.json)
        query="${query} ${moreFiles}"
        moreFiles=$(${PYTHON} ./process_metadata.py --getSecondaryEntry QueryFilesMetadata study_metadata.json)
        QueryFilesMetadata="${QueryFilesMetadata} ${moreFiles}"
    fi
}

function print_versions() {
    echo "VERSIONS:"
    echo "  $($PYTHON --version 2>&1)"
    echo "  $($IGBLASTN_EXE -version 2>&1)"
    echo "  $($AIRR_TOOLS --version 2>&1)"
    apptainer exec -e ${repcalc_image} versions report
    apptainer exec -e ${repcalc_image} repcalc --version
    echo -e "\nSTART at $(date)"
}

function print_parameters() {
    echo "Input files:"
    echo "igblast_image=${igblast_image}"
    echo "repcalc_image=${repcalc_image}"
    echo "germline_archive=${germline_archive}"
    echo "ProjectDirectory=${ProjectDirectory}"
    echo "AIRRMetadata=${AIRRMetadata}"
    echo "JobFiles=${JobFiles}"
    echo "query=$query"
    echo ""
    echo "Application parameters:"
    echo "SecondaryInputsFlag=${SecondaryInputsFlag}"
    echo "repertoires=$repertoires"
    echo "species=$species"
    echo "strain=$strain"
    echo "locus=$locus"
    echo "germline_db=${germline_db}"
    echo "germline_fasta=${germline_fasta}"
    echo "domain_system=$domain_system"
    echo "ClonalTool=$ClonalTool"
}

function run_igblast_workflow() {
    addCalculation vdj_alignment
    addCalculation parse_igblast

    # Exclude input files from archive
    for file in $JobFiles; do
        if [ -f $file ]; then
            expandfile $file
        fi
    done

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

    filelist=()
    count=0
    for file in $query; do
        # unique group name to put in metadata
        group="group${count}"
        addGroup $group file

        fileOutname="${file##*/}" # test/file -> file
        addOutputFile $group $APP_NAME assignment_sequence "$file" "Input Sequences ($fileOutname)" "read" null

        expandfile $file
        fileExtension="${file##*.}" # file.fastq -> fastq
        fileBasename="${file%.*}" # file.fastq -> file

        if [[ "$fileExtension" == "fastq" ]] || [[ "$fileExtension" == "fq" ]]; then
            ${PYTHON} fastq2fasta.py -i $file -o $fileBasename.fasta
            file="$fileBasename.fasta"
        fi

        # save expanded filenames for later merging
        filelist[${#filelist[@]}]=$file

        if [ "$(grep '>' $file | wc -l)" -gt $READS_PER_FILE ]; then
            splitfasta.pl -f $file -r $READS_PER_FILE -o . -s ${fileBasename}_p
            smallFiles="$(ls ${fileBasename}_p*.fasta)"
        else
            smallFiles="$file"
        fi

        for smallFile in $smallFiles; do
            # These come from Agave, but I need to assign them inside the loop.
            organism=${species}
            germline_set=${species}
            if [ "$species" == "macaque" ]; then
                organism="rhesus_monkey"
                strain="indian"
                germline_set="macaque_indian"
            fi
            QUERY_ARGS=""
            ARGS=""
            MDARGS=""
            if [ -f $smallFile ]; then 
                QUERY_ARGS="-query $smallFile" 
                MDARGS="$MDARGS $smallFile"
                MDARGS="$MDARGS $PWD/${smallFile}.igblast.txt"
            fi
            if [ -n $locus ]; then 
                if [ "$locus" == "TR" ]; then seqType="TCR"; fi  
                if [ "$locus" == "IG" ]; then seqType="Ig"; fi  
                ARGS="$ARGS -ig_seqtype $seqType"
                MDARGS="$MDARGS $locus"
            fi
            if [ -n $organism ]; then 
                ARGS="$ARGS -organism $organism"
                ARGS="$ARGS -auxiliary_data $IGDATA/optional_file/${germline_set}_gl.aux"
                ARGS="$ARGS -germline_db_V $VDJ_DB_ROOT/${germline_set}/ReferenceDirectorySet/${germline_set}_${locus}_V.fna"
                ARGS="$ARGS -germline_db_D $VDJ_DB_ROOT/${germline_set}/ReferenceDirectorySet/${germline_set}_${locus}_D.fna"
                ARGS="$ARGS -germline_db_J $VDJ_DB_ROOT/${germline_set}/ReferenceDirectorySet/${germline_set}_${locus}_J.fna"
                MDARGS="$MDARGS $organism"
            fi
            if [ -n $domain_system ]; then ARGS="$ARGS -domain_system $domain_system"; fi

            IGBLAST_PARAMS="$ARGS"

            # AIRR output
            AIRR_ARGS="$QUERY_ARGS $ARGS -outfmt 19"
            echo "export IGDATA=\"$IGDATA\" && $IGBLASTN_EXE $AIRR_ARGS > ${smallFile}.igblast.airr.tsv" >> joblist

            # ChangeO output
            CO_ARGS="$QUERY_ARGS $ARGS -outfmt "
            OUTFMT="7 qseqid qgi qacc qaccver qlen sseqid sallseqid sgi sallgi sacc saccver sallacc slen qstart qend sstart send qseq sseq evalue bitscore score length pident nident mismatch positive gapopen gaps ppos frames qframe sframe btop"

            # macaque not support yet
            #if [ "$species" != "macaque" ]; then
                # igblast jobs
                echo "export IGDATA=\"$IGDATA\" && export VDJ_DB_ROOT=\"$VDJ_DB_ROOT\" && $IGBLASTN_EXE $CO_ARGS \"$OUTFMT\" > ${smallFile}.igblast.txt" >> joblist

                # the post processing jobs
                echo "export IGDATA=\"$IGDATA\" && export VDJ_DB_ROOT=\"$VDJ_DB_ROOT\" && apptainer exec ${repcalc_image} bash ./do_airr_makedb.sh $MDARGS" >> joblist-post-process
            #fi

        done

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

    #
    # move the post processing of the igblast output to here
    #
    export LAUNCHER_JOB_FILE=joblist-post-process

    # check number of jobs to be run
    export LAUNCHER_PPN=$LAUNCHER_MID_PPN
    numJobs=$(cat joblist-post-process | wc -l)
    if [ $numJobs -lt $LAUNCHER_PPN ]; then
        export LAUNCHER_PPN=$numJobs
    fi

    echo "Starting post processing on $(date)"
    $LAUNCHER_DIR/paramrun

    # ----------------------------------------------------------------------------
    # and now to knit smallFiles back together
    seqMetadata=($repertoires)
    count=0
    for file in ${filelist[@]}; do
        mfile=${seqMetadata[count]}
        fileBasename="${file%.*}" # test/file.fasta -> test/file
        fileOutname="${fileBasename##*/}" # test/file -> file
        checkfiles=(`ls -1 ${fileBasename}_p*.igblast.airr.tsv 2>/dev/null`)

        if [ ${#checkfiles[@]} -ne 0 ]; then
            # merge files
            apptainer exec -e ${repcalc_image} bash do_merge.sh ${fileBasename} ${fileOutname}
            rm -f ${fileBasename}_p*.igblast.airr.tsv
            rm -f ${fileBasename}_p*.igblast.makedb.airr.tsv
            rm -f ${fileBasename}_p*.igblast.fail-makedb.airr.tsv
        else
            # no merging so rename to remove extension
            mv ${file}.igblast.airr.tsv ${fileOutname}.igblast.airr.new.tsv
            if [ "$species" != "macaque" ]; then
                mv ${file}.igblast.makedb.airr.tsv ${fileOutname}.igblast.makedb.airr.tsv
                mv ${file}.igblast.fail-makedb.airr.tsv ${fileOutname}.igblast.fail-makedb.airr.tsv
            fi
        fi

        if [ -f "${fileOutname}.igblast.fail-makedb.airr.tsv" ]; then
            addOutputFile $group $APP_NAME airr-fail-makedb ${fileOutname}.igblast.fail-makedb.airr.tsv "${fileOutname} Change-O MakeDb Failed" "tsv" $mfile
        fi

        # process pRESTO annotations
        apptainer exec -e ${repcalc_image} bash do_annotations.sh ${fileOutname}
        rm -f ${fileOutname}.igblast.airr.new.tsv

        # assign repertoire IDs
        mv ${fileOutname}.igblast.airr.tsv ${fileOutname}.igblast.orig.airr.tsv
        target_file="${mfile}.igblast.airr.tsv"
        if [ -f "$target_file" ]; then
            # Find next available numbered suffix to avoid overwriting
            i=1
            while [ -f "${mfile}.igblast.airr.${i}.tsv" ]; do
                ((i++))
            done
            # Assign repertoire ID to orig file, output to numbered file
            $PYTHON assign_repertoire_id.py ${mfile} ${_tapisJobUUID} ${fileOutname}.igblast.orig.airr.tsv ${mfile}.igblast.airr.${i}.tsv
        else
            # First file for this repertoire id, output normally
            $PYTHON assign_repertoire_id.py ${mfile} ${_tapisJobUUID} ${fileOutname}.igblast.orig.airr.tsv ${target_file}
        fi

        mv ${fileOutname}.igblast.makedb.airr.tsv ${fileOutname}.igblast.makedb.orig.airr.tsv
        target_file_makedb="${mfile}.igblast.makedb.airr.tsv"
        if [ -f "$target_file_makedb" ]; then
            # Find next available numbered suffix to avoid overwriting
            i=1
            while [ -f "${mfile}.igblast.makedb.airr.${i}.tsv" ]; do
                ((i++))
            done
            # Assign repertoire ID to orig file, output to numbered file
            $PYTHON assign_repertoire_id.py --add-missing ${mfile} ${_tapisJobUUID} ${fileOutname}.igblast.makedb.orig.airr.tsv ${mfile}.igblast.makedb.airr.${i}.tsv
        else
            # First file for this repertoire id, output normally
            $PYTHON assign_repertoire_id.py --add-missing ${mfile} ${_tapisJobUUID} ${fileOutname}.igblast.makedb.orig.airr.tsv ${target_file_makedb}
        fi
        count=$(( $count + 1 ))
    done

    # --- Merge per repertoire ID as there could be duplicate repertoire ids and they will be merged multiple times.---
    unique_repertoire_ids=($(printf "%s\n" "${seqMetadata[@]}" | sort -u))
    count=0

    for mfile in "${unique_repertoire_ids[@]}"; do
        fileOutname="${mfile##*/}" # For labeling

        # Merge AIRR files
        airr_files=( "${mfile}.igblast.airr.tsv" "${mfile}.igblast.airr."*.tsv )
        existing_airr_files=()
        for f in "${airr_files[@]}"; do
            [ -f "$f" ] && existing_airr_files+=("$f")
        done

        if [ ${#existing_airr_files[@]} -gt 1 ]; then
            echo "Merging AIRR files for repertoire ID: $mfile"
            ${AIRR_TOOLS} merge -a "${existing_airr_files[@]}" -o "${mfile}.igblast.airr.new.tsv"
            mv "${mfile}.igblast.airr.new.tsv" "${mfile}.igblast.airr.tsv"
            # After merging AIRR files remove input files
            echo "Cleaning up AIRR input files for $mfile"
            rm -f ${mfile}.igblast.airr.*.tsv
        fi

        # Merge makedb files if needed
        if [ "$species" != "macaque" ]; then
            makedb_files=( "${mfile}.igblast.makedb.airr.tsv" "${mfile}.igblast.makedb.airr."*.tsv )
            existing_makedb_files=()
            for f in "${makedb_files[@]}"; do
                [ -f "$f" ] && existing_makedb_files+=("$f")
            done

            if [ ${#existing_makedb_files[@]} -gt 1 ]; then
                echo "Merging makedb files for repertoire ID: $mfile"
                ${AIRR_TOOLS} merge -a "${existing_makedb_files[@]}" -o "${mfile}.igblast.makedb.airr.new.tsv"
                mv "${mfile}.igblast.makedb.airr.new.tsv" "${mfile}.igblast.makedb.airr.tsv"
                # After merging AIRR files remove input files
                echo "Cleaning up AIRR input files for $mfile"
                rm -f ${mfile}.igblast.makedb.airr.*.tsv
            fi
        fi

        # add to process metadata
        # they will be compressed later
        group="group${count}"
        addOutputFile $group $APP_NAME airr ${mfile}.igblast.airr.tsv.gz "${fileOutname} AIRR TSV" "tsv" $mfile
        gzipFile ${mfile}.igblast.airr.tsv
        if [ "$species" != "macaque" ]; then
            addOutputFile $group $APP_NAME airr-makedb ${mfile}.igblast.makedb.airr.tsv.gz "${fileOutname} Change-O MakeDb AIRR TSV" "tsv" $mfile
            gzipFile ${mfile}.igblast.makedb.airr.tsv
        fi
        count=$(( $count + 1 ))
    done


    # ----------------------------------------------------------------------------
    # generate count statistics
    echo Generating count statistics
    $PYTHON count_statistics.py *.igblast.airr.tsv
    mv count_statistics.csv igblast_count_statistics.csv
    addLogFile $APP_NAME log igblast_count_statistics igblast_count_statistics.csv "IgBlast AIRR TSV Count Statistics" "csv" null
    addArchiveFile igblast_count_statistics.csv
    $PYTHON count_statistics.py *.makedb.airr.tsv
    mv count_statistics.csv makedb_count_statistics.csv
    addLogFile $APP_NAME log makedb_count_statistics makedb_count_statistics.csv "Change-O MakeDb AIRR TSV Count Statistics" "csv" null
    addArchiveFile makedb_count_statistics.csv
    $PYTHON count_statistics.py *.fail-makedb.airr.tsv
    mv count_statistics.csv fail-makedb_count_statistics.csv
    addLogFile $APP_NAME log fail-makedb_count_statistics fail-makedb_count_statistics.csv "Change-O MakeDb Failed Count Statistics" "csv" null
    addArchiveFile fail-makedb_count_statistics.csv
}

function run_assign_clones() {
    addCalculation clonal_assignment

    # launcher job file
    if [ -f joblist-clones ]; then
        echo "Warning: removing file 'joblist-clones'.  That filename is reserved." 1>&2
        rm joblist-clones
        touch joblist-clones
    fi
    #noArchive "joblist-clones"

    # create AIRR metadata
    if [[ "x$AIRRMetadata" == "x" ]]; then
        AIRRMetadata="study_metadata.airr.json"
        $PYTHON create_airr_metadata.py $AIRRMetadata ${_tapisJobUUID} $repertoires
    fi

    # Assign Clones
    cloneFileList=()
    count=0
    if [[ "$ClonalTool" == "changeo" ]] ; then
        fileMetadataList=($repertoires)
        for file in ${filelist[@]}; do
            mfile=${fileMetadataList[count]}
            fileBasename="${file%.*}" # test/file.fasta -> test/file
            fileOutname="${fileBasename##*/}" # test/file -> file
            file=${mfile}.igblast.makedb.airr.tsv

            # Assuming airr.tsv extension
            fileOutname="${file%.*}" # file.airr.tsv -> file.airr
            fileOutname="${fileOutname%.*}" # file.airr -> file
            fileOutname="${fileOutname##*/}" # foo/bar/file -> file
            #noArchive $fileOutname

            # Change-O clones
            #echo "apptainer exec -e ${repcalc_image} bash changeo_clones.sh ${file} ${fileOutname} ${AGAVE_JOB_PROCESSORS_PER_NODE}" >> joblist
            echo "apptainer exec -e ${repcalc_image} bash changeo_clones.sh ${file} ${fileOutname} 4" >> joblist-clones

            # save filenames for later processing
            alleleFile="${fileOutname}.allele.clone.airr.tsv"
            cloneFileList[${#cloneFileList[@]}]=$alleleFile
            geneFile="${fileOutname}.gene.clone.airr.tsv"
            cloneFileList[${#cloneFileList[@]}]=$geneFile

            # will get compressed at end
            group="group${count}"
            addOutputFile $group $APP_NAME igblast-makedb-allele-clone ${alleleFile}.gz "${fileOutname} Change-O IG Allele Clones" "tsv" $mfile
            addOutputFile $group $APP_NAME igblast-makedb-gene-clone ${geneFile}.gz "${fileOutname} Change-O IG Gene Clones" "tsv" $mfile
            gzipFile ${alleleFile}
            gzipFile ${geneFile}

            count=$(( $count + 1 ))
        done
    fi

    if [[ "$ClonalTool" == "repcalc" ]] ; then
        fileMetadataList=($repertoires)
        for file in ${filelist[@]}; do
            mfile=${fileMetadataList[count]}
            fileBasename="${file%.*}" # test/file.fasta -> test/file
            #rep_id="${fileBasename##*/}" # test/file -> file
            rep_id=$mfile

            # We have the raw IgBlast AIRR TSV and the MakeDB processed AIRR TSV

            # RepCalc clones
            processing_stage=igblast
            #addProcessingStaqe $processing_stage
            out_prefix=${rep_id}.${processing_stage}
            file=${out_prefix}.airr.tsv
            echo "apptainer exec -e ${repcalc_image} bash repcalc_clones.sh ${AIRRMetadata} ${germline_db} ${file} ${rep_id} ${processing_stage}" >> joblist-clones
            alleleFile=${out_prefix}.allele.clone.airr.tsv
            geneFile=${out_prefix}.gene.clone.airr.tsv

            # will get compressed at end
            group="group${count}"
            addOutputFile $group $APP_NAME igblast-allele-clone ${alleleFile}.gz "${rep_id} RepCalc TCR Allele Clones (${processing_stage})" "tsv" $mfile
            addOutputFile $group $APP_NAME igblast-gene-clone ${geneFile}.gz "${rep_id} RepCalc TCR Gene Clones (${processing_stage})" "tsv" $mfile
            gzipFile ${alleleFile}
            gzipFile ${geneFile}

            # RepCalc clones
            processing_stage=igblast.makedb
            #addProcessingStaqe $processing_stage
            out_prefix=${rep_id}.${processing_stage}
            file=${out_prefix}.airr.tsv
            echo "apptainer exec -e ${repcalc_image} bash repcalc_clones.sh ${AIRRMetadata} ${germline_db} ${file} ${rep_id} ${processing_stage}" >> joblist-clones
            alleleFile=${out_prefix}.allele.clone.airr.tsv
            geneFile=${out_prefix}.gene.clone.airr.tsv

            # will get compressed at end
            group="group${count}"
            addOutputFile $group $APP_NAME igblast-makedb-allele-clone ${alleleFile}.gz "${rep_id} RepCalc TCR Allele Clones (${processing_stage})" "tsv" $mfile
            addOutputFile $group $APP_NAME igblast-makedb-gene-clone ${geneFile}.gz "${rep_id} RepCalc TCR Gene Clones (${processing_stage})" "tsv" $mfile
            gzipFile ${alleleFile}
            gzipFile ${geneFile}

            count=$(( $count + 1 ))
        done
    fi

    # check number of jobs to be run
    export LAUNCHER_JOB_FILE=joblist-clones
    numJobs=$(cat joblist-clones | wc -l)
    export LAUNCHER_PPN=$LAUNCHER_LOW_PPN
    if [ $numJobs -lt $LAUNCHER_PPN ]; then
        export LAUNCHER_PPN=$numJobs
    fi

    # run launcher
    $LAUNCHER_DIR/paramrun

    # generate clone report
    if [[ "$ClonalTool" == "changeo" ]] ; then
        $PYTHON clone_report.py *.makedb.airr.tsv
        addLogFile $APP_NAME log clone_report clone_report.csv "Clonal Assignment Summary Report" "csv" null
        addArchiveFile clone_report.csv
    fi
}

function compress_and_archive() {
    # ----------------------------------------------------------------------------
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
    addLogFile $APP_NAME log output_archive ${_tapisJobUUID}.zip "Archive of Output Files" "zip" null
    cp ${_tapisJobUUID}.zip output
}
