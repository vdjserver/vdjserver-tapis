#!/usr/bin/env bash

# Loop over files starting with "job"
for file in job*; do
    # Skip if no matching files
    [[ -e "$file" ]] || continue

    echo "Processing $file"

    # Replace the echo command with whatever you want to run
    vdjserver-tools jobs submit "$file"
done