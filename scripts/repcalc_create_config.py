#
# Generate JSON config file for RepCalc
#
# VDJServer Analysis Portal
# Repertoire calculations and comparison
# https://vdjserver.org
#
# Copyright (C) 2016-2021 The University of Texas Southwestern Medical Center
# Author: Scott Christley
# Date: Sep 16, 2016
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

from __future__ import print_function
import json
import argparse
import sys
import copy


#
# main routine
#
parser = argparse.ArgumentParser(description='Generate RepCalc config.')
parser.add_argument('--init', type=str, nargs=2, help='Create initial config from template', metavar=('template', 'metadata file'))
parser.add_argument('--rearrangementFile', type=str, nargs=1, help='Add rearrangement file')
parser.add_argument('--repertoireID', type=str, nargs=1, help='Add repertoire ID')
parser.add_argument('--germline', type=str, nargs=1, help='Germline database file')
parser.add_argument('--stage', type=str, nargs=1, help='Processing stage')
parser.add_argument('--groups', type=str, nargs=1, help='Repertoire group file')
parser.add_argument('json_file', type=str, help='Output JSON file name')

args = parser.parse_args()
if args:
    if args.init:
        # new json config from template
        with open(args.init[0], 'r') as f:
            template = json.load(f)

        # save the json
        template['metadata'] = args.init[1]
    else:
        # existing json config
        with open(args.json_file, 'r') as f:
            template = json.load(f)

    # rearrangement
    if args.rearrangementFile:
        if template.get('rearrangement_files') is None:
            template['rearrangement_files'] = []
        template['rearrangement_files'].append(args.rearrangementFile[0])

    # repertoire
    if args.repertoireID:
        if template.get('repertoires') is None:
            template['repertoires'] = []
        template['repertoires'].append(args.repertoireID[0])

    # germline
    if args.germline:
        template['germline'] = args.germline[0]

    # germline
    if args.stage:
        template['processing_stage'] = args.stage[0]

    # repertoire groups
    if args.groups:
        template['groups'] = args.groups[0]

    # save the json
    with open(args.json_file, 'w') as json_file:
        json.dump(template, json_file, indent=2)

else:
    # invalid arguments
    parser.print_help()

