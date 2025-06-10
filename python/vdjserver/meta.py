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
import time


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
    
    
    
def meta_list(system_id=None, token=None, format_json=False, **kwargs):
    token = vdjserver.defaults.vdjserver_token(token)
    headers = {"Authorization": f"Bearer {token}"}
    url = f"https://{vdjserver.defaults.vdj_host}/api/v2/project/metadata"
    # print("Format Json: ", format_json)
    try:
        response = requests.get(url, headers=headers)
        response.raise_for_status()
        json_data = response.json()
        if format_json:
            result = json_data.get('result', [])
            print(json.dumps(result, indent=4))
        else:
            if len(json_data) > 0:
                # Define the fields we want to print
                fields = ["uuid", "owner", "name", "created", "lastUpdated"]
                # Determine the maximum width for each column based on the data
                field_widths = [len(field) for field in fields]
                # First pass to calculate the maximum width for each column
                result = json_data.get('result', [])
                for metadata in result:
                    for i, field in enumerate(fields):
                        
                        field_widths[i] = max(field_widths[i], len(str(metadata.get(field, 'N/A'))))

                # Print the header row
                header = " | ".join([f"{field:<{field_widths[i]}}" for i, field in enumerate(fields)])
                print(header)
                print("-" * len(header))  # Separator line

                # Print each row of job data
                for metadata in result:
                    row = " | ".join([f"{str(metadata.get(field, 'N/A')):<{field_widths[i]}}" for i, field in enumerate(fields)])
                    print(row)

            else:
                print(f"No Metadata found.")
    except Exception as e:
        print(f"Error retrieving job list: {e}")


        

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
def import_metadata(project_uuid, metadata_file_path, operation, system_id=None, token=None):
    token = vdjserver.defaults.vdjserver_token(token)

    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }

    try:
        # Check if the file exists
        if not os.path.exists(metadata_file_path):
            print(f"Error: The file {metadata_file_path} does not exist.", file=sys.stderr)
            return

        # Upload the file
        dest_file_path = f'/projects/{project_uuid}/files/{metadata_file_path}'
        print(f"Uploading metadata file {metadata_file_path}...")
        vdjserver.files.tapis_files_upload(metadata_file_path, dest_file_path=dest_file_path)

        # Import the uploaded file to the VDJServer project
        metadata_file = os.path.basename(metadata_file_path)
        file_import_url = f"https://{vdjserver.defaults.vdj_host}/api/v2/project/{project_uuid}/file/import"
        file_import_data = {
            "path": metadata_file,
            "name": metadata_file,
            "fileType": 10
        }

        response = requests.post(file_import_url, headers=headers, json=file_import_data)
        file_response_json = response.json()
        if file_response_json.get("status") != "success":
            print("File import failed:")
            print(json.dumps(file_response_json, indent=4))
            return
        # Validate operation
        if operation not in ['append', 'replace']:
            print("Error: Invalid operation type. Choose 'append' or 'replace'.", file=sys.stderr)
            return

        # Import metadata
        metadata_import_url = f"https://{vdjserver.defaults.vdj_host}/api/v2/project/{project_uuid}/metadata/import"
        metadata_import_data = {
            "filename": metadata_file,
            "operation": operation
        }

        response = requests.post(metadata_import_url, headers=headers, json=metadata_import_data)
        metadata_response_json = response.json()
        if metadata_response_json.get("status") != "success":
            print("Metadata import failed:")
            print(json.dumps(metadata_response_json, indent=4))
            return

    except requests.exceptions.RequestException as req_err:
        print(f"HTTP request error: {req_err}", file=sys.stderr)
    except Exception as e:
        print(f"Unexpected error during metadata import: {e}", file=sys.stderr)
    
    
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