#
# Generate process workflow metadata
#
# Author: Scott Christley
# Date: Sep 7, 2016
#

from __future__ import print_function
import json
import argparse
import os
import sys
import csv

# Increment with any major updates
VERSION = 4

# empty group entry
def addGroupEntry(metadata, group, groupType):
    if (not metadata['groups'].get(group)):
        metadata['groups'][group] = {}
    metadata['groups'][group]['type'] = groupType

# generic routine to add group and file entry together
def addGroupFileEntry(metadata, type, group, name, key, value, desc, fileType, derivedFrom):
    if (not metadata['groups'].get(group)):
        metadata['groups'][group] = {}
    fileskey = group + "_" + name
    if (not metadata['groups'][group].get(name)):
        metadata['groups'][group][name] = { "type": type, "files": fileskey }
    if (not metadata['files'].get(fileskey)):
        metadata['files'][fileskey] = {}
    if derivedFrom == "null":
        metadata['files'][fileskey][key] = { "value": value, "description": desc, "type": fileType, "WasDerivedFrom": None }
    else:
        metadata['files'][fileskey][key] = { "value": value, "description": desc, "type": fileType, "WasDerivedFrom": derivedFrom }


if (__name__=="__main__"):
    template = { "process": { "version": VERSION }, "groups": {}, "files": {}, "calculations": [] };

    parser = argparse.ArgumentParser(description='Generate process metadata for workflow.')
    parser.add_argument('--init', type=str, nargs=2, help='Create initial metadata file from template', metavar=('appName', 'jobId'))
    parser.add_argument('--group', help='Add group entry', nargs=2, metavar=('group', 'groupType'))
    parser.add_argument('--entry', help='Add group/file entry', nargs=8, metavar=('entryType', 'group', 'name', 'key', 'value', 'description', 'fileType', 'derivedFrom'))
    parser.add_argument('--fileEntries', help='Add group/file entries from file', nargs=1, metavar=('filename'))
    parser.add_argument('--calc', help='Add calculation entry')
    parser.add_argument('--include', help='Include entries from file')
    parser.add_argument('--getSecondaryInput', help='Extract filenames for secondary input', nargs=2, metavar=('directory', 'entry'))
    parser.add_argument('--getSecondaryEntry', help='Extract secondary input entry', nargs=1, metavar=('entry'))
    parser.add_argument('--sampleMap', help='Generate sample mapping', nargs=1, metavar=('study_metadata'))
    parser.add_argument('--groupMap', help='Generate sample group mapping', nargs=1, metavar=('study_metadata'))
    parser.add_argument('--fileMap', help='Generate file mapping', action='store_true')
    parser.add_argument('json_file', type=str, help='Metadata JSON file name')
    args = parser.parse_args()

    if (args):
        if (args.init):
            template['process']['appName'] = args.init[0]
            template['process']['jobId'] = args.init[1]
            template['files']['metadata'] = { 'process_metadata': { "value": args.json_file, "description": "Process Workflow Metadata" } }
            if (os.path.exists('./study_metadata.json')):
                template['files']['metadata']['study_metadata'] = { "value": 'study_metadata.json', "description": "Study Metadata" }
            if (os.path.exists('./study_metadata.airr.json')):
                template['files']['metadata']['airr_metadata'] = { "value": 'study_metadata.airr.json', "description": "AIRR Study Metadata" }
            if (os.path.exists('./vdjserver_germline.airr.json')):
                template['files']['metadata']['germline_db'] = { "value": 'vdjserver_germline.airr.json', "description": "Germline Database" }

            # save the json
            with open(args.json_file, 'w') as json_file:
                json.dump(template, json_file)

        # load json
        with open(args.json_file, 'r') as f:
            metadata = json.load(f)

        if (args.getSecondaryInput):
            if metadata.get('secondaryInputs'):
                #print(metadata['secondaryInputs'])
                if metadata['secondaryInputs'].get(args.getSecondaryInput[1]):
                    if (isinstance(metadata['secondaryInputs'][args.getSecondaryInput[1]], list)):
                        for uuid in metadata['secondaryInputs'][args.getSecondaryInput[1]]:
                            entry = metadata['fileMetadata'].get(uuid)
                            if entry:
                                if entry['name'] == 'projectFile': sys.stdout.write(' ' + args.getSecondaryInput[0] + entry['value']['name'])
                                if entry['name'] == 'projectJobFile': sys.stdout.write(' ' + entry['value']['jobUuid'] + '/' + entry['value']['name'])
                    else:
                        uuid = metadata['secondaryInputs'][args.getSecondaryInput[1]]
                        entry = metadata['fileMetadata'].get(uuid)
                        if entry:
                            if entry['name'] == 'projectFile': sys.stdout.write(' ' + args.getSecondaryInput[0] + entry['value']['name'])
                            if entry['name'] == 'projectJobFile': sys.stdout.write(' ' + entry['value']['jobUuid'] + '/' + entry['value']['name'])

            # prevent saving of metadata file
            sys.exit(0)

        if (args.getSecondaryEntry):
            if metadata.get('secondaryInputs'):
                if metadata['secondaryInputs'].get(args.getSecondaryEntry[0]):
                    if (isinstance(metadata['secondaryInputs'][args.getSecondaryEntry[0]], list)):
                        for uuid in metadata['secondaryInputs'][args.getSecondaryEntry[0]]:
                            sys.stdout.write(' ' + uuid)
                    else:
                        uuid = metadata['secondaryInputs'][args.getSecondaryEntry[0]]
                        sys.stdout.write(' ' + uuid)

            # prevent saving of metadata file
            sys.exit(0)

        if args.sampleMap:
            study_md = json.load(open(args.sampleMap[0], 'r'))
            print('sample_id,sample,uuid,file,clones')
            for group in metadata['groups']:
                if metadata['groups'][group].get('type') == 'sample':
                    sample = list(metadata['groups'][group]['samples'].keys())[0]
                    sample_id = study_md['nucleicAcidProcessingMetadata'][sample]['value']['nucleic_acid_processing_id']
                    file = metadata['groups'][group]['samples'][sample][0]
                    fileKey = str(file) + '_RepCalc'
                    value = metadata['files'][fileKey]['clones']['value']
                    print(','.join([sample_id, group, sample, file, value]))
            # prevent saving of metadata file
            sys.exit(0)

        if args.groupMap:
            study_md = json.load(open(args.groupMap[0], 'r'))
            rep_groups = { 'RepertoireGroup': [] }
            for group in metadata['groups']:
                if metadata['groups'][group].get('type') == 'sampleGroup':
                    entry = { 'group_id': group }
                    entry['group_name'] = metadata['groups'][group]['category']
                    entry['repertoires'] = []
                    entry['sample_ids'] = []
                    rep_groups['RepertoireGroup'].append(entry)

                    for sample in list(metadata['groups'][group]['samples'].keys()):
                        sample_id = study_md['nucleicAcidProcessingMetadata'][sample]['value']['nucleic_acid_processing_id']
                        entry['repertoires'].append(sample_id)
                        entry['sample_ids'].append(sample)
            print('Output in group_map.airr.json')
            with open('group_map.airr.json', 'w') as json_file:
                json.dump(rep_groups, json_file, indent=2)
            # prevent saving of metadata file
            sys.exit(0)

        if args.fileMap:
            print('file,clones')
            for group in metadata['groups']:
                if metadata['groups'][group].get('type') == 'file':
                    fileKey = str(group) + '_RepCalc'
                    value = metadata['files'][fileKey]['clones']['value']
                    print(','.join([group, value]))
            # prevent saving of metadata file
            sys.exit(0)

        if (args.group):
            addGroupEntry(metadata, args.group[0], args.group[1])

        if (args.entry):
            addGroupFileEntry(metadata, args.entry[0], args.entry[1], args.entry[2], args.entry[3], args.entry[4], args.entry[5], args.entry[6], args.entry[7])

        if args.fileEntries:
            entry_file = csv.DictReader(open(args.fileEntries[0], 'r'))
            for row in entry_file:
                addGroupFileEntry(metadata, row['entryType'], row['group'], row['name'], row['key'], row['value'], row['description'], row['fileType'], row['derivedFrom'])

        if (args.calc):
            metadata['calculations'].append(args.calc);

        if (args.include):
            with open(args.include, 'r') as f:
                importData = json.load(f)
                if (importData.get('files')):
                    for file in importData['files']: metadata['files'][file] = importData['files'][file]
                if (importData.get('groups')):
                    for group in importData['groups']:
                        if metadata['groups'].get(group):
                            # add individual entries if group already exists
                            for entry in importData['groups'][group]:
                                metadata['groups'][group][entry] = importData['groups'][group][entry]
                        else:
                            metadata['groups'][group] = importData['groups'][group]


        # save the json
        with open(args.json_file, 'w') as json_file:
            json.dump(metadata, json_file, indent=2)

