#
# Manage AIRR JSON DataFile
# simple functions to modify AIRR JSON DataFile from command line
#
# VDJServer Analysis Portal
# VDJServer Tapis applications
# https://vdjserver.org
#
# Copyright (C) 2023 The University of Texas Southwestern Medical Center
# Author: Scott Christley
# Date: July 8, 2023

from __future__ import print_function
import json
import argparse
import os
import sys
import airr

if (__name__=="__main__"):
    parser = argparse.ArgumentParser(description='Manage AIRR JSON DataFile.')
#    parser.add_argument('--repertoire_id', type=str, help='Repertoire ID')
#    parser.add_argument('--data_processing_id', type=str, help='Data processing ID')
#    parser.add_argument('--processing_stage', type=str, help='Add processing stage')
#    parser.add_argument('--create', help='Create entry for given repertoire_id and data_processing_id', action='store_true')
#    parser.add_argument('--repertoire_group', help='Add repertoire group entry', nargs=2, metavar=('group', 'groupType'))
#    parser.add_argument('--set', help='Set field entry', nargs=8, metavar=('entryType', 'group', 'name', 'key', 'value', 'description', 'fileType', 'derivedFrom'))
#    parser.add_argument('--get', help='Get field entry', nargs=8, metavar=('entryType', 'group', 'name', 'key', 'value', 'description', 'fileType', 'derivedFrom'))
    parser.add_argument('--list', help='Get list for field', nargs=2, metavar=('objectType', 'field'))
    parser.add_argument('json_file', type=str, help='AIRR JSON DataFile file name')
    args = parser.parse_args()

    if args:
        # load json
        metadata = airr.read_airr(args.json_file)

        if (args.list):
            for obj in metadata.get(args.list[0]):
                field = obj.get(args.list[1])
                if field:
                    sys.stdout.write(field + ' ')

