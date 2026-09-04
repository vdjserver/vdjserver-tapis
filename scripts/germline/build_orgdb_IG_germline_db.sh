#!/bin/bash
set -euo pipefail



download_set() {

    local locus="$1"
    local set_name="$2"
    local file_prefix="$3"
    local json_prefix="$4"

    if [[ "$set_name" == "NA" ]]; then
        echo "WARNING: No $locus set available for $strain. Skipping."
        return 0
    fi

    echo "Downloading $species $set_name..."

    cd "$germline_dir" || return 1

    download_germline_set "$species" "$locus" -n "$set_name" -f MULTI-IGBLAST -p "${file_prefix}_"

    cd ../ || return 1

    download_germline_set "$species" "$locus" -n "$set_name" -f AIRRC-JSON -p "$json_prefix"
}

combine_fasta_files() {

    local segment="$1"
    local output_file="$2"
    local pattern="$3"

    echo "Combining $segment FASTA files..."
    echo "Output: $output_file"

    local found=false

    > "$output_file"

    for src_fasta in $pattern; do
        if [[ -f "$src_fasta" ]]; then
            echo "Adding $src_fasta to $output_file"
            cat "$src_fasta" >> "$output_file"
            found=true
        fi
    done

    if [[ "$found" == false ]]; then
        echo "WARNING: No $segment FASTA files found. Skipping."
        rm -f "$output_file"
    fi

}

build_vdj_fasta() {

    local vdj_file="${germline_dir}/IG_VDJ.fna"

    > "$vdj_file"

    for segment in V D J; do
        if [[ "$segment" == "V" ]]; then
            src_fasta="${germline_dir}/${strain_id}_IG_V_gapped.fna"
        
        else
            src_fasta="${germline_dir}/${strain_id}_IG_${segment}.fna"
        fi

        if [[ -f "$src_fasta" ]]; then
            echo "Adding:"
            echo "  $src_fasta"
            cat "$src_fasta" >> "$vdj_file"

        else
            echo "WARNING: $src_fasta not found."
            echo "Skipping $segment."
        fi
    done
    
    if [[ ! -s "$vdj_file" ]]; then

        echo
        echo "ERROR: IG_VDJ.fna is empty."
        exit 1

    fi

    echo
    echo "Created:"
    echo "  $vdj_file"
}

merge_igblast_files() {

    local ext="$1"
    local combined_file="${germline_dir}/${strain_id}_IG.${ext}"
    local found_any=false

    echo "Merging .$ext files..."
    > "$combined_file"

    for src_file in "${germline_dir}/${strain_short}_"*".${ext}"; do

        if [[ -f "$src_file" ]]; then
            found_any=true

            echo "Adding:"
            echo "  $src_file"

            if [[ ! -s "$combined_file" ]]; then
                # First file: include header
                cat "$src_file" >> "$combined_file"
            else
                # Additional files: skip header
                tail -n +2 "$src_file" >> "$combined_file"
            fi
        fi

    done

    if [[ "$found_any" == false ]]; then
        echo "WARNING: No .$ext files found."
        rm -f "$combined_file"
        return 0
    fi

    echo "Created:"
    echo "  $combined_file"
}


build_blast_databases() {

    for segment in V D J; do
        local combined_file="${germline_dir}/${strain_id}_IG_${segment}.fna"
        local outbase="${germline_dir}/${strain_id}_IG_${segment}"

        if [[ -f "$combined_file" && -s "$combined_file" ]]; then

            echo
            echo "Building BLAST database:"
            echo "  Input : $combined_file"
            echo "  Output: $outbase"

            if ! makeblastdb -parse_seqids -dbtype nucl -in "$combined_file" -out "$outbase"
            then
                echo "ERROR: Failed to build BLAST database for IG $segment."
                return 1
            fi

        else

            echo
            echo "Skipping IG $segment:"
            echo "  File not found or empty:"
            echo "  $combined_file"

        fi
    done
}

# Set the variables
db_date="${DB_DATE:-$(date +%Y.%m.%d)}"

database_root="/data/db.${db_date}"

map_file="germline_map.tsv"
# Remove any special \r character
sed -i 's/\r$//' "$map_file"


#  INSTALL receptor-utils
echo "----------------- Installing receptor-utils -----------------"

pip install --quiet receptor-utils

echo "----------------- receptor-utils installation complete -----------------"
echo


count=0
while IFS=$'\t' read -r \
    species_id \
    strain_id \
    species \
    strain \
    igkv_set \
    iglv_set \
    igh_set \
    ighc_set \
    igkj_set \
    iglj_set \
    update_allele || [[ -n "$species_id" ]]
