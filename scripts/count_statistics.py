#
# Count total, productive and non-productive rearrangements in AIRR TSV files
#
# VDJServer Analysis Portal
# VDJServer Tapis applications
# https://vdjserver.org
#
# Part of the iReceptor+ platform
#
# Copyright (C) 2021 The University of Texas Southwestern Medical Center
# Date: July 22, 2021
# Author: Scott Christley
# 

from __future__ import print_function
import json
import argparse
import os
import sys
import airr
import csv

names = ['file', 'productive records', 'non-productive records', 'total records',
    'productive dupcount', 'non-productive dupcount', 'total dupcount']
if (__name__=="__main__"):
    parser = argparse.ArgumentParser(description='Count rearrangements in AIRR TSV.')
    parser.add_argument('-t', '--totals', help='Include totals for all files', action="store_true", required=False)
    parser.add_argument('airr_tsv', nargs='*', type=str, help='Input AIRR TSV file names')
    args = parser.parse_args()

    if args:
        summary = {}
        all_cnt = 0
        all_prod_cnt = 0
        all_unprod_cnt = 0
        all_dup = 0
        all_prod_dup = 0
        all_unprod_dup = 0
        for fname in args.airr_tsv:
            print('Processing', fname)
            summary[fname] = {}
            summary[fname]['file'] = fname
            total_cnt = 0
            total_dup = 0
            prod_cnt = 0
            prod_dup = 0
            unprod_cnt = 0
            unprod_dup = 0
            reader = airr.read_rearrangement(fname)
            for row in reader:
                total_cnt += 1
                if row.get('duplicate_count') is not None:
                    total_dup += row['duplicate_count']
                else:
                    total_dup += 1
                if row['productive']:
                    prod_cnt += 1
                    if row.get('duplicate_count') is not None:
                        prod_dup += row['duplicate_count']
                    else:
                        prod_dup += 1
                else:
                    unprod_cnt += 1
                    if row.get('duplicate_count') is not None:
                        unprod_dup += row['duplicate_count']
                    else:
                        unprod_dup += 1
            summary[fname]['productive records'] = prod_cnt
            summary[fname]['non-productive records'] = unprod_cnt
            summary[fname]['total records'] = total_cnt
            summary[fname]['productive dupcount'] = prod_dup
            summary[fname]['non-productive dupcount'] = unprod_dup
            summary[fname]['total dupcount'] = total_dup
            all_prod_cnt += prod_cnt
            all_unprod_cnt += unprod_cnt
            all_cnt += total_cnt
            all_prod_dup += prod_dup
            all_unprod_dup += unprod_dup
            all_dup += total_dup

        # totals for all files
        totals = {}
        totals['file'] = 'TOTALS'
        totals['productive records'] = all_prod_cnt
        totals['non-productive records'] = all_unprod_cnt
        totals['total records'] = all_cnt
        totals['productive dupcount'] = all_prod_dup
        totals['non-productive dupcount'] = all_unprod_dup
        totals['total dupcount'] = all_dup

        # write out count statistics
        writer = csv.DictWriter(open('count_statistics.csv', 'w'), fieldnames = names)
        writer.writeheader()
        for s in summary:
            writer.writerow(summary[s])
        if args.totals:
            writer.writerow(totals)
