#
# Process a JSON template file for vdj_pipe.
# Used by pRESTO workflow to generate statistics.
#
# Author: Scott Christley
# Date: April 28, 2016
#

import json
import argparse

parser = argparse.ArgumentParser(description='Generate vdj_pipe statistics config for pRESTO workflow.')
parser.add_argument('template', type=str, help='JSON template file')
parser.add_argument('sequence', type=str, help='Sequence file')
parser.add_argument('prefix', type=str, help='Output file prefix')
parser.add_argument('json_out', type=str, help='Output JSON file name')
args = parser.parse_args()
if (args):
    # load json template
    with open(args.template, 'r') as f:
        template = json.load(f)

    #print(template)

    # sequence input file
    input_list = template['input']
    input_list[0] = { 'sequence' : args.sequence }

    # output file prefix
    seq_file = args.sequence + '.'
    step_list = template['steps']
    quality_stats = step_list[0]
    quality_stats['quality_stats'] = { 'out_prefix' : args.prefix + seq_file }
    comp_stats = step_list[1]
    comp_stats['composition_stats'] = { 'out_prefix' : args.prefix + seq_file }

    # save the json
    with open(args.json_out, 'w') as json_file:
        json.dump(template, json_file)

else:
    # invalid arguments
    parser.print_help()

