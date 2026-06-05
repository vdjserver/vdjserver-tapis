#
# Extract sequence and sequence_id into FASTA
# Separates the loci
#
# VDJServer Analysis Portal
# VDJServer Tapis applications
# https://vdjserver.org
#
# Author: Scott Christley
# Copyright (C) 2020-2023 The University of Texas Southwestern Medical Center
# Date: Sept 27, 2020
#

from __future__ import print_function
import argparse
import os
import sys
import airr

if (__name__=="__main__"):
    parser = argparse.ArgumentParser(description='Extract FASTA from AIRR TSV.')
    parser.add_argument('input_airr', type=str, help='Input AIRR TSV filename')
    parser.add_argument('output_fasta', type=str, help='Output FASTA filename prefix')
    args = parser.parse_args()

    if args:
        input_data = airr.read_rearrangement(args.input_airr)

        # unfortunately 10x does not provide the locus field in its output
        # so we need to use the v_call
        ig_first = True
        ig_filename = args.output_fasta + "_IG.fasta"
        tcr_first = True
        tcr_filename = args.output_fasta + "_TCR.fasta"

        print('Extracting FASTA for ' + args.input_airr)
        for row in input_data:
            loci = None
            if row.get('locus') is None:
                locus = row['v_call']
            else:
                locus = row['locus']

            # do not create the output file until actual data
            if 'IG' in locus:
                loci = 'IG'
                if ig_first:
                    ig_output = open(ig_filename, 'w')
                    ig_first = False
                ig_output.write('>' + row['sequence_id'] + '\n')
                ig_output.write(row['sequence'] + '\n')
            if 'TR' in locus:
                loci = 'TCR'
                if tcr_first:
                    tcr_output = open(tcr_filename, 'w')
                    tcr_first = False
                tcr_output.write('>' + row['sequence_id'] + '\n')
                tcr_output.write(row['sequence'] + '\n')
            if loci is None:
                print('Warning: skipping record with unknown locus:', row)

        if not ig_first:
            ig_output.close()
        if not tcr_first:
            tcr_output.close()
