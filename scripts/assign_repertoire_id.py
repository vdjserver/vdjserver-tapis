#
# Assign repertoire_id in AIRR TSV
#
# Author: Scott Christley
# Date: March 19, 2020
#

from __future__ import print_function
import json
import argparse
import os
import sys
import airr

if (__name__=="__main__"):
    parser = argparse.ArgumentParser(description='Assign repertoire identifier in AIRR TSV.')
    parser.add_argument('repertoire_id', type=str, help='AIRR Repertoire ID')
    parser.add_argument('data_processing_id', type=str, help='AIRR data processing ID')
    parser.add_argument('airr_tsv', type=str, help='Input AIRR TSV file name')
    parser.add_argument('output_tsv', type=str, help='Output AIRR TSV file name')
    parser.add_argument('--add-missing', dest='add_missing', action='store_true',  help='Add junction_aa_length for makedb if missing.')
    args = parser.parse_args()

    if args:
        reader = airr.read_rearrangement(args.airr_tsv)
        add_missing = args.add_missing
        if add_missing:
            writer = airr.derive_rearrangement(args.output_tsv, args.airr_tsv, fields=['repertoire_id', 'data_processing_id', 'junction_aa_length'])
        else:
            writer = airr.derive_rearrangement(args.output_tsv, args.airr_tsv, fields=['repertoire_id', 'data_processing_id'])
        print("Value of add_missing: ", add_missing)
        for row in reader:
            row['repertoire_id'] = args.repertoire_id
            row['data_processing_id'] = args.data_processing_id
            if add_missing:
                junction_aa = row.get('junction_aa')
                if junction_aa is None:
                    row['junction_aa_length'] = None
                else:
                    row['junction_aa_length'] = len(junction_aa)
                
            writer.write(row)
