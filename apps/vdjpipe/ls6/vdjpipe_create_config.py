#
# Generate JSON config file for VDJPipe
#
# Author: Scott Christley
# Date: Sep 6, 2016
#

from __future__ import print_function
import json
import argparse
import sys

def str2bool(v):
    return v.lower() in ("yes", "true", "t", "1")


template = {"base_path_input":"","base_path_output":"","summary_output_path":"summary.txt","input":[],"steps":[]};

parser = argparse.ArgumentParser(description='Generate VDJPipe config.')
parser.add_argument('--init', type=str, help='Create initial config with summary file')
parser.add_argument('json_file', type=str, help='Output JSON file name')

parser.add_argument('--merge', type=str, nargs=2, help='Merge file config', metavar=('score', 'output'))
parser.add_argument('--forwardReads', type=str, nargs='*', help='Forward read files')
parser.add_argument('--reverseReads', type=str, nargs='*', help='Reverse read files')

parser.add_argument('--fastq', type=str, nargs='*', help='FASTQ Read files')
parser.add_argument('--fasta', type=str, nargs='*', help='FASTA Read files')
parser.add_argument('--quals', type=str, nargs='*', help='Quality files')

parser.add_argument('--statistics', type=str, help='Add statistics step')
parser.add_argument('--length', type=str, help='Add length filter step')
parser.add_argument('--quality', type=str, help='Add quality filter step')
parser.add_argument('--homopolymer', type=str, help='Add homopolymer filter step')
parser.add_argument('--forwardPrimer', type=str, nargs=4, help='Forward primer', metavar=('mismatches', 'file', 'trim', 'window'))
parser.add_argument('--reversePrimer', type=str, nargs=4, help='Reverse primer', metavar=('mismatches', 'file', 'trim', 'window'))
parser.add_argument('--barcode', type=str, nargs=7, help='Barcode', metavar=('location', 'discard',  'mismatches', 'file', 'trim', 'window', 'name'))
parser.add_argument('--barcodeHistogram', type=str, help='Barcode histogram')
parser.add_argument('--unique', type=str, nargs=2, help='Find unique sequences', metavar=('output', 'dups'))
parser.add_argument('--uniqueGroup', type=str, nargs=2, help='Find unique sequences within barcode groups', metavar=('output', 'dups'))
parser.add_argument('--write', type=str, help='Write sequences')

