#
# VDJServer IgBlast SplitFasta function
#
# VDJServer Analysis Portal
# VDJServer Tapis applications
# https://vdjserver.org
#
# Copyright (C) 2016-2026 The University of Texas Southwestern Medical Center
# Author: Tanzira Najnin
# Date: Sep 1, 2026
# 

#!/usr/bin/env python3

import argparse
import os
from Bio import SeqIO


def split_fasta(input_file, output_dir, prefix, records_per_file):
    os.makedirs(output_dir, exist_ok=True)

    count = 0
    file_count = 0
    output_handle = None

    try:
        for record in SeqIO.parse(input_file, "fasta"):

            if count == 0:
                output_file = os.path.join(output_dir, f"{prefix}.{file_count}.fasta")

                output_handle = open(output_file, "w")
                print(f"Creating {output_file}")

            SeqIO.write(record, output_handle, "fasta")

            count += 1

            if count >= records_per_file:
                output_handle.close()
                output_handle = None

                count = 0
                file_count += 1

    finally:
        if output_handle is not None:
            output_handle.close()

    print(f"Split {input_file} into {file_count + (1 if count > 0 else 0)} files")


def main():
    parser = argparse.ArgumentParser(
        description="Split a FASTA file into chunks containing N records."
    )

    parser.add_argument("-f", "--fasta", required=True)
    parser.add_argument("-o", "--output-dir", default=".")
    parser.add_argument("-s", "--stem", default="query")
    parser.add_argument("-r", "--records", type=int, default=1000)

    args = parser.parse_args()

    print(
        f"Splitting {args.fasta} into chunks of "
        f"{args.records} records"
    )

    split_fasta(args.fasta, args.output_dir, args.stem, args.records)


if __name__ == "__main__":
    main()