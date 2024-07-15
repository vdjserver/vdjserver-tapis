#
# Create AIRR DataFile with repertoires
#
# Author: Scott Christley
# Date: July 3, 2023
#

from __future__ import print_function
import json
import argparse
import os
import sys
import airr

if (__name__=="__main__"):
    parser = argparse.ArgumentParser(description='Create AIRR JSON metadata.')
    parser.add_argument('output_json', type=str, help='Output AIRR JSON file name')
    parser.add_argument('data_processing_id', type=str, help='Data processing ID')
    parser.add_argument('repertoire_id', nargs='*', type=str, help='Repertoire IDs')
    args = parser.parse_args()

    if args:
        reps = []
        for rep_id in args.repertoire_id:
            rep = airr.schema.RepertoireSchema.template()
            rep['repertoire_id'] = rep_id
            rep['data_processing'][0]['data_processing_id'] = args.data_processing_id
            reps.append(rep)

        data = {}
        data['Repertoire'] = reps
        airr.write_airr(args.output_json, data)

