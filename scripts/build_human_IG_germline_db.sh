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
database_root="/data/db.2025.10.22"
loci=("IGH" "IGK" "IGL")
segments=("V" "D" "J")

# Set Paths
germline_dir="${database_root}/germline/${species_short}/ReferenceDirectorySet"
mkdir -p "$germline_dir"

## Install this package for data download.
pip install receptor-utils


## Download the germline data from orgdb
for locus in "${loci[@]}"; do
    echo "Downloading $species $locus into $germline_dir..."
    cd "$germline_dir"
    download_germline_set "$species" "$locus" -f MULTI-IGBLAST -p "${species_short}_${locus}_"
    cd ../
    download_germline_set "$species" "$locus" -f AIRRC-JSON -p "vdjserver_germline.airr"
    # Copy the JSON file into the germline_dir with species in filename
    if [[ -f "vdjserver_germline.airr.json" ]]; then
        cp "vdjserver_germline.airr.json" "vdjserver_${species_short}_germline.airr.json"
    else
        echo "Warning: AIRR JSON file not found for $locus"
    fi
done
echo "Germline dataset download — complete!"


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

# Merge .aux and .ndm files across loci
combined_base="${germline_dir}/${species_short}_IG"
for ext in aux ndm; do
    combined_file="${combined_base}.${ext}"
    > "$combined_file"  # create or empty file

    for locus in "${loci[@]}"; do
        src_file="${germline_dir}/${species_short}_${locus}.${ext}"

        if [[ -f "$src_file" ]]; then
            if [[ ! -s "$combined_file" ]]; then
                # First file → include header
                cat "$src_file" >> "$combined_file"
            else
                # Subsequent files → skip header (first line)
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
dest="$database_root"
echo "Copying internal_data folders to $dest..."
cp -r "$internal_data_dir" "$dest"
echo "internal_data folder copy complete."


# Archive the whole folder into .tgz format
echo "Creating tgz archive of $base_dir at $archive_path ..."
base_dir="$(basename "$database_root")"
parent_dir="$(dirname "$database_root")"
archive_path="${database_root}.tgz"

echo "Creating tgz archive of $database_root at $archive_path ..."
tar -czf "$archive_path" -C "$parent_dir" "$base_dir"
echo "Archive created at $archive_path"

