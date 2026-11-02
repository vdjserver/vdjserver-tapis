#
# Split AIRR TSV into separate files for each locus
#
# VDJServer Analysis Portal
# VDJServer Tapis applications
# https://vdjserver.org
#
# Author: Scott Christley
# Copyright (C) 2026 The University of Texas Southwestern Medical Center
# Date: Oct 30, 2026
#

from __future__ import print_function
import argparse
import os
import sys
import airr

if (__name__=="__main__"):
    parser = argparse.ArgumentParser(description='Split AIRR TSV by locus.')
    parser.add_argument('repertoire_json', type=str, help='AIRR JSON repertoire metadata')
    parser.add_argument('processing_stage', type=str, help='VDJServer processing stage')
    args = parser.parse_args()

    if args:
        try:
            # Load the repertoires
            data = airr.read_airr(args.repertoire_json)
    
            # Put repertoires in dictionary keyed by repertoire_id
            repDict = { obj['repertoire_id'] : obj for obj in data['Repertoire'] }
        except:
            print("Could not read metadata file: " + args.repertoire_json)
            raise

        # process each repertoire
        for rep_id in repDict:
            output_handles = {}

            # We infer input/output file names based upon repertoire_id
            file_input_airr_tsv = rep_id + '.' + args.processing_stage + '.airr.tsv'
            print('Processing input AIRR file: ' + file_input_airr_tsv)
            input_airr = airr.read_rearrangement(file_input_airr_tsv)
            for row in input_airr:
                if row['locus'] is None or len(row['locus']) == 0:
                    continue
                if output_handles.get(row['locus']) is None:
                    # we do not create the handle until locus is found
                    file_output = rep_id + '.' + row['locus'] + '.' + args.processing_stage + '.airr.tsv'
                    print('Generating output AIRR file: ' + file_output)
                    output_data = airr.derive_rearrangement(file_output, file_input_airr_tsv)
                    output_handles[row['locus']] = output_data
                else:
                    output_data = output_handles[row['locus']]
                output_data.write(row)
            for handle in output_handles:
                output_handles[handle].close()

    print("Done with split locus.")