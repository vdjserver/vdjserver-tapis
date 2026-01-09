#
# Generate provenance metadata
#
# Author: Scott Christley
# Author: Tanzira Najnin
# Date: Nov 13, 2025
#

from __future__ import print_function
import json
import argparse
import os
import sys
import csv
import uuid

def addProvRelation(metadata, relation_type, key, value_dict):
    if relation_type not in metadata:
        metadata[relation_type] = {}
    metadata[relation_type][key] = value_dict
    
def wasDerivedFrom(metadata, generatedEntity, usedEntity, tags, description, format_type):
    workflow_metadata = metadata.get("value")
    entities = workflow_metadata.get("entity")

    # find the source entity
    used_key = None
    used = None
    for ent_key, ent_val in entities.items():
        if ent_key.endswith(usedEntity):
            used_key = ent_key
            used = entities[ent_key]
            break

    if used is None:
        print(f"ERROR (wasDerivedFrom): Cannot find used entity: {usedEntity}", file=sys.stderr)
        print("From wasDerivedFrom: ", generatedEntity, usedEntity, tags, description, format_type, file=sys.stderr)
        sys.exit(1)

    # does generated entity already exist
    generated_key = None
    generated = None
    for ent_key, ent_val in entities.items():
        if ent_val.get("vdjserver:type") == "app:outputs" and ent_key.endswith(generatedEntity):
            generated_key = ent_key
            generated = entities[ent_key]
            break

    # create new entity record if needed
    if generated is None:
        generated_key = "vdjserver:project_job_file:" + generatedEntity
        generated = {
            "vdjserver:type": "app:outputs",
            "vdjserver:tags": tags,
            "vdjserver:description": description,
            "vdjserver:format": format_type
        }
        entities[generated_key] = generated

    # Add wasDerivedFrom relation
    key = uuid.uuid4().hex[:9]
    if workflow_metadata['wasDerivedFrom'] is None:
        workflow_metadata['wasDerivedFrom'] = {}
    workflow_metadata['wasDerivedFrom'][key] = {
        "prov:generatedEntity": generated_key,
        "prov:usedEntity": used_key
    }

    return metadata

def wasGeneratedBy(metadata, entity, activity_key, tags, description, format_type):
    workflow_metadata = metadata.get("value")
    entities = workflow_metadata.get("entity")
    activities = workflow_metadata.get("activity")

    # does entity already exist
    generated_key = None
    generated = None
    for ent_key, ent_val in entities.items():
        if ent_val.get("vdjserver:type") == "app:outputs" and ent_key.endswith(entity):
            generated_key = ent_key
            generated = entities[ent_key]
            break

    # find the activity
    if activities.get(activity_key) is None:
        print(f"ERROR (wasGeneratedBy): Cannot find activity: {activity_key}", file=sys.stderr)
        sys.exit(1)

    # create new entity record if needed
    if generated is None:
        generated_key = "vdjserver:project_job_file:" + entity
        generated = {
            "vdjserver:type": "app:outputs",
            "vdjserver:tags": tags,
            "vdjserver:description": description,
            "vdjserver:format": format_type
        }
        entities[generated_key] = generated

    # Add wasGeneratedBy relation
    key = uuid.uuid4().hex[:9]
    if workflow_metadata['wasGeneratedBy'] is None:
        workflow_metadata['wasGeneratedBy'] = {}
    workflow_metadata['wasGeneratedBy'][key] = {
        "prov:entity": generated_key,
        "prov:activity": activity_key
    }

    return metadata

def addCalculation(metadata, activity_key, tags):
    workflow_metadata = metadata.get("value")
    activities = workflow_metadata.get("activity")

    # find the activity
    activity = activities.get(activity_key)
    if activity is None:
        print(f"ERROR (addCalculation): Cannot find activity: {activity_key}", file=sys.stderr)
        sys.exit(1)

    # Add or append tags
    existing_tags = activity.get("vdjserver:tags")

    if existing_tags:
        activity["vdjserver:tags"] = f"{existing_tags}, {tags}"
    else:
        activity["vdjserver:tags"] = tags

    return metadata

