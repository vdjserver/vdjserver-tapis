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
import uuid

# Increment with any major updates
VERSION = 4

def addProvRelation(metadata, relation_type, key, value_dict):
    if relation_type not in metadata:
        metadata[relation_type] = {}
    metadata[relation_type][key] = value_dict
    
def buildWasDerivedFrom(metadata):
    workflow_metadata = metadata.get("process", {}).get("workflow_metadata", {})
    entities = workflow_metadata.get("entity", {})
    was_derived_from = {}
    generated_entities = []
    for ent_key, ent_val in entities.items():
        if ent_val.get("vdjserver:type") == "app:inputs" and ent_key.startswith("vdjserver:project_file:"):
            # Extract the input filename from the key
            if ":" in ent_key:
                used_entity = ent_key
                filename = ent_key.split(":", 2)[-1]  # e.g., "healthy-171-19-117_S1_L004_R1_001.fastq.gz"

                # Determine output file extension: remove .gz if present
                if filename.endswith(".gz"):
                    output_filename = filename[:-3]  # strip .gz
                else:
                    output_filename = filename

                # Construct the generated entity key
                generated_entity = ent_key.replace("project_file", "project_job_file")
                # Replace the filename in the key
                generated_entity = ":".join(generated_entity.split(":", 2)[:2] + [output_filename])

                # Add a new relation
                key = uuid.uuid4().hex[:9]
                was_derived_from[key] = {
                    "prov:generatedEntity": generated_entity,
                    "prov:usedEntity": used_entity
                }
                generated_entities.append(generated_entity)
    # add generated entry inside input if it does not exist
    for generated_entity in generated_entities:
        if generated_entity not in entities:
            entities[generated_entity] = {
                "vdjserver:type": "app:outputs"
            }

    workflow_metadata["wasDerivedFrom"] = was_derived_from
    workflow_metadata["entity"] = entities
    metadata["process"]["workflow_metadata"] = workflow_metadata
    return metadata




if (__name__=="__main__"):
    # template = { "process": { "version": VERSION }, "groups": {}, "files": {}, "calculations": [] };
    template = {"process": {"version": VERSION},"groups": {},"files": {},"calculations": []}
    parser = argparse.ArgumentParser(description='Generate process metadata for workflow.')
    parser.add_argument('--init', type=str, nargs=2, help='Create initial metadata file from template', metavar=('appName', 'jobId'))
    parser.add_argument('--wasGeneratedBy', help='Add wasGeneratedBy relation', nargs=2, metavar=('entity', 'activity'))
    parser.add_argument('--wasDerivedFrom', help='Add was wasDerivedFrom relation', nargs=2, metavar=('generatedEntity', 'sourceEntity'))
    parser.add_argument('--used', help='Add used relation', nargs=2, metavar=('activity', 'entity'))
    parser.add_argument('--wasAssociatedWith', help='Add wasAssociatedWith relation', nargs=2, metavar=('activity', 'agent'))
    parser.add_argument('--wasAttributedTo', help='Add wasAttributedTo relation', nargs=2, metavar=('entity', 'agent'))
    parser.add_argument('json_file', type=str, help='Metadata JSON file name')
    args = parser.parse_args()

    if (args):
        if (args.init):
            template['process']['appName'] = args.init[0]
            template['process']['jobId'] = args.init[1]
            if (os.path.exists('./analysis_document.json')):
                with open('./analysis_document.json', 'r') as f:
                    data = json.load(f)
                    template['process']['workflow_metadata'] = data['value']
            
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
        
        if args.wasGeneratedBy:
            entity, activity = args.wasGeneratedBy
            key = f"{entity}_{activity}"
            addProvRelation(metadata, "wasGeneratedBy", key, {
                "prov:entity": entity,
                "prov:activity": activity
            })
        # if args.wasDerivedFrom:
        #     gen_entity, src_entity = args.wasDerivedFrom
        #     key = f"{gen_entity}_{src_entity}"
        #     addProvRelation(metadata, "wasDerivedFrom", key, {
        #         "prov:generatedEntity": gen_entity,
        #         "prov:usedEntity": src_entity
        #     })
        
        if args.wasDerivedFrom:
            metadata = buildWasDerivedFrom(metadata)
            
            
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

