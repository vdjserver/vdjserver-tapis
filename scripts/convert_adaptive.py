#
# Extract out FASTA sequences from Adaptive Biotech file
#
# Author: Scott Christley
# Date: May 23, 2017
#

from __future__ import print_function
import json
import argparse
import os
import sys

if (__name__=="__main__"):
    parser = argparse.ArgumentParser(description='Convert Adaptive Biotech export file.')
    parser.add_argument('--counting_method', help='Counting method (v1, v2, v3)')
    parser.add_argument('adaptive_file', nargs='*', type=str, help='Input Adaptive file names')
    args = parser.parse_args()

    if args:
        for fname in args.adaptive_file:
            with open(fname, 'r') as infile:
                print('Processing ' + fname)
                header = True
                first = True
                outname = '.'.join(fname.split('.')[0:-1]) + '.fasta'
                outname = outname.replace(' ', '_')
                outfile = open(outname, 'w')
                count = 0
                counting_method_col = None
                counting_method = None
                seq_col = None
                template_col = None
                while True:
                    line = infile.readline().rstrip('\n')
                    if not line: break
                    fields = line.split('\t')
                    if header:
                        header = False
                        headers = fields
                        if args.counting_method:
                            counting_method = args.counting_method
                        else:
                            try:
                                counting_method_col = headers.index('counting_method')
                            except:
                                counting_method_col = None
                            if not counting_method_col:
                                print('WARNING: cannot find counting_method column, assuming v3.')
                                counting_method = 'v3'
                        continue

                    if first:
                        first = False
                        if counting_method_col:
                            counting_method = fields[counting_method_col]
                        if not counting_method:
                            print('ERROR: no counting method.')
                            sys.exit(1)
                        elif counting_method == 'v1':
                            seq_col = headers.index('rearrangement')
                            template_col = headers.index('reads')
                        elif counting_method == 'v2':
                            seq_col = headers.index('rearrangement')
                            template_col = headers.index('templates')
                        elif counting_method == 'v3':
                            seq_col = headers.index('rearrangement')
                            template_col = headers.index('templates')
                        elif counting_method == 'v4':
                            seq_col = headers.index('rearrangement')
                            template_col = headers.index('templates')
                        else:
                            print('ERROR: unknown counting method:', counting_method)
                            sys.exit(1)

                    if int(fields[template_col]) < 1:
                        outfile.write('>' + '.'.join(outname.split('.')[0:-1]) + '.seq.' + str(count) + '|DUPCOUNT=1\n')
                    else:
                        outfile.write('>' + '.'.join(outname.split('.')[0:-1]) + '.seq.' + str(count) + '|DUPCOUNT=' + str(fields[template_col]) + '\n')
                    outfile.write(fields[seq_col] + '\n')
                    count += 1
            outfile.close()