# System imports
import json
import sys
import os
from tapipy.tapis import Tapis
import vdjserver.defaults
import requests
import time


def create_project(title = None,  json_file = None, system_id = None, token = None):
    token = vdjserver.defaults.vdjserver_token(token)
    url = f"https://{vdjserver.defaults.vdj_host}/api/v2/project"

    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    if json_file:
        with open(json_file, 'r') as f:
            project_fields = json.load(f)  # Now it's a dict!
            
    elif title:
        project_fields = { "project":
                            {
                                "study_id": None,
                                "study_title": title,
                                "study_type": None,
                                "study_description": None,
                                "inclusion_exclusion_criteria": None,
                                "grants": None,
                                "collected_by": None,
                                "lab_name": None,
                                "lab_address": None,
                                "submitted_by": None,
                                "pub_ids": None,
                                "keywords_study": None
                            }
                        }
    else:
        print("Must provide either --title or --json-file")
        return
    # print(project_fields)
    try:
        response = requests.post(url, headers=headers, json=project_fields)
        #print(f'Response: {response.json()}')
        response.raise_for_status()
        json_data = response.json()
        #print("Json Data: ", json_data)

        if json_data.get('status') == 'success' and 'result' in json_data:
            result = json_data['result']
            uuid = result.get('uuid')
            if uuid:
                print(f"Project created successfully with UUID: {uuid}")
                # return uuid
            else:
                print("UUID not found in response.", file=sys.stderr)
                print("Json Data: ", json_data)
        else:
            print(f"Project creation failed with status: {json_data.get('status')}", file=sys.stderr)
            if json_data.get('message'):
                print(f"Message: {json_data.get('message')}", file=sys.stderr)

    except requests.exceptions.RequestException as e:
        print(f"Error creating project: {e}", file=sys.stderr)
        
        
def add_user_to_project(project_uuid, username, system_id = None, token=None):
    token = vdjserver.defaults.vdjserver_token(token)
    url = f"https://{vdjserver.defaults.vdj_host}/api/v2/project/{project_uuid}/user"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    data = {"username": username}

    try:
        response = requests.post(url, headers=headers, json=data)
        response_json = response.json()
        if response_json.get("status") != "success":
            print("Failed to add user to project:")
            print(json.dumps(response_json, indent=4))
            return

        print(f"\n------ User '{username}' added to project '{project_uuid}' successfully.\n")
        # print(json.dumps(response_json, indent=4))

    except requests.exceptions.RequestException as e:
        print(f"Error adding user to project: {e}", file=sys.stderr)
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        
def remove_user_from_project(project_uuid, username, system_id = None, token = None):
    token = vdjserver.defaults.vdjserver_token(token)
    url = f"https://{vdjserver.defaults.vdj_host}/api/v2/project/{project_uuid}/user"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    data = {"username": username}
    try:
        response = requests.delete(url, headers=headers, json=data)
        response_json = response.json()

        if response_json.get("status") != "success":
            print("Failed to remove user from project:")
            print(json.dumps(response_json, indent=4))
            return

        print(f"\n------ User  '{username}' removed from project '{project_uuid}' successfully.\n")
        # print(json.dumps(response_json, indent=4))

    except requests.exceptions.RequestException as e:
        print(f"Error removing user from project: {e}", file=sys.stderr)
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
