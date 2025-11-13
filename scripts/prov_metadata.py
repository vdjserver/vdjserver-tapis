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
    
def wasDerivedFrom(metadata, generatedEntity, usedEntity):
    workflow_metadata = metadata.get("value")
    entities = workflow_metadata.get("entity")

    # find the source entity
    used_key = None
    used = None
    for ent_key, ent_val in entities.items():
        if ent_val.get("vdjserver:type") == "app:inputs" and ent_key.endswith(usedEntity):
            used_key = ent_key
            used = entities[ent_key]
            break

    if used is None:
        print(f"ERROR: Cannot find used entity: {usedEntity}")
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
        generated = { "vdjserver:type": "app:outputs" }
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




if (__name__=="__main__"):
    parser = argparse.ArgumentParser(description='Generate provenance metadata for activity.')
    parser.add_argument('--wasGeneratedBy', help='Add wasGeneratedBy relation', nargs=2, metavar=('entity', 'activity'))
    parser.add_argument('--wasDerivedFrom', help='Add was wasDerivedFrom relation', nargs=2, metavar=('generatedEntity', 'usedEntity'))
    parser.add_argument('--used', help='Add used relation', nargs=2, metavar=('activity', 'entity'))
    parser.add_argument('--wasAssociatedWith', help='Add wasAssociatedWith relation', nargs=2, metavar=('activity', 'agent'))
    parser.add_argument('--wasAttributedTo', help='Add wasAttributedTo relation', nargs=2, metavar=('entity', 'agent'))
    parser.add_argument('json_file', type=str, help='Metadata JSON file name')
    args = parser.parse_args()

    if (args):
        # load json
        with open(args.json_file, 'r') as f:
            metadata = json.load(f)

        if args.wasGeneratedBy:
            entity, activity = args.wasGeneratedBy
            key = f"{entity}_{activity}"
            addProvRelation(metadata, "wasGeneratedBy", key, {
                "prov:entity": entity,
                "prov:activity": activity
            })

        if args.wasDerivedFrom:
            metadata = wasDerivedFrom(metadata, args.wasDerivedFrom[0], args.wasDerivedFrom[1])

        if args.used:
            activity, entity = args.used
            key = f"{activity}_{entity}"
            addProvRelation(metadata, "used", key, {
                "prov:activity": activity,
                "prov:entity": entity
            })
        if args.wasAssociatedWith:
            activity, agent = args.wasAssociatedWith
            key = f"{activity}_{agent}"
            addProvRelation(metadata, "wasAssociatedWith", key, {
                "prov:activity": activity,
                "prov:agent":agent
            })
        if args.wasAttributedTo:
            entity, agent = args.wasAttributedTo
            key = F"{entity}_{agent}"
            addProvRelation(metadata, "wasAttributedTo", key, {
                "prov:entity":entity,
                "prov:agent":agent
            })
        # save the json
        with open(args.json_file, 'w') as json_file:
            json.dump(metadata, json_file, indent=2)

