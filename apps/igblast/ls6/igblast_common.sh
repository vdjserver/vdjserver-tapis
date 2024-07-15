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

# IgBlast germline database and extra files
VDJ_DB_VERSION=db.2019.01.23
IGDATA="$WORK/../common/igblast-db/$VDJ_DB_VERSION"
VDJ_DB_URI=http://wiki.vdjserver.org/vdjserver/index.php/VDJServer_IgBlast_Database
export IGDATA
export VDJ_DB_ROOT="$IGDATA/germline/"
germline_db="$VDJ_DB_ROOT/$species/vdjserver_germline.airr.json"

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
    echo "ProjectDirectory=${ProjectDirectory}"
    echo "JobFiles=${JobFiles}"
    echo "query=$query"
    echo ""
    echo "Application parameters:"
    echo "SecondaryInputsFlag=${SecondaryInputsFlag}"
    echo "QueryFilesMetadata=$QueryFilesMetadata"
    echo "species=$species"
    echo "strain=$strain"
    echo "ig_seqtype=$ig_seqtype"
    echo "domain_system=$domain_system"
    echo "ClonalTool=$ClonalTool"
}

function run_igblast_workflow() {
    addCalculation vdj_alignment
    addCalculation parse_igblast

    # Exclude input files from archive
    #noArchive "${ProjectDirectory}"
    for file in $JobFiles; do
        if [ -f $file ]; then
            expandfile $file
            #noArchive $file
            #noArchive "${file%.*}"
        fi
    done

    # launcher job file
    if [ -f joblist ]; then
        echo "Warning: removing file 'joblist'.  That filename is reserved." 1>&2
        rm joblist
    fi
    touch joblist
    #echo "joblist" >> .agave.archive

    if [ -f joblist-post-process ]; then
        echo "Warning: removing file 'joblist-post-process'.  That filename is reserved." 1>&2
        rm joblist-post-process
    fi
    touch joblist-post-process
    #echo "joblist-post-process" >> .agave.archive

    filelist=()
    count=0
    for file in $query; do
        # unique group name to put in metadata
        group="group${count}"
        addGroup $group file

        fileOutname="${file##*/}" # test/file -> file
        addOutputFile $group $APP_NAME assignment_sequence "$file" "Input Sequences ($fileOutname)" "read" null

        expandfile $file
        #echo $file >> .agave.archive
        fileExtension="${file##*.}" # file.fastq -> fastq
        fileBasename="${file%.*}" # file.fastq -> file

        if [[ "$fileExtension" == "fastq" ]] || [[ "$fileExtension" == "fq" ]]; then
            ${PYTHON} fastq2fasta.py -i $file -o $fileBasename.fasta
            file="$fileBasename.fasta"
            #echo $file >> .agave.archive
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
            #echo $smallFile >> .agave.archive
            #echo ${smallFile}.igblast.txt >> .agave.archive

            # These come from Agave, but I need to assign them inside the loop.
            organism=${species}
            germline_set=${species}
            if [ "$species" == "macaque" ]; then
                organism="rhesus_monkey"
                strain="indian"
                germline_set="macaque_indian"
            fi
            seqType=${ig_seqtype}
            QUERY_ARGS=""
            ARGS=""
            MDARGS=""
            if [ -f $smallFile ]; then 
                QUERY_ARGS="-query $smallFile" 
                MDARGS="$MDARGS $smallFile"
                MDARGS="$MDARGS $PWD/${smallFile}.igblast.txt"
            fi
            if [ -n $seqType ]; then 
                ARGS="$ARGS -ig_seqtype $seqType"
                if [ "$seqType" == "TCR" ]; then seqType="TR"; fi  
                if [ "$seqType" == "Ig" ]; then seqType="IG"; fi  
                MDARGS="$MDARGS $seqType"
            fi
            if [ -n $organism ]; then 
                ARGS="$ARGS -organism $organism"
                ARGS="$ARGS -auxiliary_data $IGDATA/optional_file/${germline_set}_gl.aux"
                ARGS="$ARGS -germline_db_V $VDJ_DB_ROOT/${germline_set}/ReferenceDirectorySet/${germline_set}_${seqType}_V.fna"
                ARGS="$ARGS -germline_db_D $VDJ_DB_ROOT/${germline_set}/ReferenceDirectorySet/${germline_set}_${seqType}_D.fna"
                ARGS="$ARGS -germline_db_J $VDJ_DB_ROOT/${germline_set}/ReferenceDirectorySet/${germline_set}_${seqType}_J.fna"
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
    seqMetadata=($QueryFilesMetadata)
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

        # process pRESTO annotations
        apptainer exec -e ${repcalc_image} bash do_annotations.sh ${fileOutname}
        #$PYTHON presto_annotations.py ${fileOutname}.igblast.airr.new.tsv ${fileOutname}.igblast.airr.tsv
        rm -f ${fileOutname}.igblast.airr.new.tsv

        # assign repertoire IDs
        mv ${fileOutname}.igblast.airr.tsv ${fileOutname}.igblast.orig.airr.tsv
        $PYTHON assign_repertoire_id.py ${fileOutname} ${_tapisJobUUID} ${fileOutname}.igblast.orig.airr.tsv ${fileOutname}.igblast.airr.tsv
        mv ${fileOutname}.igblast.makedb.airr.tsv ${fileOutname}.igblast.makedb.orig.airr.tsv
        $PYTHON assign_repertoire_id.py ${fileOutname} ${_tapisJobUUID} ${fileOutname}.igblast.makedb.orig.airr.tsv ${fileOutname}.igblast.makedb.airr.tsv

        # add to process metadata
        # they will be compressed later
        group="group${count}"
        addOutputFile $group $APP_NAME airr ${fileOutname}.igblast.airr.tsv.gz "${fileOutname} AIRR TSV" "tsv" $mfile
        if [ "$species" != "macaque" ]; then
            addOutputFile $group $APP_NAME airr-makedb ${fileOutname}.igblast.makedb.airr.tsv.gz "${fileOutname} Change-O MakeDb AIRR TSV" "tsv" $mfile
            if [ -f ${fileOutname}.igblast.fail-makedb.airr.tsv ]; then
                addOutputFile $group $APP_NAME airr-fail-makedb ${fileOutname}.igblast.fail-makedb.airr.tsv.gz "${fileOutname} Change-O MakeDb Failed" "tsv" $mfile
            fi
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
    metadata_file="study_metadata.airr.json"
    repertoire_ids=""
    for file in ${filelist[@]}; do
        fileBasename="${file%.*}" # test/file.fasta -> test/file
        fileOutname="${fileBasename##*/}" # test/file -> file
        repertoire_ids="${repertoire_ids} ${fileOutname}"
    done
    $PYTHON create_airr_metadata.py $metadata_file ${_tapisJobUUID} $repertoire_ids

    # Assign Clones
    cloneFileList=()
    count=0
    if [[ "$ClonalTool" == "changeo" ]] ; then
        fileMetadataList=($QueryFilesMetadata)
        for file in ${filelist[@]}; do
            mfile=${fileMetadataList[count]}
            fileBasename="${file%.*}" # test/file.fasta -> test/file
            fileOutname="${fileBasename##*/}" # test/file -> file
            file=${fileOutname}.igblast.makedb.airr.tsv

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

            count=$(( $count + 1 ))
        done
    fi

    if [[ "$ClonalTool" == "repcalc" ]] ; then
        fileMetadataList=($QueryFilesMetadata)
        for file in ${filelist[@]}; do
            mfile=${fileMetadataList[count]}
            fileBasename="${file%.*}" # test/file.fasta -> test/file
            rep_id="${fileBasename##*/}" # test/file -> file

            # We have the raw IgBlast AIRR TSV and the MakeDB processed AIRR TSV

            # RepCalc clones
            processing_stage=igblast
            #addProcessingStaqe $processing_stage
            out_prefix=${rep_id}.${processing_stage}
            file=${out_prefix}.airr.tsv
            echo "apptainer exec -e ${repcalc_image} bash repcalc_clones.sh ${metadata_file} ${germline_db} ${file} ${rep_id} ${processing_stage}" >> joblist-clones
            result_file=${out_prefix}.allele.clone.airr.tsv

            # will get compressed at end
            group="group${count}"
            addOutputFile $group $APP_NAME igblast-allele-clone ${result_file}.gz "${rep_id} RepCalc TCR Clones (${processing_stage})" "tsv" $mfile

            # RepCalc clones
            processing_stage=igblast.makedb
            #addProcessingStaqe $processing_stage
            out_prefix=${rep_id}.${processing_stage}
            file=${out_prefix}.airr.tsv
            echo "apptainer exec -e ${repcalc_image} bash repcalc_clones.sh ${metadata_file} ${germline_db} ${file} ${rep_id} ${processing_stage}" >> joblist-clones
            result_file=${out_prefix}.allele.clone.airr.tsv

            # will get compressed at end
            group="group${count}"
            addOutputFile $group $APP_NAME igblast-makedb-allele-clone ${result_file}.gz "${rep_id} RepCalc TCR Clones (${processing_stage})" "tsv" $mfile

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
    # compress the tsv files
    echo Compressing output files
    for file in ${filelist[@]}; do
        fileBasename="${file%.*}"
        fileOutname="${fileBasename##*/}"
        gzip ${fileOutname}.igblast.airr.tsv
        if [ "$species" != "macaque" ]; then
            gzip ${fileOutname}.igblast.makedb.airr.tsv
            if [ -f ${fileOutname}.igblast.fail-makedb.airr.tsv ]; then
                gzip ${fileOutname}.igblast.fail-makedb.airr.tsv
            fi
        fi
        if [ -f ${fileOutname}.igblast.makedb.gene.clone.airr.tsv ]; then
            gzip ${fileOutname}.igblast.makedb.gene.clone.airr.tsv
        fi
        if [ -f ${fileOutname}.igblast.makedb.allele.clone.airr.tsv ]; then
            gzip ${fileOutname}.igblast.makedb.allele.clone.airr.tsv
        fi
        if [ -f ${fileOutname}.igblast.allele.clone.airr.tsv ]; then
            gzip ${fileOutname}.igblast.allele.clone.airr.tsv
        fi
    done

    # zip archive of all output files
    for file in $ARCHIVE_FILE_LIST; do
        if [ -f $file ]; then
            cp -f $file ${_tapisJobUUID}
        fi
    done
    zip ${_tapisJobUUID}.zip ${_tapisJobUUID}/*
    addLogFile $APP_NAME log output_archive ${_tapisJobUUID}.zip "Archive of Output Files" "zip" null
}
