#!/bin/bash
set -e

declare -A species_map=(
    ["Homo sapiens"]="human"
    ["Mus musculus"]="mouse"
    # add more species mappings as needed but currently only 2 available
)

species="Homo sapiens"
# species="Mus musculus"

# Map full species name to short name (fallback to lowercase underscored)
species_short="${species_map[$species]}"

if [[ -z "$species_short" ]]; then
    # Fallback: lowercase + underscores
    species_short=$(echo "$species" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')
fi

# Set variables for database name, loci and segments
database_root="/data/db.2026.01.12"
loci=("IGH" "IGK" "IGL")
segments=("V" "D" "J" "C")
# segments=("V" "D" "J")


# Set Paths
germline_dir="${database_root}/germline/${species_short}/ReferenceDirectorySet"
mkdir -p "$germline_dir"


# Install this package for data download.
pip install --quiet receptor-utils
# pip install git+https://github.com/williamdlees/receptor_utils.git

# Download the germline data from orgdb
for locus in "${loci[@]}"; do
    echo "Downloading $species $locus into $germline_dir..."
    cd "$germline_dir"
    if [[ $locus == "IGH" ]]; then
        # Download C genes first otherwise it overrides the aux and ndm file for IGH
        download_germline_set "$species" "$locus" -n IGHC -f MULTI-IGBLAST -p "${species_short}_${locus}_"
        download_germline_set "$species" "$locus" -n IGH_VDJ -f MULTI-IGBLAST -p "${species_short}_${locus}_"
        
        #download the json file
        download_germline_set "$species" "$locus" -n IGH_VDJ -f AIRRC-JSON -p "${species_short}_${locus}_VDJ_vdjserver_germline.airr"
        download_germline_set "$species" "$locus" -n IGHC -f AIRRC-JSON -p "${species_short}_${locus}C_vdjserver_germline.airr"
    else
        download_germline_set "$species" "$locus" -f MULTI-IGBLAST -p "${species_short}_${locus}_"
        download_germline_set "$species" "$locus" -f AIRRC-JSON -p "${species_short}_${locus}_vdjserver_germline.airr"
    fi
done

echo "Germline dataset download — complete!"
cd /data
# Combine All downloaded AIRR JSON files into one
echo "Combine all germline JSON files into a single file and put them up a directory!"
airr_json_dir="${database_root}/germline/${species_short}"
python combine_airr_json.py --mergeAirrJson "$species_short" "$airr_json_dir"

echo "Removing all json files from germline directory."
rm "${germline_dir}/"*_germline.airr.json

#Remove _SC alleles as they do not appear in the airr json file yet.
echo "Remove All _SC alleles from ${species_short}_IGH_C.fna!"
python combine_airr_json.py --removeSCGgenes "$species_short" "$germline_dir"
#rename the updated file to the old file
mv -f "${germline_dir}/${species_short}_IGH_C_updated.fasta" "${germline_dir}/${species_short}_IGH_C.fasta"
# Combine downloaded fasta files for each segment (V, D, J) across loci into one .fna file in the same directory

for segment in "${segments[@]}"; do
    combined_file="${germline_dir}/${species_short}_IG_${segment}.fna"
    > "$combined_file"  # create or empty the combined file
    for locus in "${loci[@]}"; do
        src_fasta="${germline_dir}/${species_short}_${locus}_${segment}.fasta"

        if [[ -f "$src_fasta" ]]; then
            echo "Adding $src_fasta to $combined_file"
            cat "$src_fasta" >> "$combined_file"
        else
            echo "Warning: $src_fasta not found, skipping."
        fi
    done
done

echo "All loci for each segment have been merged into a single IG locus — complete!"

# Combine IG gapped files together
v_gapped_combined="${germline_dir}/${species_short}_IG_V_gapped.fna"
> "$v_gapped_combined"  # create or empty the combined file
for locus in "${loci[@]}"; do
    src_fasta="${germline_dir}/${species_short}_${locus}_V_gapped.fasta"
    if [[ -f "$src_fasta" ]]; then
        echo "Adding $src_fasta to $v_gapped_combined"
        cat "$src_fasta" >> "$v_gapped_combined"
    else
        echo "ERROR: $src_fasta not found for v gapped merge, skipping."
    fi
done
echo "Gapped V segments are merging complete!"

## Create VDJ and C files here as C is added later. Not changing the file name though.
# segments=("V" "D" "J")

# Build IG_VDJ.fna. Combine fna files to create IG_VDJ.fna with gapped files. Combine IG_V_Gapped with others D and J.
vdj_file="${germline_dir}/IG_VDJ.fna"
> "$vdj_file"  # create or empty the combined file
for segment in "${segments[@]}"; do
    if [[ "$segment" == "V" ]]; then
        src_fasta="${germline_dir}/${species_short}_IG_${segment}_gapped.fna"
    else
        src_fasta="${germline_dir}/${species_short}_IG_${segment}.fna"
    fi
    if [[ -f "$src_fasta" ]]; then
        echo "Adding $src_fasta to $vdj_file"
        cat "$src_fasta" >> "$vdj_file"
    else
        echo "ERROR: $src_fasta not found creating IG_VDJ.fna, skipping."
    fi
done
echo "IG_VDJ.fna creation complete!"

# Final check on IG_VDJ.fna and vs vdjserver_germline.airr.json for inconsistencies
echo "CHECK Allele existenece between IG_VDJ and AIRR json file!"
airr_json_dir="${database_root}/germline/${species_short}"
python combine_airr_json.py --geneExistence "$airr_json_dir" 

# Merge .aux and .ndm files across loci
combined_base="${germline_dir}/${species_short}_IG"
for ext in aux ndm; do
    combined_file="${combined_base}.${ext}"
    > "$combined_file"  # create or empty file

    for locus in "${loci[@]}"; do
        src_file="${germline_dir}/${species_short}_${locus}.${ext}"

        if [[ -f "$src_file" ]]; then
            if [[ ! -s "$combined_file" ]]; then
                # First file - include header
                cat "$src_file" >> "$combined_file"
            else
                # Subsequent files - skip header (first line)
                tail -n +2 "$src_file" >> "$combined_file"
            fi
        else
            echo "Warning: missing ${ext^^} file for $locus: $src_file"
        fi
    done
done
echo "Combined aux and ndm!"

# Build BLAST DBs from combined .fna files in the same directory
for segment in "${segments[@]}"; do
    combined_file="${germline_dir}/${species_short}_IG_${segment}.fna"
    outbase="${germline_dir}/${species_short}_IG_${segment}.fna"

    if [[ -f "$combined_file" ]]; then
        echo "Building BLAST DB for combined IG $segment in $outbase ..."
        makeblastdb -parse_seqids -dbtype nucl -in "$combined_file" -out "$outbase"
    else
        echo "Skipping combined IG $segment (file not found: $combined_file)"
    fi
done

echo "Download, combine, and BLAST DB creation complete!"

# Copy internal_data dir and keep in base directory
echo "Copy internal data folder and keep it in base directory !"
internal_data_dir="/usr/local/share/igblast/internal_data"
optional_data_dir="/usr/local/share/igblast/optional_file"
dest="$database_root"
echo "Copying internal_data folders to $dest..."
cp -r "$internal_data_dir" "$dest"
cp -r "$optional_data_dir" "$dest"
echo "internal_data and optional_file folder copy complete."


# Archive the whole folder into .tgz format
echo "Creating tgz archive of $base_dir at $archive_path ..."
base_dir="$(basename "$database_root")"
parent_dir="$(dirname "$database_root")"
archive_path="${database_root}.tgz"

echo "Creating tgz archive of $database_root at $archive_path ..."
tar -czf "$archive_path" -C "$parent_dir" "$base_dir"
echo "Archive created at $archive_path"

