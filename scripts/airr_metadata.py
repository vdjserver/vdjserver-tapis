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



def get_repertoire_chain(json_file, repertoire_id):

    with open(json_file, "r", encoding="utf-8") as file:
        data = json.load(file)

    selected_chain_types = set()
    locus_set = set()

    for repertoire in data.get("Repertoire", []):
        if repertoire.get("repertoire_id") != repertoire_id:
            continue

        for sample in repertoire.get("sample", []) or []:
            for pcr_target in sample.get("pcr_target", []) or []:
                locus = pcr_target.get("pcr_target_locus")

                if not locus:
                    continue

                locus = str(locus).strip().upper()
                locus_set.add(locus)

                if locus.startswith("TR"):
                    selected_chain_types.add("TR")
                elif locus.startswith("IG"):
                    selected_chain_types.add("IG")

        break

    if len(selected_chain_types) == 1:
        chain_type = selected_chain_types.pop()
        
    elif len(selected_chain_types) == 0:
        print(f"No TR/IG locus found for repertoire '{repertoire_id}'. Using chain='auto'.")
        chain_type = "auto"
    else:
        print(f"Both TR and IG loci found for repertoire '{repertoire_id}'. Exiting.")
        sys.exit(1)

    return  chain_type


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
    parser.add_argument('--chain_type', type=str, help='Get repertoire_if for chain')
    parser.add_argument('json_file', type=str, help='AIRR JSON DataFile file name')
    args = parser.parse_args()

    if args:
        if (args.list):
            # Moved here cause cellranger does not have airr
            import airr
            metadata = airr.read_airr(args.json_file)
            for obj in metadata.get(args.list[0]):
                field = obj.get(args.list[1])
                if field:
                    sys.stdout.write(field + ' ')
        if args.chain_type:
            result = get_repertoire_chain(args.json_file, args.chain_type)
            print(result)