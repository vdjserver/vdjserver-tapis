import json
import argparse
import os
import sys
import gzip


if (__name__=="__main__"):
    parser = argparse.ArgumentParser(description='Combine airr tsv files for compairr.')
    parser.add_argument('-i', '--airr_tsv_files', dest='airr_tsv_files', nargs='*', type=str, help='Repertoire IDs')
    parser.add_argument('-o', '--output_path', dest='output_path', type=str, help='Combined airr tsv file name')
    args = parser.parse_args()
    
    if args:
        columns = ['repertoire_id', 'sequence_id', 'junction', 'junction_aa', 'v_call', 'j_call', 'duplicate_count']
        all_rows = []
        for path in args.airr_tsv_files:
            with gzip.open(path, 'rt') as f:
                header = f.readline().strip().split('\t')
                # Map columns to their indices
                indices = [header.index(col) for col in columns]
                for line in f:
                    parts = line.rstrip('\n').split('\t')
                    selected = [parts[i] for i in indices]
                    all_rows.append(selected)
        # Build column names once at the end
        output_path = args.output_path
        # output_path = "all_concatenated_cdr3.tsv"
        with open(output_path, 'w') as f:
            f.write('\t'.join(columns) + '\n')
            for row in all_rows:
                f.write('\t'.join(row) + '\n')

            