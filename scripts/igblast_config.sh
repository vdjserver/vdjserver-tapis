#!/bin/bash

configure_igblast()
{
    local locus="$1"
    local species="$2"
    local germline_db="$3"

    local args=""

    # Clear previous values
    local seqType=""
    IGBLAST_PARAMS=""

    ###########################################################################
    # Old database uses human/mouse organism names
    ###########################################################################

    if [[ "$germline_db" == "db.2019.01.23" ]]; then

        if [[ "$species" == "NCBITAXON:9606" ]]; then
            species="human"
        else
            species="mouse"
        fi
    else
        species="${species//:/_}"
        species="${species^^}"

    fi

    local organism="$species"
    local germline_set="$species"

    echo "ORGANISM: $organism"

    ###########################################################################
    # Locus-specific configuration
    ###########################################################################

    if [ "$locus" == "TR" ]; then
        seqType="TCR"

    elif [ "$locus" == "IG" ]; then
        seqType="Ig"

    else
        echo "ERROR: Invalid locus: $locus"
        echo "Expected TR or IG"
        exit 1
    fi

    ###########################################################################
    # IgBLAST sequence type
    ###########################################################################

    args="$args -ig_seqtype $seqType"

    ###########################################################################
    # Organism
    ###########################################################################

    if [ -n "$species" ]; then

        args="$args -organism $species"

        #######################################################################
        # Old database
        #######################################################################

        if [ "$germline_db" == "db.2019.01.23" ]; then
            args="$args -auxiliary_data $IGDATA/optional_file/${germline_set}_gl.aux"
            args="$args -germline_db_V $VDJ_DB_ROOT/${germline_set}/ReferenceDirectorySet/${germline_set}_${locus}_V.fna"
            args="$args -germline_db_D $VDJ_DB_ROOT/${germline_set}/ReferenceDirectorySet/${germline_set}_${locus}_D.fna"
            args="$args -germline_db_J $VDJ_DB_ROOT/${germline_set}/ReferenceDirectorySet/${germline_set}_${locus}_J.fna"

        #######################################################################
        # New database
        #######################################################################

        else
            args="$args -germline_db_V $VDJ_DB_ROOT/${germline_set}/ReferenceDirectorySet/${germline_set}_V"
            args="$args -germline_db_D $VDJ_DB_ROOT/${germline_set}/ReferenceDirectorySet/${germline_set}_D"
            args="$args -germline_db_J $VDJ_DB_ROOT/${germline_set}/ReferenceDirectorySet/${germline_set}_J"
            # C region
            if [ "$species" == "NCBITAXON_9606" ] && [ "$locus" == "IG" ]; then
                args="$args -c_region_db $VDJ_DB_ROOT/${germline_set}/ReferenceDirectorySet/${germline_set}_C"
            fi
            # Auxiliary data
            args="$args -auxiliary_data $VDJ_DB_ROOT/${germline_set}/ReferenceDirectorySet/${germline_set}.aux"
            # Custom internal data
            args="$args -custom_internal_data $VDJ_DB_ROOT/${germline_set}/ReferenceDirectorySet/${germline_set}.ndm"
        fi
    fi

    # Domain system need to double check if we need the if. Where is this input coming from?
    args="$args -domain_system imgt"
    # Export final parameters
    IGBLAST_PARAMS="$args"

    return 0
}