args = parser.parse_args()
if (args):
    if (args.init):
        # save the json
        template['summary_output_path'] = args.init;
        with open(args.json_file, 'w') as json_file:
            json.dump(template, json_file)

    # load json
    with open(args.json_file, 'r') as f:
        config = json.load(f)

    # read merging
    if (args.merge):
        config['paired_reads'] = True;
        config['steps'].append({"merge_paired":{"min_score":args.merge[0]}});
        config['steps'].append({"apply":{"to":"merged","step":{"write_sequence":{"out_path":args.merge[1]}}}});

        if (not args.forwardReads) or (not args.reverseReads):
            print ("ERROR: forward/reverse read files not provided.", file=sys.stderr);
            sys.exit(1);

        if (len(args.forwardReads) != len(args.reverseReads)):
            print ("ERROR: Equal number of forward/reverse read files not provided.", file=sys.stderr);
            sys.exit(1);

        for i in range(0, len(args.forwardReads)):
            config['input'].append({"forward_seq":args.forwardReads[i],"reverse_seq":args.reverseReads[i]});

    # reads
    if (args.fastq):
        for i in range(0, len(args.fastq)):
            config['input'].append({"sequence":args.fastq[i]});

    if (args.fasta):
        if (not args.quals):
            print ("ERROR: quality files not provided.", file=sys.stderr);
            sys.exit(1);

        if (len(args.fasta) != len(args.quals)):
            print ("ERROR: Equal number of FASTA/quality read files not provided.", file=sys.stderr);
            sys.exit(1);

        for i in range(0, len(args.fasta)):
            config['input'].append({"sequence":args.fasta[i],"quality":args.quals[i]});

    # statistics
    if (args.statistics):
        config['steps'].append({"quality_stats":{"out_prefix":args.statistics}});
        config['steps'].append({"composition_stats":{"out_prefix":args.statistics}});

    # length filter
    if (args.length):
        config['steps'].append({"length_filter":{"min":args.length}});

    # quality filter
    if (args.quality):
        config['steps'].append({"average_quality_filter":{"min_quality":args.quality}});

    # homopolymer filter
    if (args.homopolymer):
        config['steps'].append({"homopolymer_filter":{"max_length":args.homopolymer}});

    # barcode
    if (args.barcode):
        step = {"match":{"reverse":True,
                         "elements":[{"max_mismatches":args.barcode[2],
                                      "required":str2bool(args.barcode[1]),
                                      "length":args.barcode[5],
                                      "seq_file":args.barcode[3],
                                      "score_name":args.barcode[6] + '-score',
                                      "value_name":args.barcode[6]
                                     }]}};
        if (args.barcode[0] == 'forward'):
            step['match']['elements'][0]['start'] = {"before":""};
            if (str2bool(args.barcode[4])):
                step['match']['elements'][0]['cut_lower'] = {"after":"0"};
        else:
            step['match']['elements'][0]['end'] = {"after":""};
            if (str2bool(args.barcode[4])):
                step['match']['elements'][0]['cut_upper'] = {"before":"0"}
        config['steps'].append(step);

    if (args.barcodeHistogram):
        config['steps'].append({"histogram":{"name":args.barcodeHistogram,"out_path":args.barcodeHistogram + '.tsv'}});
        config['steps'].append({"histogram":{"name":args.barcodeHistogram + '-score',"out_path":args.barcodeHistogram + '-score.tsv'}});
        
    # forward primer
    if (args.forwardPrimer):
        if (str2bool(args.forwardPrimer[2])):
            step = {"match":{"elements":[{"require_best":False,
                                          "required":True,
                                          "max_mismatches":args.forwardPrimer[0],
                                          "seq_file":args.forwardPrimer[1],
                                          "length":args.forwardPrimer[3],
                                          "cut_lower":{"after":0},
                                          "start":{"before":""}}]}};
        else:
            step = {"match":{"elements":[{"require_best":False,
                                          "required":True,
                                          "max_mismatches":args.forwardPrimer[0],
                                          "seq_file":args.forwardPrimer[1],
                                          "length":args.forwardPrimer[3],
                                          "start":{"before":""}}]}};
        config['steps'].append(step);

    # reverse primer
    if (args.reversePrimer):
        if (str2bool(args.reversePrimer[2])):
            step = {"match":{"elements":[{"require_best":False,
                                          "required":True,
                                          "max_mismatches":args.reversePrimer[0],
                                          "seq_file":args.reversePrimer[1],
                                          "length":args.reversePrimer[3],
                                          "cut_upper":{"before":0},
                                          "end":{"after":""}}]}};
        else:
            step = {"match":{"elements":[{"require_best":False,
                                          "required":True,
                                          "max_mismatches":args.reversePrimer[0],
                                          "seq_file":args.reversePrimer[1],
                                          "length":args.reversePrimer[3],
                                          "end":{"after":""}}]}};
        config['steps'].append(step);

    # find unique
    if (args.unique):
        config['steps'].append({"find_shared":{"out_unique":args.unique[0],"out_duplicates":args.unique[1]}});
    if (args.uniqueGroup):
        config['steps'].append({"find_shared":{"out_group_unique":args.uniqueGroup[0],"out_group_duplicates":args.uniqueGroup[1]}});

    # write sequences
    if (args.write):
        config['steps'].append({"write_sequence":{"out_path":args.write}});

    # save the json
    with open(args.json_file, 'w') as json_file:
        json.dump(config, json_file, indent=2)

else:
    # invalid arguments
    parser.print_help()

