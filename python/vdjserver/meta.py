"""
Interface functions for Meta operations
"""

# System imports
import json
import sys
import os
from tapipy.tapis import Tapis
import vdjserver.defaults
import requests
import vdjserver.files


#### Meta ####

def meta_get(tapis_obj, meta_uuid, system_id = None, token = None):
#    f = tapis_obj.files.listFiles(systemId=system_id, path=path)
    print('meta_show')
    

def meta_query(tapis_obj, query):
#    f = tapis_obj.files.listFiles(systemId=system_id, path=path)
    print('meta_query')

def meta_update(tapis_obj, obj):
#    f = tapis_obj.files.listFiles(systemId=system_id, path=path)
    print('meta_update')

def meta_delete(tapis_obj, query):
#    f = tapis_obj.files.listFiles(systemId=system_id, path=path)
    print('meta_delete')
    
    
    
def meta_list(system_id=None, token=None):
    token = vdjserver.defaults.vdjserver_token(token)

    headers = {"Authorization": f"Bearer {token}"}
    # Construct the URL
    url = f"https://{vdjserver.defaults.vdj_host}/api/v2/project/metadata"

    try:
        print("Sending request to fetch metadata...")
        response = requests.get(url, headers=headers)
        response.raise_for_status()  # Raise exception for non-2xx status codes
        #parse json response
        json_data = response.json()
        print(json.dumps(json_data, indent=4))  # Pretty-print the JSON response

    except requests.exceptions.RequestException as e:
        print(f"Error making request: {e}")
        exit(1)
    except json.JSONDecodeError:
        print("Error: Unable to parse response as JSON.")
        exit(1)
        

def get_metadata(project_uuid, name, system_id = None, token = None):
    token = vdjserver.defaults.vdjserver_token(token)
    
    url = f"https://{vdjserver.defaults.vdj_host}/api/v2/project/{project_uuid}/metadata/name/{name}"
    headers = {"Authorization": f"Bearer {token}"}
    try:
        response = requests.get(url, headers=headers)
        response.raise_for_status()  # Will raise an HTTPError if the HTTP request failed
        json_data = response.json()
        # Check if the status is success and if there are any results
        if json_data.get('status') == 'success':
            # Print the 'result' directly, or print a message if it's empty
            result = json_data.get('result', [])
            if result:
                print(json.dumps(result, indent=4))  # Pretty-print the result if it's not empty
            else:
                print(f"\n\nNo data found for the specified metadata type({name}).\n")
        else:
            print(f"Query failed with status: {json_data.get('status')}")
            if json_data.get('message'):
                print(f"Message: {json_data.get('message')}")

    except requests.exceptions.RequestException as e:
        # Print the error if the request fails
        print(f"Error querying metadata: {e}", file=sys.stderr)

def meta_get_by_uuid(project_uuid, uuid, system_id = None, token = None):
    token = vdjserver.defaults.vdjserver_token(token)
    
    url = f"https://{vdjserver.defaults.vdj_host}/api/v2/project/{project_uuid}/metadata/uuid/{uuid}"
    headers = {"Authorization": f"Bearer {token}"}
    try:
        response = requests.get(url, headers=headers)
        response.raise_for_status()  # Will raise an HTTPError if the HTTP request failed
        json_data = response.json()
        # Check if the status is success and if there are any results
        if json_data.get('status') == 'success':
            # Print the 'result' directly, or print a message if it's empty
            result = json_data.get('result', [])
            if result:
                print(json.dumps(result, indent=4))  # Pretty-print the result if it's not empty
            else:
                print("-------------------------------------------------------------------")
                print(f"\n\nNo data found for the specified metadata type({uuid}).\n")
                print("-------------------------------------------------------------------")
        else:
            print(f"Query failed with status: {json_data.get('status')}")
            if json_data.get('message'):
                print(f"Message: {json_data.get('message')}")

    except requests.exceptions.RequestException as e:
        # Print the error if the request fails
        print(f"Error querying metadata: {e}", file=sys.stderr)
        
# Function to export metadata for a project by UUID
def export_metadata(project_uuid, system_id = None, token=None):
    token = vdjserver.defaults.vdjserver_token(token)

    headers = {"Authorization": f"Bearer {token}"}

    # Construct the URL
    url = f"https://{vdjserver.defaults.vdj_host}/api/v2/project/{project_uuid}/metadata/export"

    try:
        print(f"Sending request to export metadata for project {project_uuid}...")
        response = requests.get(url, headers=headers)
        response.raise_for_status()
        # Assuming the response is a JSON object
        json_data = response.json()
        # Print the export result (could be a file or data)
        if json_data.get('result'):
            print("-------------------------------------------------------------------")
            file_name = json_data.get('result')['file']
            path = f'./projects/{project_uuid}/deleted/{file_name}'
            vdjserver.files.tapis_files_download(path)
            print("Metadata has been downloaded to your current directory.")
            print("-------------------------------------------------------------------")
        else:
            print("No metadata found for this project.")

    except requests.exceptions.RequestException as e:
        print(f"Error making request: {e}")
        exit(1)
    except json.JSONDecodeError:
        print("Error: Unable to parse response as JSON.")
        exit(1)
    
