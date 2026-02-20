#
# VDJServer IgBlast common functions
#
# VDJServer Analysis Portal
# VDJServer Tapis applications
# https://vdjserver.org
#
# Copyright (C) 2016-2025 The University of Texas Southwestern Medical Center
# Author: Scott Christley
# Date: Sep 1, 2016
# 

APP_NAME=igblast
# TODO: this is not generic enough
export ACTIVITY_NAME="vdjserver:activity:igblast"

# automatic parallelization of large files
READS_PER_FILE=10000

# bring in common functions
source ./common_functions.sh

# bring in provenance functions
source ./provenance_functions.sh

# ----------------------------------------------------------------------------
# IgBlast workflow

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
    echo "repcalc_image=${repcalc_image}"
    echo "germline_archives=${germline_archives}"
    echo "analysis_provenance=${analysis_provenance}"
    echo "AIRRMetadata=${AIRRMetadata}"
    echo "JobFiles=${JobFiles}"
    echo "query=$query"
    echo ""
    echo "Application parameters:"
    echo "species=$species"
    echo "strain=$strain"
    echo "locus=$locus"
    echo "germline_db_file=${germline_db_file}"
    echo "germline_fasta=${germline_fasta}"
    echo "domain_system=$domain_system"
    echo "ClonalTool=$ClonalTool"
}

