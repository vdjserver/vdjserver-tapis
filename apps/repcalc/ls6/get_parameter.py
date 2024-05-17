#
# Pull out VDJ assignment job parameters from metadata
#
# Author: Scott Christley
# Date: Dec 12, 2016
#

from __future__ import print_function
import json
import argparse

parser = argparse.ArgumentParser(description='Extract job parameters from metadata.')
parser.add_argument('--organism', type=str, help='Get organism', metavar=('metadataFile'))
parser.add_argument('--seqtype', type=str, help='Get sequence type', metavar=('metadataFile'))
parser.add_argument('--domain', type=str, help='Get domain system', metavar=('metadataFile'))

args = parser.parse_args()
if (args):
    if (args.organism):
        with open(args.organism, 'r') as json_file:
            metadata = json.load(json_file)
            value = metadata['jobSelected']['parameters']['species']
            print(value)

    if (args.seqtype):
        with open(args.seqtype, 'r') as json_file:
            metadata = json.load(json_file)
            value = metadata['jobSelected']['parameters']['ig_seqtype']
            print(value)

    if (args.domain):
        with open(args.domain, 'r') as json_file:
            metadata = json.load(json_file)
            value = metadata['jobSelected']['parameters']['domain_system']
            print(value)

else:
    # invalid arguments
    parser.print_help()
