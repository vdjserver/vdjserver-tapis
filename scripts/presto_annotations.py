#
# Extract pRESTO annotations into columns
#
# Author: Scott Christley
# Date: April 18, 2019
#

from __future__ import print_function
import argparse
import os
import sys
import airr

if (__name__=="__main__"):
    parser = argparse.ArgumentParser(description='Extract pRESTO annotations into columns.')
    parser.add_argument('input_airr', type=str, help='Input AIRR TSV filename')
    parser.add_argument('output_airr', type=str, help='Output AIRR TSV filename')
    args = parser.parse_args()

    if args:
        input_data = airr.read_rearrangement(args.input_airr)
        output_data = airr.derive_rearrangement(args.output_airr, args.input_airr, fields=['duplicate_count', 'consensus_count', 'cell_id'])

        print('Processing pRESTO annotations for ' + args.input_airr)
        first = True
        for row in input_data:
            fields = row['sequence_id'].split('|')
            if len(fields) > 1:
                first = False
                row['sequence_id'] = fields[0]
                for i in range(1,len(fields)):
                    ann = fields[i].split('=')
                    if len(ann) == 2:
                        if ann[0] == 'DUPCOUNT':
                            row['duplicate_count'] = int(ann[1])
                        elif ann[0] == 'CONSCOUNT':
                            row['consensus_count'] = int(ann[1])
                        elif ann[0] == 'CELL_ID':
                            row['cell_id'] = ann[1]
            else:
                # if annotations are not found on first line, assume none in file and abort processing
                # if we have already processed some lines, then continue
                if first:
                    print('Aborting: no pRESTO annotations found for ' + args.input_airr)
                    output_data.close()
                    os.remove(args.output_airr)
                    sys.exit(0)

            output_data.write(row)
        output_data.close()