function run_igblast_workflow() {
    addCalculation "${ACTIVITY_NAME}" vdj_annotation

    # unarchive job files
    for file in $JobFiles; do
        if [ -f $file ]; then
            expandfile $file

            # copy files that will be processed
            fileBasename="${file%.*}" # test/file.fasta -> test/file
            for file2 in $query; do
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

    if [ -f joblist-post-process ]; then
        echo "Warning: removing file 'joblist-post-process'.  That filename is reserved." 1>&2
        rm joblist-post-process
    fi
    touch joblist-post-process

    filelist=()
    count=0
    repertoires=""
    for file in $query; do
        query_file=$file
        rep_id=$(getRepertoireForFile $file)
        # TODO: check error
        repertoires="${repertoires} ${rep_id}"

        fileOutname="${file##*/}" # test/file -> file
        #addOutputFile $group $APP_NAME assignment_sequence "$file" "Input Sequences ($fileOutname)" "read" null

        expandfile $file
        fileExtension="${file##*.}" # file.fastq -> fastq
        fileBasename="${file%.*}" # file.fastq -> file

        if [[ "$fileExtension" == "fastq" ]] || [[ "$fileExtension" == "fq" ]]; then
            ${PYTHON} fastq2fasta.py -i $file -o $fileBasename.fasta
            file="$fileBasename.fasta"
        fi

        # save expanded filenames for later merging
        filelist[${#filelist[@]}]=$file

        # These come from Agave, but I need to assign them inside the loop.
        # TODO: get these from repertoire metadata
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
            QUERY_ARGS="-query $file" 
            MDARGS="$MDARGS $file"
            MDARGS="$MDARGS $PWD/${file}.igblast.txt"
        fi
        if [ -n $locus ]; then 
            if [ "$locus" == "TR" ]; then seqType="TCR"; fi  
            if [ "$locus" == "IG" ]; then seqType="Ig"; fi  
            ARGS="$ARGS -ig_seqtype $seqType"
            MDARGS="$MDARGS $locus"
        fi
        if [ -n $organism ]; then 
            ARGS="$ARGS -organism $organism"
            
            ARGS="$ARGS -germline_db_V $VDJ_DB_ROOT/${germline_set}/ReferenceDirectorySet/${germline_set}_${locus}_V.fna"
            ARGS="$ARGS -germline_db_D $VDJ_DB_ROOT/${germline_set}/ReferenceDirectorySet/${germline_set}_${locus}_D.fna"
            ARGS="$ARGS -germline_db_J $VDJ_DB_ROOT/${germline_set}/ReferenceDirectorySet/${germline_set}_${locus}_J.fna"
            # If locus is TR then use old auxilary data file.
            if [ "$locus" == "TR" ]; then
                ARGS="$ARGS -auxiliary_data $IGDATA/optional_file/${germline_set}_gl.aux"
            fi

            # for newer version of igblast we need an extra argument
            if [ "$locus" == "IG" ]; then
                ARGS="$ARGS -c_region_db  $VDJ_DB_ROOT/${germline_set}/ReferenceDirectorySet/${germline_set}_${locus}_C.fna"
                ARGS="$ARGS -auxiliary_data  $VDJ_DB_ROOT/${germline_set}/ReferenceDirectorySet/${germline_set}_${locus}.aux"
                ARGS="$ARGS -custom_internal_data $VDJ_DB_ROOT/${germline_set}/ReferenceDirectorySet/${germline_set}_${locus}.ndm"
            fi
            MDARGS="$MDARGS $organism"
        fi
        if [ -n $domain_system ]; then ARGS="$ARGS -domain_system $domain_system"; fi

        IGBLAST_PARAMS="$ARGS"

        # AIRR output
        AIRR_ARGS="$QUERY_ARGS $ARGS -outfmt 19"
        echo "export IGDATA=\"$IGDATA\" && $IGBLASTN_EXE $AIRR_ARGS > ${file}.igblast.airr.tsv" >> joblist

        # ChangeO output
        CO_ARGS="$QUERY_ARGS $ARGS -outfmt "
        OUTFMT="7 qseqid qgi qacc qaccver qlen sseqid sallseqid sgi sallgi sacc saccver sallacc slen qstart qend sstart send qseq sseq evalue bitscore score length pident nident mismatch positive gapopen gaps ppos frames qframe sframe btop"

        # macaque not support yet
        #if [ "$species" != "macaque" ]; then
            # igblast jobs
            echo "export IGDATA=\"$IGDATA\" && export VDJ_DB_ROOT=\"$VDJ_DB_ROOT\" && $IGBLASTN_EXE $CO_ARGS \"$OUTFMT\" > ${file}.igblast.txt" >> joblist

            # the post processing jobs
            echo "export IGDATA=\"$IGDATA\" && export VDJ_DB_ROOT=\"$VDJ_DB_ROOT\" && apptainer exec ${repcalc_image} bash ./do_airr_makedb.sh $MDARGS" >> joblist-post-process
        #fi

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

    # ----------------------------------------------------------------------------

    echo "Starting post processing on $(date)"
    $LAUNCHER_DIR/paramrun

    seqMetadata=($repertoires)
    count=0
    for file in ${filelist[@]}; do
        mfile=${seqMetadata[count]}

        fileBasename="${file%.*}" # test/file.fasta -> test/file
        fileOutname="${fileBasename##*/}" # test/file -> file

        # no merging so rename to remove extension
        mv ${file}.igblast.airr.tsv ${fileOutname}.igblast.airr.new.tsv
        mv ${file}.igblast.makedb.airr.tsv ${fileOutname}.igblast.makedb.airr.tsv

        if [ -f "${file}.igblast.fail-makedb.airr.tsv" ]; then
            mv ${file}.igblast.fail-makedb.airr.tsv ${fileOutname}.igblast.fail-makedb.airr.tsv
            wasDerivedFrom "${fileOutname}.igblast.fail-makedb.airr.tsv" "${file}" "airr-fail-makedb" "Change-O MakeDb Failed" tsv
            #addOutputFile $group $APP_NAME airr-fail-makedb ${fileOutname}.igblast.fail-makedb.airr.tsv "${fileOutname} Change-O MakeDb Failed" "tsv" $mfile
        fi

        # process pRESTO annotations
        # TODO: parallelize
        apptainer exec -e ${repcalc_image} bash do_annotations.sh ${fileOutname}
        rm -f ${fileOutname}.igblast.airr.new.tsv

        # assign repertoire IDs
        # If multiple sample files have same repertoire ID, write in separate file, and merge later
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
        # TODO: provenance
        #group="group${count}"
        #addOutputFile $group $APP_NAME airr ${mfile}.igblast.airr.tsv.gz "${fileOutname} AIRR TSV" "tsv" $mfile
        gzipFile ${mfile}.igblast.airr.tsv
        if [ "$species" != "macaque" ]; then
            #addOutputFile $group $APP_NAME airr-makedb ${mfile}.igblast.makedb.airr.tsv.gz "${fileOutname} Change-O MakeDb AIRR TSV" "tsv" $mfile
            gzipFile ${mfile}.igblast.makedb.airr.tsv
        fi
        count=$(( $count + 1 ))
    done

    #add provenance here.
    count=0
    for file in ${filelist[@]}; do
        mfile=${seqMetadata[count]}

        wasDerivedFrom "${mfile}.igblast.airr.tsv.gz" "${file}" "vdj_sequence_annotation" "IgBlast AIRR TSV" tsv
        wasDerivedFrom "${mfile}.igblast.makedb.airr.tsv.gz" "${file}" "vdj_sequence_annotation" "Change-O MakeDb AIRR TSV" tsv

        count=$(( $count + 1 ))
    done

    # ----------------------------------------------------------------------------
    # generate count statistics
    echo Generating count statistics
    $PYTHON count_statistics.py *.igblast.airr.tsv
    mv count_statistics.csv igblast_count_statistics.csv
    wasGeneratedBy "igblast_count_statistics.csv" "${ACTIVITY_NAME}" igblast_count_statistics "IgBlast AIRR TSV Count Statistics" csv
    #addLogFile $APP_NAME log igblast_count_statistics igblast_count_statistics.csv "IgBlast AIRR TSV Count Statistics" "csv" null
    #addArchiveFile igblast_count_statistics.csv
    $PYTHON count_statistics.py *.makedb.airr.tsv
    mv count_statistics.csv makedb_count_statistics.csv
    wasGeneratedBy "makedb_count_statistics.csv" "${ACTIVITY_NAME}" makedb_count_statistics "Change-O MakeDb AIRR TSV Count Statistics" csv
    #addLogFile $APP_NAME log makedb_count_statistics makedb_count_statistics.csv "Change-O MakeDb AIRR TSV Count Statistics" "csv" null
    #addArchiveFile makedb_count_statistics.csv
    has_fail_makedb=0
    if ls *.fail-makedb.airr.tsv 1> /dev/null 2>&1; then
        has_fail_makedb=1
    fi
    if [[ $has_fail_makedb -eq 1 ]]; then
        $PYTHON count_statistics.py *.fail-makedb.airr.tsv
        mv count_statistics.csv fail-makedb_count_statistics.csv
        wasGeneratedBy "fail-makedb_count_statistics.csv" "${ACTIVITY_NAME}" fail-makedb_count_statistics "Change-O MakeDb Failed Count Statistics" csv
    fi
    #addLogFile $APP_NAME log fail-makedb_count_statistics fail-makedb_count_statistics.csv "Change-O MakeDb Failed Count Statistics" "csv" null
    #addArchiveFile fail-makedb_count_statistics.csv
}

function run_assign_clones() {
    addCalculation "${ACTIVITY_NAME}" clonal_assignment

    # launcher job file
    if [ -f joblist-clones ]; then
        echo "Warning: removing file 'joblist-clones'.  That filename is reserved." 1>&2
        rm joblist-clones
        touch joblist-clones
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
            wasDerivedFrom "${alleleFile}.gz" "${file}.gz" "assigned_clones, allele_clones" "${fileOutname} Change-O IG Allele Clones" tsv
            wasDerivedFrom "${geneFile}.gz" "${file}.gz" "assigned_clones, gene_clones" "${fileOutname} Change-O IG Gene Clones" tsv
            #group="group${count}"
            #addOutputFile $group $APP_NAME igblast-makedb-allele-clone ${alleleFile}.gz "${fileOutname} Change-O IG Allele Clones" "tsv" $mfile
            #addOutputFile $group $APP_NAME igblast-makedb-gene-clone ${geneFile}.gz "${fileOutname} Change-O IG Gene Clones" "tsv" $mfile
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
            echo "apptainer exec -e ${repcalc_image} bash repcalc_clones.sh ${AIRRMetadata} ${germline_db_file} ${file} ${rep_id} ${processing_stage}" >> joblist-clones
            alleleFile=${out_prefix}.allele.clone.airr.tsv
            geneFile=${out_prefix}.gene.clone.airr.tsv

            # will get compressed at end
            wasDerivedFrom "${alleleFile}.gz" "${file}.gz" "assigned_clones, allele_clones" "${rep_id} RepCalc TCR Allele Clones (${processing_stage})" tsv
            wasDerivedFrom "${geneFile}.gz" "${file}.gz" "assigned_clones, gene_clones" "${rep_id} RepCalc TCR Gene Clones (${processing_stage})" tsv
            #group="group${count}"
            #addOutputFile $group $APP_NAME igblast-allele-clone ${alleleFile}.gz "${rep_id} RepCalc TCR Allele Clones (${processing_stage})" "tsv" $mfile
            #addOutputFile $group $APP_NAME igblast-gene-clone ${geneFile}.gz "${rep_id} RepCalc TCR Gene Clones (${processing_stage})" "tsv" $mfile
            gzipFile ${alleleFile}
            gzipFile ${geneFile}

            # RepCalc clones
            processing_stage=igblast.makedb
            #addProcessingStaqe $processing_stage
            out_prefix=${rep_id}.${processing_stage}
            file=${out_prefix}.airr.tsv
            echo "apptainer exec -e ${repcalc_image} bash repcalc_clones.sh ${AIRRMetadata} ${germline_db_file} ${file} ${rep_id} ${processing_stage}" >> joblist-clones
            alleleFile=${out_prefix}.allele.clone.airr.tsv
            geneFile=${out_prefix}.gene.clone.airr.tsv

            # will get compressed at end
            wasDerivedFrom "${alleleFile}.gz" "${file}.gz" "assigned_clones, allele_clones" "${rep_id} RepCalc TCR Allele Clones (${processing_stage})" tsv
            wasDerivedFrom "${geneFile}.gz" "${file}.gz" "assigned_clones, gene_clones" "${rep_id} RepCalc TCR Gene Clones (${processing_stage})" tsv
            #group="group${count}"
            #addOutputFile $group $APP_NAME igblast-makedb-allele-clone ${alleleFile}.gz "${rep_id} RepCalc TCR Allele Clones (${processing_stage})" "tsv" $mfile
            #addOutputFile $group $APP_NAME igblast-makedb-gene-clone ${geneFile}.gz "${rep_id} RepCalc TCR Gene Clones (${processing_stage})" "tsv" $mfile
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
        wasGeneratedBy "clone_report.csv" "${ACTIVITY_NAME}" clone_report "Clonal Assignment Summary Report" csv
        #addLogFile $APP_NAME log clone_report clone_report.csv "Clonal Assignment Summary Report" "csv" null
        #addArchiveFile clone_report.csv
    fi
}

function compress_and_archive() {
    # Provenance file
    wasGeneratedBy "provenance_output.json" "${ACTIVITY_NAME}" prov "Analysis Provenance" json

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
    wasGeneratedBy ${_tapisJobUUID}.zip "${ACTIVITY_NAME}" job_archive "Archive of Output Files" zip
    #addLogFile $APP_NAME log output_archive ${_tapisJobUUID}.zip "Archive of Output Files" "zip" null
    cp ${_tapisJobUUID}.zip output
}
