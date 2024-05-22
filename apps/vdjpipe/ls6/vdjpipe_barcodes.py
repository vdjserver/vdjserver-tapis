#
# Helper script to generate barcode file names
#
# Author: Scott Christley
# Date: Sep 8, 2016
#

from __future__ import print_function
import json
import argparse
import sys
from Bio import SeqIO

parser = argparse.ArgumentParser(description='Generate barcode filenames.')
parser.add_argument('--barcodeFiles', type=str, nargs=4, help='Generate barcode filenames', metavar=('output', 'barcodeFile', 'name', 'derivedFrom'))
parser.add_argument('--uniqueGroup', type=str, nargs=5, help='Generate barcode filenames', metavar=('output', 'duplicates', 'barcodeFile', 'name', 'derivedFrom'))
parser.add_argument('--catFiles', type=str, nargs=2, help='Concatenate split barcode filenames', metavar=('output', 'barcodeFile'))
parser.add_argument('--fileList', type=str, nargs=2, help='Generate barcode filenames', metavar=('output', 'barcodeFile'))

args = parser.parse_args()
if (args):

    # Helper to generate barcode file name
    if (args.barcodeFiles):
        fasta_reader = SeqIO.parse(open(args.barcodeFiles[1], "r"), "fasta")
        for query_record in fasta_reader:
            print ("python ./process_metadata.py --group", query_record.id, "file", "process_metadata.json")
            print ("python ./process_metadata.py --entry output",
                   query_record.id, "vdjPipe processed_sequence",
                   args.barcodeFiles[0].replace('{MID}', query_record.id),
                   '"Total Post-Filter Sequences (' + args.barcodeFiles[2] + '), Barcode (' + query_record.id + ')"',
                   "read", args.barcodeFiles[3], "process_metadata.json")

    # Helper to generate barcode file name
    if (args.uniqueGroup):
        fasta_reader = SeqIO.parse(open(args.uniqueGroup[2], "r"), "fasta")
        for query_record in fasta_reader:
            print ("python ./process_metadata.py --group", query_record.id, "file", "process_metadata.json")
            print ("python ./process_metadata.py --entry output",
                   query_record.id, "vdjPipe sequence",
                   args.uniqueGroup[0].replace('{MID}', query_record.id),
                   '"Unique Post-Filter Sequences (' + args.uniqueGroup[3] + '), Barcode (' + query_record.id + ')"',
                   "read", args.uniqueGroup[4], "process_metadata.json")
            print ("python ./process_metadata.py --entry output",
                   query_record.id, "vdjPipe duplicates",
                   args.uniqueGroup[1].replace('{MID}', query_record.id),
                   '"Unique Sequence Duplicates Table (' + args.uniqueGroup[3] + '), Barcode (' + query_record.id + ')"',
                   "tsv", args.uniqueGroup[4], "process_metadata.json")

    if (args.catFiles):
        fasta_reader = SeqIO.parse(open(args.catFiles[1], "r"), "fasta")
        print ("rm -f $1")
        print ("touch $1")
        for query_record in fasta_reader:
            print ("if [ -f ", args.catFiles[0].replace('{MID}', query_record.id), " ]; then")
            print ("cat ", args.catFiles[0].replace('{MID}', query_record.id), ">> $1")
            print ("fi")

    if (args.fileList):
        fasta_reader = SeqIO.parse(open(args.fileList[1], "r"), "fasta")
        for query_record in fasta_reader:
            print (args.fileList[0].replace('{MID}', query_record.id))

else:
    # invalid arguments
    parser.print_help()
