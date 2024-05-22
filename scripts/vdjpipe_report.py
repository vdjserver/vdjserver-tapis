#
# Parse VDJPipe log files into summary report
#
# Author: Scott Christley
# Date: Jan 21, 2021
#

from __future__ import print_function
import argparse
import os
import sys
import csv

names = ['file', 'input reads', 'merged reads', 'length_filter', 'quality_filter',
    'homopolymer_filter', 'match1', 'match2', 'match3', 'filtered reads', 'unique reads']
if (__name__=="__main__"):
    parser = argparse.ArgumentParser(description='Generate VDJPipe summary report.')
    parser.add_argument('input_files', nargs='*', type=str, help='VDJPipe log files')
    args = parser.parse_args()

    if args:
        summary = {}
        for f in args.input_files:
            summary[f] = {}
            summary[f]['file'] = f
            fields = f.split('.summary.txt')
            merged = False
            try:
                reader = open(fields[0] + '.merge_summary.txt', 'r')
                line = reader.readline()
                while line:
                    if 'sequencing reads processed' in line:
                        fields = line.split(' ')
                        summary[f]['input reads'] = int(fields[0])
                        merged = True
                        break
                    line = reader.readline()
                reader.close()
            except:
                pass
            reader = open(f, 'r')
            line = reader.readline()
            while line:
                if 'length_filter' in line:
                    line = reader.readline()
                    fields = line.split(' ')
                    summary[f]['length_filter'] = int(fields[1])
                elif 'average_quality_filter' in line:
                    line = reader.readline()
                    fields = line.split(' ')
                    summary[f]['quality_filter'] = int(fields[1])
                elif 'homopolymer_filter' in line:
                    line = reader.readline()
                    fields = line.split(' ')
                    summary[f]['homopolymer_filter'] = int(fields[1])
                elif 'match' in line:
                    line = reader.readline()
                    fields = line.split(' ')
                    if summary[f].get('match1') is None:
                        summary[f]['match1'] = int(fields[1])
                    elif summary[f].get('match2') is None:
                        summary[f]['match2'] = int(fields[1])
                    else:
                        summary[f]['match3'] = int(fields[1])
                elif 'write_sequence' in line:
                    line = reader.readline()
                    line = reader.readline()
                    fields = line.split(' ')
                    summary[f]['filtered reads'] = int(fields[2])
                elif 'find_shared' in line:
                    line = reader.readline()
                    line = reader.readline()
                    fields = line.split(' ')
                    summary[f]['unique reads'] = int(fields[3])
                elif 'sequencing reads processed' in line:
                    fields = line.split(' ')
                    if merged:
                        summary[f]['merged reads'] = int(fields[0])
                    else:
                        summary[f]['input reads'] = int(fields[0])
                line = reader.readline()
        writer = csv.DictWriter(open('vdjpipe_summary.csv', 'w'), fieldnames = names)
        writer.writeheader()
        for s in summary:
            writer.writerow(summary[s])