do
    # skip header
    [[ "$species_id" == "species_id" ]] && continue

    echo ""
    echo "========================================================================================================================"
    echo "Processing: $species - $strain"
    echo "$species_id $strain_id $species $strain $igkv_set $iglv_set $igh_set $ighc_set $igkj_set $iglj_set $update_allele"
    echo "========================================================================================================================"

    # Directory setup
    # species_dir="${database_root}/germline/${species_id}" # turn this on if you want species id

    species_dir="${database_root}/germline/" #Using strain id as species id
    strain_dir="${species_dir}/${strain_id}"
    germline_dir="${strain_dir}/ReferenceDirectorySet"

    mkdir -p "$germline_dir"

    count=$(( $count + 1 ))
    echo "Database count: $count"
    

    # Short names not using for now
    if [[ "$species" == "Homo sapiens" ]]; then
        species_short="human"
    elif [[ "$species" == "Mus musculus" ]]; then
        species_short="mouse"
    else
        echo "WARNING: Unknown species: $species"
        continue
    fi

    strain_short="${strain//\//_}"
    strain_short="${strain_short// /_}"

    echo "Directory: $germline_dir"

    echo "======================================================================================"
    echo "                          Downloading germlines for $species -  $strain "
    echo "======================================================================================"

    echo
    echo "----------------------------------------------------------------------------------"
    echo "                                        IGH"
    echo "----------------------------------------------------------------------------------"


    download_set "IGH" "$igh_set" "${strain_short}_IGH" "vdjserver_${strain_short}_IGH_germline.airr"
    # IGHC -- still uses IGH locus for human
    download_set "IGH" "$ighc_set" "${strain_short}_IGH_C" "vdjserver_${strain_short}_IGH_C_germline.airr"


    # There is no D segment for IGK and IGL.
    echo
    echo "----------------------------------------------------------------------------------"
    echo "                                        IGK"
    echo "----------------------------------------------------------------------------------"

    download_set "IGK" "$igkv_set" "${strain_short}_IGK_V" "vdjserver_${strain_short}_IGK_V_germline.airr"
    # IGK J
    download_set "IGK" "$igkj_set" "${strain_short}_IGK_J" "vdjserver_${strain_short}_IGK_J_germline.airr"

    echo
    echo "----------------------------------------------------------------------------------"
    echo "                                        IGL"
    echo "----------------------------------------------------------------------------------"

    download_set "IGL" "$iglv_set" "${strain_short}_IGL_V" "vdjserver_${strain_short}_IGL_V_germline.airr"
    # IGL J
    download_set "IGL" "$iglj_set" "${strain_short}_IGL_J" "vdjserver_${strain_short}_IGL_J_germline.airr"

    echo "----------------- Downloaded germline files --------------------------------------"

    find "$strain_dir" -maxdepth 2 -type f | sort

    echo
    echo "======================================================================================"
    echo "                          COMBINING AIRR JSON FILES AND RENAMING"
    echo "======================================================================================"

    cd /data
    python combine_airr_json.py  --mergeAirrJson "$strain_short" "$strain_dir"

    # Rename/copy final combined AIRR JSON

    combined_airr="${strain_dir}/vdjserver_${strain_short}_germline.airr.json"
    final_airr="${strain_dir}/vdjserver_germline.airr.json"

    cp "${combined_airr}" "${final_airr}" 

    # python combine_airr_json.py --CheckCGene "$germline_dir" # Need to figure out about mismatched gene names

    echo
    echo "======================================================================================"
    echo "                          COMBINE FASTA FILES ACROSS LOCI AND GAPPED V FILES"
    echo "======================================================================================"

    for segment in V D J; do
        combined_file="${germline_dir}/${strain_id}_IG_${segment}.fna"
        pattern="${germline_dir}/${strain_short}_"*"_${segment}.fasta"

        combine_fasta_files "$segment" "$combined_file" "$pattern"
    
    done
    echo "All loci for each segment have been merged into a single IG locus — complete!"

    v_gapped_combined="${germline_dir}/${strain_id}_IG_V_gapped.fna"
    pattern="${germline_dir}/${strain_short}_"*"_V_gapped.fasta"

    combine_fasta_files "gapped V" "$v_gapped_combined" "$pattern"

    echo "V-gapped files have been merged — complete!"

    echo
    echo "======================================================================================"
    echo "                          BUILDING IG_VDJ.fna"
    echo "======================================================================================"

    build_vdj_fasta || exit 1


    echo
    echo "======================================================================================"
    echo "                          MERGING AUX AND NDM FILES"
    echo "======================================================================================"
    echo

    merge_igblast_files "aux"
    merge_igblast_files "ndm"

    echo

    echo
    echo "======================================================================================"
    echo "                          CHECKING ALLELE EXISTENCE AND UPDATE"
    echo "======================================================================================"

    python combine_airr_json.py  --geneExistence "$strain_dir"

    if [[ "$update_allele" == "Y" ]]; then
        echo "----------------------------------------------------------------------------------"
        echo "          Updating Allele description for $strain"
        echo "----------------------------------------------------------------------------------"
        python combine_airr_json.py  --updateAirrAlleleLabels "$strain_dir"

        echo
        echo "Recheck gene existence after update"
        echo
        
        python combine_airr_json.py  --geneExistence "$strain_dir"
    fi
    
    echo
    echo "======================================================================================"
    echo "                          BUILDING BLAST DATABASES"
    echo "======================================================================================"

    build_blast_databases || exit 1

done < "$map_file"

echo
echo "======================================================================================"
echo "                          CREATING ARCHIVE"
echo "======================================================================================"


base_dir="$(basename "$database_root")"
parent_dir="$(dirname "$database_root")"
archive_path="${database_root}.tgz"

tar -czf "$archive_path"  -C "$parent_dir" "$base_dir"

echo
echo "Archive created:"
echo "  $archive_path"

echo
echo "======================================================================================"
echo "                          DATABASE BUILD COMPLETE"
echo "======================================================================================"
echo
echo "Database      : $database_root"
echo "Archive       : $archive_path"
echo
echo "======================================================================================"