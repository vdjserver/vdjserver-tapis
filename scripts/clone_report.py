#
# Generate summary table for clonal assignment
#
# Author: Scott Christley
# Date: Dec 15, 2029
#

from __future__ import print_function
import json
import argparse
import os
import sys
import csv

if (__name__=="__main__"):
    parser = argparse.ArgumentParser(description='Generate clonal assignment summary.')
    parser.add_argument('input_files', nargs='*', type=str, help='JSON files')
    args = parser.parse_args()

    if args:
        first = True
        names = ['sample_id']
        usage = {}
        for f in args.input_files:
            fields = f.split('.')
            sample_id = fields[0]
            usage[sample_id] = {'sample_id': sample_id}
            fields = f.split('.makedb.')
            prefix = fields[0] + '.makedb.'
            print('Processing sample:', sample_id, 'prefix:', prefix)

            # non/productive counts
            filename = prefix + 'productive.airr.json'
            try:
                doc = json.load(open(filename, 'r'))
            except:
                print('WARNING: Could not read file', filename, 'skipping...')
                continue
            usage[sample_id]['rearrangement_count'] = doc['RECORDS']
            if first: names.append('rearrangement_count')
            usage[sample_id]['rearrangement_count_productive'] = doc['SELECTED']
            if first: names.append('rearrangement_count_productive')

            # allele counts
            filename = prefix + 'summary.allele.clone.airr.json'
            try:
                doc = json.load(open(filename, 'r'))
            except:
                print('WARNING: Could not read file', filename, 'skipping...')
                continue
            usage[sample_id]['allele_rearrangement_pass'] = doc.get('PASS')
            if usage[sample_id]['allele_rearrangement_pass'] is None:
                usage[sample_id]['allele_rearrangement_pass'] = 0
            if first: names.append('allele_rearrangement_pass')
            usage[sample_id]['allele_rearrangement_fail'] = doc.get('FAIL')
            if usage[sample_id]['allele_rearrangement_fail'] is None:
                usage[sample_id]['allele_rearrangement_fail'] = 0
            if first: names.append('allele_rearrangement_fail')
            usage[sample_id]['allele_clone_count'] = doc.get('CLONES')
            if usage[sample_id]['allele_clone_count'] is None:
                usage[sample_id]['allele_clone_count'] = 0
            if first: names.append('allele_clone_count')

            # gene counts
            filename = prefix + 'summary.gene.clone.airr.json'
            try:
                doc = json.load(open(filename, 'r'))
            except:
                print('WARNING: Could not read file', filename, 'skipping...')
                continue
            usage[sample_id]['gene_rearrangement_pass'] = doc.get('PASS')
            if usage[sample_id]['gene_rearrangement_pass'] is None:
                usage[sample_id]['gene_rearrangement_pass'] = 0
            if first: names.append('gene_rearrangement_pass')
            usage[sample_id]['gene_rearrangement_fail'] = doc.get('FAIL')
            if usage[sample_id]['gene_rearrangement_fail'] is None:
                usage[sample_id]['gene_rearrangement_fail'] = 0
            if first: names.append('gene_rearrangement_fail')
            usage[sample_id]['gene_clone_count'] = doc.get('CLONES')
            if usage[sample_id]['gene_clone_count'] is None:
                usage[sample_id]['gene_clone_count'] = 0
            if first: names.append('gene_clone_count')

            first = False

        writer = csv.DictWriter(open('clone_report.csv', 'w'), fieldnames=names)
        writer.writeheader()
        for rep in usage:
            writer.writerow(usage[rep])