def getRepertoireForFile(metadata, filename):
    workflow_metadata = metadata.get("value")
    entities = workflow_metadata.get("entity")

    # find the entity for file
    used_key = None
    used = None
    for ent_key, ent_val in entities.items():
        if ent_key.endswith(filename):
            used_key = ent_key
            used = entities[ent_key]
            break

    if used is None:
        print(f"ERROR (getRepertoireForFile): Cannot find file in entities: {filename}", file=sys.stderr)
        sys.exit(1)

    if used.get('airr:Repertoire') is None:
        print(f"ERROR (getRepertoireForFile): entity {used_key} for file {filename} does not have airr:Repertoire", file=sys.stderr)
        sys.exit(1)
    else:
        # print repertoire_id
        print(used.get('airr:Repertoire'))
        
def fileEntries(metadata, filename):
    entry_file = csv.DictReader(open(filename, 'r'))
    for row in entry_file:
        wasDerivedFrom(metadata, row['generatedEntity'], row['usedEntity'], row['tags'], row['description'], row['format_type'])

def groupFileEntries(metadata, filename):
    entry_file = csv.DictReader(open(filename, 'r'))
    for row in entry_file:
        wasGeneratedBy(metadata, row['entity'], row['activity_key'], row['tags'], row['description'], row['format_type'])
    

if (__name__=="__main__"):
    parser = argparse.ArgumentParser(description='Generate provenance metadata for activity.')
    parser.add_argument('--wasGeneratedBy', help='Add wasGeneratedBy relation', nargs=5, metavar=('entity', 'activity', 'tags', 'description', 'format'))
    parser.add_argument('--wasDerivedFrom', help='Add wasDerivedFrom relation', nargs=5, metavar=('generatedEntity', 'usedEntity', 'tags', 'description', 'format'))
    parser.add_argument('--addCalculation', help='Add calculation tags', nargs=2, metavar=('activity', 'tags'))
    parser.add_argument('--getRepertoireForFile', help='Get repertoire ID for file', nargs=1, metavar=('filename'))
    parser.add_argument('--fileEntries', help='Add prov entries from file', nargs=1, metavar=('filename'))
    parser.add_argument('--groupFileEntries', help='Add prov entries from file', nargs=1, metavar=('filename'))
    
    #parser.add_argument('--used', help='Add used relation', nargs=2, metavar=('activity', 'entity'))
    #parser.add_argument('--wasAssociatedWith', help='Add wasAssociatedWith relation', nargs=2, metavar=('activity', 'agent'))
    #parser.add_argument('--wasAttributedTo', help='Add wasAttributedTo relation', nargs=2, metavar=('entity', 'agent'))
    parser.add_argument('json_file', type=str, help='Metadata JSON file name')
    args = parser.parse_args()

    if (args):
        # load json
        with open(args.json_file, 'r') as f:
            metadata = json.load(f)

        if args.wasGeneratedBy:
            metadata = wasGeneratedBy(metadata, args.wasGeneratedBy[0], args.wasGeneratedBy[1], args.wasGeneratedBy[2], args.wasGeneratedBy[3], args.wasGeneratedBy[4])

        if args.wasDerivedFrom:
            metadata = wasDerivedFrom(metadata, args.wasDerivedFrom[0], args.wasDerivedFrom[1], args.wasDerivedFrom[2], args.wasDerivedFrom[3], args.wasDerivedFrom[4])

        if args.addCalculation:
            metadata = addCalculation(metadata, args.addCalculation[0], args.addCalculation[1])

        if args.getRepertoireForFile:
            getRepertoireForFile(metadata, args.getRepertoireForFile[0])
            
        if args.fileEntries:
            fileEntries(metadata, args.fileEntries[0])
            
        if args.groupFileEntries:
            fileEntries(metadata, args.groupFileEntries[0])
            

        # save the json
        with open(args.json_file, 'w') as json_file:
            json.dump(metadata, json_file, indent=2)