## Function to export table metadata for a project by UUID and table name
def export_table_metadata(project_uuid, table_name, system_id = None, token=None):
    token = vdjserver.defaults.vdjserver_token(token)

    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }

    url = f"https://{vdjserver.defaults.vdj_host}/api/v2/project/{project_uuid}/metadata/export/table/{table_name}"
    print(f"Making request to: {url}")

    try:
        response = requests.get(url, headers=headers)
        response.raise_for_status()  # Raise an exception for bad status codes (4xx or 5xx)
        
        # Parse and handle the response
        json_data = response.json()
        if json_data.get('result'):
            print("-------------------------------------------------------------------")
            file_name = json_data.get('result')['file']
            path = f'./projects/{project_uuid}/deleted/{file_name}'
            vdjserver.files.tapis_files_download(path)
            print("Metadata has been downloaded to your current directory.")
            print("-------------------------------------------------------------------")
        else:
            print("No metadata found for this project.")
    
    except requests.exceptions.RequestException as e:
        print(f"Error making request: {e}")
        exit(1)
    except json.JSONDecodeError:
        print("Error: Invalid JSON response.")
        exit(1)
        
        
# Function to import metadata with project uuid and file path
##NOT WORKING RIGHT NOW.

def import_metadata(project_uuid, metadata_file_path, system_id = None, token=None):
    token = vdjserver.defaults.vdjserver_token(token)

    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }

    # Check if the file exists
    if not os.path.exists(metadata_file_path):
        print(f"Error: The file {metadata_file_path} does not exist.")
        exit(1)

    # upload the file
    dest_file_path = f'/projects/{project_uuid}/files/{metadata_file_path}'
    print(f"Uploading metadata file {metadata_file_path}...")
    vdjserver.files.tapis_files_upload(metadata_file_path, dest_file_path=dest_file_path)

    # attach uploaded file to a vdjserver project
    metadata_file = metadata_file_path.split('/')[-1]
    url = f"https://{vdjserver.defaults.vdj_host}/api/v2/project/{project_uuid}/file/import"
    data = {
        "path": metadata_file,
        "name": metadata_file,
        "fileType": 10
    }
    response = requests.post(url, headers=headers, data=data)
    response.raise_for_status()  # Raise an exception for bad status codes (4xx or 5xx)

    # Assuming the response is a JSON object
    json_data = response.json()

    # Now import the metadata
    url = f"https://{vdjserver.defaults.vdj_host}/api/v2/project/{project_uuid}/metadata/import"
    data = {
        "filename": metadata_file,
        "operation": "append"
    }
    response = requests.post(url, headers=headers, data=data)
    response.raise_for_status()  # Raise an exception for bad status codes (4xx or 5xx)

    # Assuming the response is a JSON object
    json_data = response.json()

#     # Open the file to be sent in the request
#     with open(metadata_file_path, 'rb') as metadata_file:
#         files = {'file': (os.path.basename(metadata_file_path), metadata_file)}
#         try:
#             print(f"Sending request to import metadata from file {metadata_file_path}...")
#             data = {
#                 "filename": metadata_file,
#                 "operation": "append"
#             }
#             # Send the POST request to upload the file
#             response = requests.post(url, headers=headers, data=data)
#             response.raise_for_status()  # Raise an exception for bad status codes (4xx or 5xx)
#             
#             # Assuming the response is a JSON object
#             json_data = response.json()
#             
#             # Check if the import was successful
#             if json_data.get('status') == 'success':
#                 print(f"Metadata successfully imported into project {project_uuid}.")
#             else:
#                 print(f"Failed to import metadata: {json_data.get('message', 'Unknown error')}")
#         
#         except requests.exceptions.RequestException as e:
#             print(f"Error making request: {e}")
#             exit(1)
#         except json.JSONDecodeError:
#             print("Error: Unable to parse response as JSON.")
#             exit(1)

def import_table_metadata(project_uuid, table_name, metadata_file_path, system_id=None, token=None):
    token = vdjserver.defaults.vdjserver_token(token)

    headers = {
        "Authorization": f"Bearer {token}",
    }

    # Check if the file exists
    if not os.path.exists(metadata_file_path):
        print(f"Error: The file {metadata_file_path} does not exist.")
        exit(1)

    # Construct the URL for the API
    url = f"https://{vdjserver.defaults.vdj_host}/api/v2/project/{project_uuid}/metadata/import/table/{table_name}"

    # Open the metadata file and upload it
    with open(metadata_file_path, 'rb') as metadata_file:
        files = {'file': (os.path.basename(metadata_file_path), metadata_file)}

        try:
            print(f"Sending request to import metadata from file {metadata_file_path} for table {table_name}...")
            # Send the POST request to import the metadata file
            response = requests.post(url, headers=headers, files=files)
            response.raise_for_status()  # Raise an exception for bad status codes (4xx or 5xx)
            
            json_data = response.json()  # Assuming the response is JSON

            if json_data.get('status') == 'success':
                print(f"Metadata successfully imported into table {table_name} for project {project_uuid}.")
            else:
                print(f"Failed to import metadata: {json_data.get('message', 'Unknown error')}")
    
        except requests.exceptions.RequestException as e:
            print(f"Error making request: {e}")
            if response.content:
                print(f"Response content: {response.content.decode()}")
            exit(1)
        except json.JSONDecodeError:
            print("Error: Unable to parse response as JSON.")
            exit(1)