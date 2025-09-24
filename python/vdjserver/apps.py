"""
Interface functions for App operations
"""

# System imports
import json
import sys
import os
from tapipy.tapis import Tapis
import vdjserver.defaults
import requests

def apps_list(system_id=None, token=None, all=False):
    token = vdjserver.defaults.vdjserver_token(token)

    # Construct the Tapis file download URL (for Agave-style APIs)
    if all:
        url = f"https://{vdjserver.defaults.tapis_host}/v3/apps?search=(version.like.*)&select=allAttributes"
    else:
        url = f"https://{vdjserver.defaults.tapis_host}/v3/apps?select=allAttributes"
    headers = {"X-Tapis-Token": token,
                "Accept": "application/json"}

    # Define the fields we want to print
    fields = ["id",  "version", "owner", "description", "containerImage"]
    # Determine the maximum width for each column based on the data
    field_widths = [len(field) for field in fields]
    print('\n')
    try:
        response = requests.get(url, headers=headers)
        response = response.json()
        results = response['result']
        if isinstance(results, list):
            if len(results) > 0:
                # First pass to calculate the maximum width for each column
                for job in results:
                    for i, field in enumerate(fields):
                        field_widths[i] = max(field_widths[i], len(job.get(field, 'N/A')))
                # Print the header row
                header = " | ".join([f"{field:<{field_widths[i]}}" for i, field in enumerate(fields)])
                print(header)
                print("-" * len(header))  # Separator line

                # Print each row of job data
                for job in results:
                    row = " | ".join([f"{job.get(field, 'N/A'):<{field_widths[i]}}" for i, field in enumerate(fields)])
                    print(row)
            else:
                print("No apps found.")
        else:
            print(f"Unexpected response format. Expected list, got {type(response)}.")

    except Exception as e:
        print(f"Error retrieving apps list: {e}")

def create_app_version(json_file, system_id = None, token=None):
    # Initialize the Tapis object
    tapis_obj = vdjserver.defaults.init_tapis(token)

    try:
        # Read the app data from the provided JSON file
        with open(json_file, 'r') as file:
            app_data = json.load(file)
        print(type(app_data))
    except Exception as e:
        print(f"Error reading JSON file: {e}")
        sys.exit(1)
    try:
        # Convert the app_data dictionary to a JSON string using json.dumps()

        # Call the Tapis API to create the app version with the data
        response = tapis_obj.apps.createAppVersion(**app_data)
        
        # Print the successful response
        print("App version created successfully:", response)

    except Exception as e:
        print(f"Error creating app version: {e}")




def apps_update(app_name, app_version, json_file, system_id = None, token=None):
    tapis_obj = vdjserver.defaults.init_tapis(token)
    try:
        # Read the app data from the provided JSON file
        with open(json_file, 'r') as file:
            data = json.load(file)
    except Exception as e:
        print(f"Error reading JSON file: {e}")
        sys.exit(1)
    try:
        # Convert the app_data dictionary to a JSON string using json.dumps()

        # Call the Tapis API to create the app version with the data
        response = tapis_obj.apps.putApp(appId = app_name, appVersion = app_version, **data)
        
        # Print the successful response
        print("App version Updated successfully:", response)

    except Exception as e:
        print(f"Error Updating app version: {e}")
        
        
        
def delete_app(app_name, system_id=None, token=None):
    # Initialize the Tapis object
    tapis_obj = vdjserver.defaults.init_tapis(token)

    try:
        # Call the Tapis API to delete the app version
        response = tapis_obj.apps.deleteApp(appId=app_name)

        # Print the successful response
        print(f"App {app_name} deleted successfully:", response)

    except Exception as e:
        print(f"Error deleting app {app_name}: {e}")

def change_app_owner(app_id, user_name, system_id=None, token=None):
    # Initialize the Tapis object
    tapis_obj = vdjserver.defaults.init_tapis(token)

    try:
        # Call the Tapis API to change the app owner
        response = tapis_obj.apps.changeAppOwner(appId=app_id, userName=user_name)

        # Print the successful response
        print(f"App {app_id} owner changed to {user_name} successfully:", response)

    except Exception as e:
        print(f"Error changing owner of app {app_id}: {e}")


def get_app_history(app_id, system_id=None, token=None):
    # Initialize the Tapis object
    tapis_obj = vdjserver.defaults.init_tapis(token)

    try:
        # Call the Tapis API to get the app history
        response = tapis_obj.apps.getHistory(appId=app_id)

        # Print a formatted history summary
        print(f"History for app '{app_id}':\n")
        
        # Assuming the response is a list of history entries
        for history_entry in response:
            # Extract and print important details, ensuring each field is accessed correctly
            app_version = history_entry.get('appVersion', 'N/A')
            created = history_entry.get('created', 'N/A')
            description_details = history_entry.get('description', 'No description available')
            description = description_details.get('description', 'No description available' )
            container_image = description_details.get('containerImage', 'N/A')
            exec_system_id = description_details.get('execSystemId', 'N/A')
            owner = description_details.get('owner', 'N/A')
            job_description = description_details.get('jobDescription', 'N/A')
            memory_mb = description_details.get('memoryMB', 'N/A')
            version_enabled = description_details.get('versionEnabled', 'N/A')
            archived = description_details.get('archiveOnAppError', 'N/A')
            
            # Print the extracted details in a nicely formatted manner
            print(f"\tApp Name: {app_id}")
            print(f"\tVersion: {app_version}")
            print(f"\tCreated: {created}")
            print(f"\tDescription: {description}")
            print(f"\tContainer Image: {container_image}")
            print(f"\tExec System ID: {exec_system_id}")
            print(f"\tOwner: {owner}")
            print(f"\tJob Description: {job_description}")
            print(f"\tMemory (MB): {memory_mb}")
            print(f"\tVersion Enabled: {version_enabled}")
            print(f"\tArchived: {archived}")
            print("-" * 100)  # Separator for readability

    except Exception as e:
        print(f"Error retrieving history for app {app_id}: {e}")


def get_app_details(app_id, app_version, system_id=None, token=None):
    token = vdjserver.defaults.vdjserver_token(token)

    url = f'https://{vdjserver.defaults.tapis_host}/v3/apps/{app_id}/{app_version}'
    
    headers = {"X-Tapis-Token": token,
               "Accept": "application/json"}
    try:
        response = requests.get(url, headers=headers)
        print("-" * 100)
        print(f"\n\t\tappID: {app_id} \n\t\tversion: {app_version}\n")
        print("-" * 100)
        response = response.json()
        print(json.dumps(response['result'], indent = 4))
    except Exception as e:
        print(f"Error retrieving detailed information for {app_id}: {e}")
