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
    echo "locus=$locus"
    echo "germline_db=$germline_db"
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

    # we parallelize by splitting the input files into smaller files
    # and using launcher to run igblast jobs
    filelist=()
    count=0
    repertoires=""
    for file in $query; do
        query_file=$file
        rep_id=$(getRepertoireForFile $file)
        # TODO: check error
        repertoires="${repertoires} ${rep_id}"

        fileOutname="${file##*/}" # test/file -> file

        expandfile $file
        fileExtension="${file##*.}" # file.fastq -> fastq
        fileBasename="${file%.*}" # file.fastq -> file

        if [[ "$fileExtension" == "fastq" ]] || [[ "$fileExtension" == "fq" ]]; then
            ${PYTHON} fastq2fasta.py -i $file -o $fileBasename.fasta
            file="$fileBasename.fasta"
        fi

        # save expanded filenames for later merging
        filelist[${#filelist[@]}]=$file


        #DEBUG Message
        echo "file = $file"
        echo "fileBasename = $fileBasename"
        echo "READS_PER_FILE = $READS_PER_FILE"
        echo "Python = $PYTHON"
        ls -lh "$file"

        ## Add file splitting back
        if [ "$(grep -c '^>' "$file")" -gt "$READS_PER_FILE" ]; then
            #removing if there is any old files left
            rm -f "${fileBasename}_p"*.fasta

            echo "Splitting $file into chunks of $READS_PER_FILE records"

            ${PYTHON} splitfasta.py -f "$file" -r "$READS_PER_FILE" -o "." -s "${fileBasename}_p"

            smallFiles="$(ls ${fileBasename}_p*.fasta)"

            if [ $? -ne 0 ]; then
                echo "ERROR: splitfasta.py failed for $file" >&2
                exit 1
            fi
            echo "Generated small files:"
            printf '  %s\n' "${smallFiles[@]}"
        else
            smallFiles="$file"
        fi
        
        for smallFile in $smallFiles; do
            # These come from Agave, but I need to assign them inside the loop.
            # TODO: get these from repertoire metadata
            
            # if [[ "$species" == "NCBITAXON_9606" || "$species" == "human" ]]; then
            #     organism="human"
            # else
            #     organism="mouse"
            # fi

            # echo "Species: $species"
            # echo "IgBLAST organism: $organism"
            ## Change organism to human or mouse becuase of internal_data stucture
            organism=${species}
            germline_set=${species}

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
                if [ "$germline_db" == "db.2019.01.23" ]; then
                    # old germline
                    ARGS="$ARGS -auxiliary_data $IGDATA/optional_file/${germline_set}_gl.aux"
                    ARGS="$ARGS -germline_db_V $VDJ_DB_ROOT/${germline_set}/ReferenceDirectorySet/${germline_set}_${locus}_V.fna"
                    ARGS="$ARGS -germline_db_D $VDJ_DB_ROOT/${germline_set}/ReferenceDirectorySet/${germline_set}_${locus}_D.fna"
                    ARGS="$ARGS -germline_db_J $VDJ_DB_ROOT/${germline_set}/ReferenceDirectorySet/${germline_set}_${locus}_J.fna"
                else
                    # newer OGRDB-based germlines conform to standard directory structure and file names
                    ARGS="$ARGS -germline_db_V $VDJ_DB_ROOT/${germline_set}/ReferenceDirectorySet/${germline_set}_V"
                    ARGS="$ARGS -germline_db_D $VDJ_DB_ROOT/${germline_set}/ReferenceDirectorySet/${germline_set}_D"
                    ARGS="$ARGS -germline_db_J $VDJ_DB_ROOT/${germline_set}/ReferenceDirectorySet/${germline_set}_J"
                    # currently only human has C genes
                    if [[ "$species" == "NCBITAXON_9606" ]]; then
                        ARGS="$ARGS -c_region_db  $VDJ_DB_ROOT/${germline_set}/ReferenceDirectorySet/${germline_set}_C"
                    fi
                    ARGS="$ARGS -auxiliary_data  $VDJ_DB_ROOT/${germline_set}/ReferenceDirectorySet/${germline_set}.aux"
                    ARGS="$ARGS -custom_internal_data $VDJ_DB_ROOT/${germline_set}/ReferenceDirectorySet/${germline_set}.ndm"
                fi
                # MDARGS="$MDARGS $organism"
                # changing it to have species there.
                MDARGS="$MDARGS $organism"

            fi
            if [ -n $domain_system ]; then ARGS="$ARGS -domain_system $domain_system"; fi

            IGBLAST_PARAMS="$ARGS"

            # igblast job with AIRR output
            AIRR_ARGS="$QUERY_ARGS $ARGS -outfmt 19"
            echo "export IGDATA=\"$IGDATA\" && $IGBLASTN_EXE $AIRR_ARGS > ${smallFile}.igblast.airr.tsv" >> joblist

            # igblast job with ChangeO output
            CO_ARGS="$QUERY_ARGS $ARGS -outfmt "
            OUTFMT="7 qseqid qgi qacc qaccver qlen sseqid sallseqid sgi sallgi sacc saccver sallacc slen qstart qend sstart send qseq sseq evalue bitscore score length pident nident mismatch positive gapopen gaps ppos frames qframe sframe btop"
            echo "export IGDATA=\"$IGDATA\" && export VDJ_DB_ROOT=\"$VDJ_DB_ROOT\" && $IGBLASTN_EXE $CO_ARGS \"$OUTFMT\" > ${smallFile}.igblast.txt" >> joblist

            # the post processing jobs
            echo "export IGDATA=\"$IGDATA\" && export VDJ_DB_ROOT=\"$VDJ_DB_ROOT\" && apptainer exec ${repcalc_image} bash ./do_airr_makedb.sh $MDARGS" >> joblist-post-process
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
    query_files=($query)
    count=0
    for file in ${filelist[@]}; do
        mfile=${seqMetadata[count]}
        query_file=${query_files[count]}

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
            mv ${file}.igblast.makedb.airr.tsv ${fileOutname}.igblast.makedb.airr.tsv # Do we need this line? Old code had it only if if [ "$species" != "macaque" ]
        fi

        # provenance for sequences that fail MakeDB
        # we do not merge into repertoire_id file to make it easier to map sequences to original sample file
        if [ -f "${file}.igblast.fail-makedb.airr.tsv" ]; then
            mv ${file}.igblast.fail-makedb.airr.tsv ${fileOutname}.igblast.fail-makedb.airr.tsv
            wasDerivedFrom "${fileOutname}.igblast.fail-makedb.airr.tsv" "${query_file}" "airr-fail-makedb" "Change-O MakeDb Failed" tsv
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

    # ----------------------------------------------------------------------------

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

        # compress the AIRR TSV
        gzipFile ${mfile}.igblast.airr.tsv
        if [ "$species" != "macaque" ]; then
            gzipFile ${mfile}.igblast.makedb.airr.tsv
        fi
        count=$(( $count + 1 ))
    done

    #add provenance here.
    count=0
    for file in $query; do
        mfile=${seqMetadata[count]}

        wasDerivedFrom "${mfile}.igblast.airr.tsv.gz" "${file}" "vdj_sequence_annotation" "IgBlast AIRR TSV" tsv
        wasDerivedFrom "${mfile}.igblast.makedb.airr.tsv.gz" "${file}" "makedb_parse,vdj_sequence_annotation" "Change-O MakeDb AIRR TSV" tsv

        count=$(( $count + 1 ))
    done

    # ----------------------------------------------------------------------------
    # generate count statistics

    echo Generating count statistics

    $PYTHON count_statistics.py *.igblast.airr.tsv
    mv count_statistics.csv igblast_count_statistics.csv
    wasGeneratedBy "igblast_count_statistics.csv" "${ACTIVITY_NAME}" igblast_count_statistics "IgBlast AIRR TSV Count Statistics" csv

    $PYTHON count_statistics.py *.makedb.airr.tsv
    mv count_statistics.csv makedb_count_statistics.csv
    wasGeneratedBy "makedb_count_statistics.csv" "${ACTIVITY_NAME}" makedb_count_statistics "Change-O MakeDb AIRR TSV Count Statistics" csv

    has_fail_makedb=0
    if ls *.fail-makedb.airr.tsv 1> /dev/null 2>&1; then
        has_fail_makedb=1
    fi
    if [[ $has_fail_makedb -eq 1 ]]; then
        $PYTHON count_statistics.py *.fail-makedb.airr.tsv
        mv count_statistics.csv fail-makedb_count_statistics.csv
        wasGeneratedBy "fail-makedb_count_statistics.csv" "${ACTIVITY_NAME}" fail-makedb_count_statistics "Change-O MakeDb Failed Count Statistics" csv
    fi
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
        for mfile in ${fileMetadataList[@]}; do
            file=${mfile}.igblast.makedb.airr.tsv

            # Assuming airr.tsv extension
            fileOutname="${file%.*}" # file.airr.tsv -> file.airr
            fileOutname="${fileOutname%.*}" # file.airr -> file
            fileOutname="${fileOutname##*/}" # foo/bar/file -> file
            #noArchive $fileOutname

            # Change-O clones
            echo "apptainer exec -e ${repcalc_image} bash changeo_clones.sh ${file} ${fileOutname} 4" >> joblist-clones

            # save filenames for later processing
            alleleFile="${fileOutname}.allele.clone.airr.tsv"
            cloneFileList[${#cloneFileList[@]}]=$alleleFile
            geneFile="${fileOutname}.gene.clone.airr.tsv"
            cloneFileList[${#cloneFileList[@]}]=$geneFile

            # will get compressed at end
            wasDerivedFrom "${alleleFile}.gz" "${file}.gz" "assigned_clones, allele_clones" "${fileOutname} Change-O IG Allele Clones" tsv
            wasDerivedFrom "${geneFile}.gz" "${file}.gz" "assigned_clones, gene_clones" "${fileOutname} Change-O IG Gene Clones" tsv

            gzipFile ${alleleFile}
            gzipFile ${geneFile}

            count=$(( $count + 1 ))
        done
    fi

    if [[ "$ClonalTool" == "repcalc" ]] ; then
        fileMetadataList=($repertoires)
        for file in ${fileMetadataList[@]}; do
            rep_id=$file

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
    fi
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
    cp -f ${germline_db_file} ${_tapisJobUUID}
    zip ${_tapisJobUUID}.zip ${_tapisJobUUID}/*
    
    cp ${_tapisJobUUID}.zip output
    
}
