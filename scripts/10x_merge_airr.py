#
# Merge 10x AIRR field with IgBlast AIRR TSV
# Creates AIRR Cell and Clone objects
#
# VDJServer Analysis Portal
# VDJServer Tapis applications
# https://vdjserver.org
#
# Author: Scott Christley
# Copyright (C) 2020-2023 The University of Texas Southwestern Medical Center
# Date: Sept 27, 2020
#

from __future__ import print_function
import argparse
import os
import sys
import airr
import uuid

if (__name__=="__main__"):
    parser = argparse.ArgumentParser(description='Merge 10x AIRR field with IgBlast AIRR TSV.')
    parser.add_argument('repertoire_id', type=str, help='AIRR repertoire_id')
    parser.add_argument('data_processing_id', type=str, help='AIRR data_processing_id')
    args = parser.parse_args()

    data_processing_id = args.data_processing_id
    if data_processing_id == 'null':
        data_processing_id = None

    #input_processing_stage = 'igblast'
    #output_processing_stage = '10x.igblast'

    if args:
        # We infer input/output file names based upon repertoire_id
        file_input_10x = args.repertoire_id + '.airr_rearrangement.tsv'
        file_input_igblast = args.repertoire_id + '.igblast.airr.tsv'
        file_output_airr_tsv = args.repertoire_id + '.10x.igblast.airr.tsv'
        file_output_airr_json = args.repertoire_id + '.10x.igblast.airr.json'

        print('Processing 10x AIRR file ' + file_input_10x)
        input_10x = airr.read_rearrangement(file_input_10x)
        input_igblast = airr.read_rearrangement(file_input_igblast)
        more_fields = ['repertoire_id', 'data_processing_id', 'umi_count', 'adc_annotation_sequence_id']
        for f in input_10x.fields:
            if f not in input_igblast.fields:
                more_fields.append(f)
        print(more_fields)
        data_10x = {}
        for row in input_10x:
            if data_10x.get(row['sequence_id']) is not None:
                print('ERROR: duplicate sequence id in 10x AIRR file: ' + row['sequence_id'])
                sys.exit(1)
            data_10x[row['sequence_id']] = row

        print('Merging 10x AIRR fields with IgBlast AIRR TSV file ' + file_input_igblast)
        output_data = airr.derive_rearrangement(file_output_airr_tsv, file_input_igblast, fields=more_fields)

        cells = {}
        clones = {}
        data_airr = { 'Cell': [], 'Clone': [] }
        for row in input_igblast:
            row_10x = data_10x.get(row['sequence_id'])
            if row_10x is None:
                print('ERROR: sequence id is missing from 10x AIRR file: ' + row['sequence_id'])
                sys.exit(1)

            for f in more_fields:
                # manually handle duplicate_count, which is umi_count in AIRR spec
                if f == 'umi_count':
                    row[f] = row_10x['duplicate_count']
                elif f == 'duplicate_count':
                    row[f] = 1
                elif f == 'repertoire_id':
                    row[f] = args.repertoire_id
                elif f == 'data_processing_id':
                    row[f] = data_processing_id
                elif f == 'adc_annotation_sequence_id':
                    row['adc_annotation_sequence_id'] = row['sequence_id']
                    row['sequence_id'] = 'vdjserver:rearrangement:' + str(uuid.uuid1())
                else:
                    row[f] = row_10x[f]

            # AIRR Clone
            if clones.get(row['clone_id']) is None:
                clones[row['clone_id']] = airr.schema.AIRRSchema['Clone'].template()
                for obj in clones[row['clone_id']]:
                    if obj == 'repertoire_id':
                        clones[row['clone_id']]['repertoire_id'] = args.repertoire_id
                    elif obj == 'data_processing_id':
                        clones[row['clone_id']]['data_processing_id'] = data_processing_id
                    elif obj == 'clone_id':
                        clones[row['clone_id']]['clone_id'] = 'vdjserver:clone:' + str(uuid.uuid1())
                    elif obj == 'clone_count':
                        clones[row['clone_id']]['clone_count'] = 0
                    else:
                        clones[row['clone_id']][obj] = row.get(obj)
                clones[row['clone_id']]['adc_annotation_clone_id'] = row['clone_id']

            # AIRR Cell
            if cells.get(row['cell_id']) is None:
                cells[row['cell_id']] = airr.schema.AIRRSchema['Cell'].template()
                cells[row['cell_id']]['repertoire_id'] = args.repertoire_id
                cells[row['cell_id']]['data_processing_id'] = data_processing_id
                cells[row['cell_id']]['cell_id'] = 'vdjserver:cell:' + str(uuid.uuid1())
                cells[row['cell_id']]['adc_annotation_cell_id'] = row['cell_id']
                cells[row['cell_id']]['rearrangements'] = []
                cells[row['cell_id']]['clones'] = [{ 'clone_id': clones[row['clone_id']]['clone_id'], 'data_processing_id': args.data_processing_id }]
                clones[row['clone_id']]['clone_count'] = clones[row['clone_id']]['clone_count'] + 1
            cells[row['cell_id']]['rearrangements'].append(row['sequence_id'])

            # update rearrangement ids
            row['adc_annotation_cell_id'] = row['cell_id']
            row['cell_id'] = cells[row['adc_annotation_cell_id']]['cell_id']
            row['adc_annotation_clone_id'] = row['clone_id']
            row['clone_id'] = clones[row['adc_annotation_clone_id']]['clone_id']

            output_data.write(row)
        output_data.close()

        # write AIRR data file
        for cell in cells:
            data_airr['Cell'].append(cells[cell])
        for clone in clones:
            data_airr['Clone'].append(clones[clone])
        airr.write_airr(file_output_airr_json, data_airr)
    print("Done with 10X merge.")